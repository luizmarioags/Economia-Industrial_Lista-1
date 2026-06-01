"""Estimação do sistema AIDS por GMM linear empilhado, Stata-like."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

import numpy as np
import pandas as pd

from .config import AIDSConfig, default_config
from .utils import chi2_sf, f_sf, matrix_rank, safe_solve, save_pickle, write_csv


@dataclass
class AIDSDesign:
    y: pd.Series
    X: pd.DataFrame
    Z: pd.DataFrame
    spec: str
    inst_names: list[str]
    design_data: pd.DataFrame


@dataclass
class AIDSModel:
    theta: pd.Series
    se: pd.Series
    V: pd.DataFrame
    resid: pd.Series
    fitted: pd.Series
    J: float
    df_J: int
    p_J: float
    design: AIDSDesign
    n_periodos: int
    Sigma_u: pd.DataFrame


def make_block_Z(data: pd.DataFrame, inst_names: list[str], cfg: AIDSConfig) -> pd.DataFrame:
    n = len(data)
    e = len(cfg.est_goods)
    q = len(inst_names)
    Z = np.zeros((n * e, q * e), dtype=float)
    Z0 = data.loc[:, inst_names].to_numpy(dtype=float)

    colnames: list[str] = []
    for eq in cfg.est_goods:
        colnames.extend([f"{eq}:{inst}" for inst in inst_names])

    for i, _eq in enumerate(cfg.est_goods):
        rows = slice(i * n, (i + 1) * n)
        cols = slice(i * q, (i + 1) * q)
        Z[rows, cols] = Z0

    return pd.DataFrame(Z, columns=colnames, index=pd.RangeIndex(n * e))


def build_design(
    data: pd.DataFrame,
    spec: str,
    inst_names: list[str],
    cfg: AIDSConfig | None = None,
) -> AIDSDesign:
    cfg = cfg or default_config()
    n = len(data)
    y_values = np.concatenate([data[f"w_{g}"].to_numpy(dtype=float) for g in cfg.est_goods])
    y = pd.Series(y_values, name="y")
    Z = make_block_Z(data, inst_names, cfg)

    if spec == "unrestricted":
        param_names: list[str] = []
        for eq in cfg.est_goods:
            param_names.extend([f"a_{eq}", *[f"g{eq}_{g}" for g in cfg.goods], f"b_{eq}"])

        X = pd.DataFrame(0.0, index=pd.RangeIndex(n * len(cfg.est_goods)), columns=param_names)
        for i, eq in enumerate(cfg.est_goods):
            rows = X.index[i * n : (i + 1) * n]
            X.loc[rows, f"a_{eq}"] = 1.0
            for g in cfg.goods:
                X.loc[rows, f"g{eq}_{g}"] = data[f"lngp_{g}"].to_numpy(dtype=float)
            X.loc[rows, f"b_{eq}"] = data["ln_real_x"].to_numpy(dtype=float)

    elif spec == "homogeneity":
        free_price_goods = [g for g in cfg.goods if g != cfg.omit_good]
        param_names = []
        for eq in cfg.est_goods:
            param_names.extend([f"a_{eq}", *[f"g{eq}_{g}" for g in free_price_goods], f"b_{eq}"])

        X = pd.DataFrame(0.0, index=pd.RangeIndex(n * len(cfg.est_goods)), columns=param_names)
        omit = data[f"lngp_{cfg.omit_good}"].to_numpy(dtype=float)
        for i, eq in enumerate(cfg.est_goods):
            rows = X.index[i * n : (i + 1) * n]
            X.loc[rows, f"a_{eq}"] = 1.0
            for g in free_price_goods:
                X.loc[rows, f"g{eq}_{g}"] = data[f"lngp_{g}"].to_numpy(dtype=float) - omit
            X.loc[rows, f"b_{eq}"] = data["ln_real_x"].to_numpy(dtype=float)

    elif spec == "hsym":
        param_names = [
            "a_bfvl",
            "a_pork",
            "a_fish",
            "g11",
            "g12",
            "g14",
            "g22",
            "g24",
            "g44",
            "b_bfvl",
            "b_pork",
            "b_fish",
        ]
        X = pd.DataFrame(0.0, index=pd.RangeIndex(n * len(cfg.est_goods)), columns=param_names)
        d1 = data["lngp_bfvl"].to_numpy(dtype=float) - data["lngp_poult"].to_numpy(dtype=float)
        d2 = data["lngp_pork"].to_numpy(dtype=float) - data["lngp_poult"].to_numpy(dtype=float)
        d4 = data["lngp_fish"].to_numpy(dtype=float) - data["lngp_poult"].to_numpy(dtype=float)
        real_x = data["ln_real_x"].to_numpy(dtype=float)

        rows1 = X.index[0:n]
        rows2 = X.index[n : 2 * n]
        rows4 = X.index[2 * n : 3 * n]

        X.loc[rows1, "a_bfvl"] = 1.0
        X.loc[rows1, "g11"] = d1
        X.loc[rows1, "g12"] = d2
        X.loc[rows1, "g14"] = d4
        X.loc[rows1, "b_bfvl"] = real_x

        X.loc[rows2, "a_pork"] = 1.0
        X.loc[rows2, "g12"] = d1
        X.loc[rows2, "g22"] = d2
        X.loc[rows2, "g24"] = d4
        X.loc[rows2, "b_pork"] = real_x

        X.loc[rows4, "a_fish"] = 1.0
        X.loc[rows4, "g14"] = d1
        X.loc[rows4, "g24"] = d2
        X.loc[rows4, "g44"] = d4
        X.loc[rows4, "b_fish"] = real_x

    else:
        raise ValueError("Especificação desconhecida. Use unrestricted, homogeneity ou hsym.")

    return AIDSDesign(y=y, X=X, Z=Z, spec=spec, inst_names=inst_names, design_data=data.copy())


def estimate_linear_gmm(design: AIDSDesign, cfg: AIDSConfig | None = None) -> AIDSModel:
    """
    Estimador GMM em dois passos no padrão do comando Stata usado na lista:
        winitial(unadjusted, independent) wmatrix(unadjusted) twostep

    A matriz inicial é I_e \otimes (Z0'Z0/n)^(-1). No segundo passo, permite-se
    covariância contemporânea entre os resíduos das equações:
        W2 = (Sigma_u \otimes (Z0'Z0/n))^(-1).
    """
    cfg = cfg or default_config()
    y = design.y.to_numpy(dtype=float)
    X = design.X.to_numpy(dtype=float)
    Z = design.Z.to_numpy(dtype=float)
    inst_names = design.inst_names

    e = len(cfg.est_goods)
    n_periodos = int(len(y) / e)

    Z0 = design.design_data.loc[:, inst_names].to_numpy(dtype=float)
    Qz = (Z0.T @ Z0) / n_periodos

    W1 = safe_solve(np.kron(np.eye(e), Qz))
    A1 = X.T @ Z @ W1 @ Z.T @ X
    b1 = X.T @ Z @ W1 @ Z.T @ y
    theta1 = safe_solve(A1) @ b1
    resid1 = y - X @ theta1

    U1 = resid1.reshape((e, n_periodos)).T
    Sigma_u = (U1.T @ U1) / n_periodos

    S2 = np.kron(Sigma_u, Qz)
    W2 = safe_solve(S2)
    A2 = X.T @ Z @ W2 @ Z.T @ X
    b2 = X.T @ Z @ W2 @ Z.T @ y
    theta2 = safe_solve(A2) @ b2
    resid2 = y - X @ theta2
    fitted = X @ theta2

    U2 = resid2.reshape((e, n_periodos)).T
    gbar = np.concatenate([(Z0.T @ U2[:, j]) / n_periodos for j in range(e)])

    D = (Z.T @ X) / n_periodos
    bread = safe_solve(D.T @ W2 @ D)
    V = bread / n_periodos
    diag_V = np.diag(V)
    se = np.sqrt(np.where(diag_V >= 0, diag_V, np.nan))

    J = float(n_periodos * (gbar.T @ W2 @ gbar))
    df_J = int(Z.shape[1] - X.shape[1])
    p_J = chi2_sf(J, df_J)

    theta_s = pd.Series(theta2, index=design.X.columns, name="theta")
    se_s = pd.Series(se, index=design.X.columns, name="se")
    V_df = pd.DataFrame(V, index=design.X.columns, columns=design.X.columns)
    resid_s = pd.Series(resid2, name="resid")
    fitted_s = pd.Series(fitted, name="fitted")
    sigma_df = pd.DataFrame(Sigma_u, index=cfg.est_goods, columns=cfg.est_goods)

    return AIDSModel(
        theta=theta_s,
        se=se_s,
        V=V_df,
        resid=resid_s,
        fitted=fitted_s,
        J=J,
        df_J=df_J,
        p_J=p_J,
        design=design,
        n_periodos=n_periodos,
        Sigma_u=sigma_df,
    )


def coef_table(model: AIDSModel, model_name: str) -> pd.DataFrame:
    out = pd.DataFrame(
        {
            "modelo": model_name,
            "parametro": model.theta.index,
            "estimativa": model.theta.to_numpy(dtype=float),
            "erro_padrao": model.se.to_numpy(dtype=float),
        }
    )
    out["estat_t"] = out["estimativa"] / out["erro_padrao"]
    return out


def check_design(design: AIDSDesign, model_name: str) -> pd.DataFrame:
    ZX = design.Z.to_numpy(dtype=float).T @ design.X.to_numpy(dtype=float)
    rank_Z = matrix_rank(design.Z.to_numpy(dtype=float))
    rank_ZX = matrix_rank(ZX)
    parametros = design.X.shape[1]
    momentos = design.Z.shape[1]
    identificado = rank_ZX >= parametros
    if not identificado:
        print(
            f"Aviso: modelo {model_name} possivelmente subidentificado: "
            f"rank(Z'X)={rank_ZX}, parametros={parametros}."
        )
    return pd.DataFrame(
        {
            "modelo": [model_name],
            "N_empilhado": [design.X.shape[0]],
            "parametros": [parametros],
            "momentos": [momentos],
            "rank_Z": [rank_Z],
            "rank_ZX": [rank_ZX],
            "identificado": [identificado],
        }
    )


def wald_test(model: AIDSModel, R: np.ndarray, r: np.ndarray, nome: str) -> pd.DataFrame:
    theta = model.theta.to_numpy(dtype=float).reshape(-1, 1)
    r = np.asarray(r, dtype=float).reshape(-1, 1)
    diff = R @ theta - r
    V_R = R @ model.V.to_numpy(dtype=float) @ R.T
    W = float(diff.T @ safe_solve(V_R) @ diff)
    df = int(R.shape[0])
    return pd.DataFrame({"teste": [nome], "estatistica": [W], "gl": [df], "p_valor": [chi2_sf(W, df)]})


def first_stage(data: pd.DataFrame, instruments: list[str], label: str, cfg: AIDSConfig) -> pd.DataFrame:
    """Diagnóstico de primeira etapa sem depender de fórmulas: OLS por álgebra matricial."""
    instruments_lm = [x for x in instruments if x != "const"]
    rows: list[dict[str, Any]] = []

    def ols_fit(y: np.ndarray, X: np.ndarray) -> tuple[np.ndarray, np.ndarray, float, float, int, int]:
        beta = np.linalg.pinv(X) @ y
        resid = y - X @ beta
        ssr = float(resid.T @ resid)
        tss = float(((y - y.mean()) ** 2).sum())
        r2 = 1 - ssr / tss if tss > 0 else np.nan
        nobs = X.shape[0]
        rank = matrix_rank(X)
        df_resid = nobs - rank
        return beta, resid, ssr, r2, nobs, df_resid

    for g in cfg.goods:
        y_name = f"lngp_{g}"
        cols_full = instruments_lm
        cols_red = ["ln_real_x"]
        work = data[[y_name, *cols_full]].dropna().copy()
        y = work[y_name].to_numpy(dtype=float)
        X_full = np.column_stack([np.ones(len(work)), work[cols_full].to_numpy(dtype=float)])
        X_red = np.column_stack([np.ones(len(work)), work[cols_red].to_numpy(dtype=float)])

        _, _, ssr_full, r2_full, nobs, df_full = ols_fit(y, X_full)
        _, _, ssr_red, r2_red, _nobs_red, df_red = ols_fit(y, X_red)
        dfn = df_red - df_full
        dfd = df_full
        F_excluidos = ((ssr_red - ssr_full) / dfn) / (ssr_full / dfd) if dfn > 0 and dfd > 0 else np.nan
        r2_parcial = (r2_full - r2_red) / (1 - r2_red) if np.isfinite(r2_red) and r2_red < 1 else np.nan

        rows.append(
            {
                "preco": g,
                "instrumento": label,
                "F_excluidos": F_excluidos,
                "p_valor": f_sf(F_excluidos, dfn, dfd),
                "r2_full": r2_full,
                "r2_reduzido": r2_red,
                "r2_parcial": r2_parcial,
                "N": nobs,
            }
        )

    return pd.DataFrame(rows)


def estimate_all(cfg: AIDSConfig | None = None) -> dict[str, AIDSModel]:
    cfg = cfg or default_config()
    cfg.ensure_dirs()

    if not cfg.proc_pickle.exists():
        raise FileNotFoundError(
            f"Base processada não encontrada: {cfg.proc_pickle}. Rode prepare_aids_data primeiro."
        )
    dados = pd.read_pickle(cfg.proc_pickle)
    dados = dados.copy()
    dados["const"] = 1.0

    l1_cols = [
        "w_bfvl",
        "w_pork",
        "w_fish",
        "ln_real_x",
        "lngp_bfvl",
        "lngp_pork",
        "lngp_poult",
        "lngp_fish",
        "L1_lngp_bfvl",
        "L1_lngp_pork",
        "L1_lngp_poult",
        "L1_lngp_fish",
    ]
    l2_cols = [*l1_cols, "L2_lngp_bfvl", "L2_lngp_pork", "L2_lngp_poult", "L2_lngp_fish"]
    data_L1 = dados.dropna(subset=l1_cols).reset_index(drop=True)
    data_L2 = dados.dropna(subset=l2_cols).reset_index(drop=True)

    inst_L1 = ["const", "ln_real_x", "L1_lngp_bfvl", "L1_lngp_pork", "L1_lngp_poult", "L1_lngp_fish"]
    inst_L2 = [
        "const",
        "ln_real_x",
        "L1_lngp_bfvl",
        "L1_lngp_pork",
        "L1_lngp_poult",
        "L1_lngp_fish",
        "L2_lngp_bfvl",
        "L2_lngp_pork",
        "L2_lngp_poult",
        "L2_lngp_fish",
    ]

    design_unrestricted = build_design(data_L1, "unrestricted", inst_L1, cfg)
    design_homogeneity = build_design(data_L1, "homogeneity", inst_L1, cfg)
    design_hsym = build_design(data_L1, "hsym", inst_L1, cfg)
    design_hsym_L2 = build_design(data_L2, "hsym", inst_L2, cfg)

    diagnostico_identificacao = pd.concat(
        [
            check_design(design_unrestricted, "irrestrito"),
            check_design(design_homogeneity, "homogeneidade"),
            check_design(design_hsym, "homog_simetria"),
            check_design(design_hsym_L2, "homog_simetria_L2"),
        ],
        ignore_index=True,
    )

    models = {
        "irrestrito": estimate_linear_gmm(design_unrestricted, cfg),
        "homogeneidade": estimate_linear_gmm(design_homogeneity, cfg),
        "homog_simetria": estimate_linear_gmm(design_hsym, cfg),
        "homog_simetria_L2": estimate_linear_gmm(design_hsym_L2, cfg),
    }

    coeficientes = pd.concat(
        [coef_table(models[name], name) for name in models.keys()], ignore_index=True
    )

    model_comparison = pd.DataFrame(
        {
            "modelo": list(models.keys()),
            "N": [m.n_periodos for m in models.values()],
            "N_empilhado": [len(m.resid) for m in models.values()],
            "parametros": [len(m.theta) for m in models.values()],
            "momentos": [m.design.Z.shape[1] for m in models.values()],
            "J": [m.J for m in models.values()],
            "df_J": [m.df_J for m in models.values()],
            "p_J": [m.p_J for m in models.values()],
        }
    ).merge(
        diagnostico_identificacao[["modelo", "rank_Z", "rank_ZX", "identificado"]],
        on="modelo",
        how="left",
    )

    pnames = list(models["irrestrito"].theta.index)
    R_hom = np.zeros((3, len(pnames)))
    for row, cols in enumerate(
        [
            ["gbfvl_bfvl", "gbfvl_pork", "gbfvl_poult", "gbfvl_fish"],
            ["gpork_bfvl", "gpork_pork", "gpork_poult", "gpork_fish"],
            ["gfish_bfvl", "gfish_pork", "gfish_poult", "gfish_fish"],
        ]
    ):
        for c in cols:
            R_hom[row, pnames.index(c)] = 1.0

    R_sym = np.zeros((3, len(pnames)))
    restrictions = [
        ("gbfvl_pork", "gpork_bfvl"),
        ("gbfvl_fish", "gfish_bfvl"),
        ("gpork_fish", "gfish_pork"),
    ]
    for row, (c1, c2) in enumerate(restrictions):
        R_sym[row, pnames.index(c1)] = 1.0
        R_sym[row, pnames.index(c2)] = -1.0

    testes_wald = pd.concat(
        [
            wald_test(models["irrestrito"], R_hom, np.zeros(3), "Homogeneidade"),
            wald_test(models["irrestrito"], R_sym, np.zeros(3), "Simetria"),
        ],
        ignore_index=True,
    )

    diagnostico_primeira_etapa = pd.concat(
        [first_stage(data_L1, inst_L1, "L1", cfg), first_stage(data_L2, inst_L2, "L1_L2", cfg)],
        ignore_index=True,
    )

    write_csv(coeficientes, cfg.tagged_table("coeficientes"))
    write_csv(diagnostico_identificacao, cfg.tagged_table("diagnostico_identificacao"))
    write_csv(model_comparison, cfg.tagged_table("comparacao_modelos"))
    write_csv(testes_wald, cfg.tagged_table("testes_wald_restricoes"))
    write_csv(diagnostico_primeira_etapa, cfg.tagged_table("diagnostico_primeira_etapa"))

    save_pickle(models["irrestrito"], cfg.tagged_model("model_unrestricted"))
    save_pickle(models["homogeneidade"], cfg.tagged_model("model_homogeneity"))
    save_pickle(models["homog_simetria"], cfg.tagged_model("model_hsym"))
    save_pickle(models["homog_simetria_L2"], cfg.tagged_model("model_hsym_L2"))

    return models


if __name__ == "__main__":
    estimate_all()
    print("Modelos AIDS estimados e salvos com sucesso.")
