"""Recuperação de parâmetros completos e elasticidades do AIDS."""

from __future__ import annotations

import numpy as np
import pandas as pd

from .config import AIDSConfig, default_config
from .utils import load_pickle, matrix_to_long, save_pickle, write_csv


def calculate_elasticities(
    cfg: AIDSConfig | None = None,
    wbar_sample: str = "full",
) -> dict[str, object]:
    cfg = cfg or default_config()
    cfg.ensure_dirs()

    if not cfg.proc_pickle.exists():
        raise FileNotFoundError(f"Base processada não encontrada: {cfg.proc_pickle}")
    model_path = cfg.tagged_model("model_hsym")
    if not model_path.exists():
        raise FileNotFoundError(f"Modelo hsym não encontrado: {model_path}")

    dados = pd.read_pickle(cfg.proc_pickle)
    model_hsym = load_pickle(model_path)

    if wbar_sample == "estimacao":
        subset = [
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
        dados_wbar = dados.dropna(subset=subset)
    elif wbar_sample == "full":
        dados_wbar = dados.dropna(subset=[f"w_{g}" for g in cfg.goods])
    else:
        raise ValueError("wbar_sample deve ser 'full' ou 'estimacao'.")

    wbar = pd.Series({g: dados_wbar[f"w_{g}"].mean(skipna=True) for g in cfg.goods}, name="wbar")
    if (~np.isfinite(wbar.to_numpy(dtype=float))).any() or (wbar <= 0).any():
        raise ValueError("As participações médias usadas nas elasticidades têm NA, Inf ou valor não positivo.")
    if abs(wbar.sum() - 1.0) > 1e-8:
        print(f"Aviso: soma das participações médias = {wbar.sum():.12f}, não exatamente 1.")

    theta = model_hsym.theta
    if theta.index.empty:
        raise ValueError("model_hsym.theta está sem nomes.")

    def pega_theta(nome: str) -> float:
        if nome not in theta.index:
            raise KeyError(f"Parâmetro ausente em model_hsym.theta: {nome}")
        valor = float(theta.loc[nome])
        if not np.isfinite(valor):
            raise ValueError(f"Parâmetro não finito em model_hsym.theta: {nome}")
        return valor

    alpha = pd.Series(
        {
            "bfvl": pega_theta("a_bfvl"),
            "pork": pega_theta("a_pork"),
            "poult": 1.0 - pega_theta("a_bfvl") - pega_theta("a_pork") - pega_theta("a_fish"),
            "fish": pega_theta("a_fish"),
        },
        name="alpha",
    )
    beta = pd.Series(
        {
            "bfvl": pega_theta("b_bfvl"),
            "pork": pega_theta("b_pork"),
            "poult": -pega_theta("b_bfvl") - pega_theta("b_pork") - pega_theta("b_fish"),
            "fish": pega_theta("b_fish"),
        },
        name="beta",
    )

    G = pd.DataFrame(np.nan, index=cfg.goods, columns=cfg.goods, dtype=float)
    G.loc["bfvl", "bfvl"] = pega_theta("g11")
    G.loc["bfvl", "pork"] = pega_theta("g12")
    G.loc["bfvl", "fish"] = pega_theta("g14")
    G.loc["bfvl", "poult"] = -G.loc["bfvl", ["bfvl", "pork", "fish"]].sum()

    G.loc["pork", "bfvl"] = pega_theta("g12")
    G.loc["pork", "pork"] = pega_theta("g22")
    G.loc["pork", "fish"] = pega_theta("g24")
    G.loc["pork", "poult"] = -G.loc["pork", ["bfvl", "pork", "fish"]].sum()

    G.loc["fish", "bfvl"] = pega_theta("g14")
    G.loc["fish", "pork"] = pega_theta("g24")
    G.loc["fish", "fish"] = pega_theta("g44")
    G.loc["fish", "poult"] = -G.loc["fish", ["bfvl", "pork", "fish"]].sum()

    G.loc["poult", :] = -G.loc[["bfvl", "pork", "fish"], :].sum(axis=0)
    G.loc["poult", "poult"] = -G.loc["poult", ["bfvl", "pork", "fish"]].sum()

    if alpha.isna().any() or beta.isna().any() or G.isna().any().any():
        raise ValueError("Alpha, beta ou gamma ainda têm NA.")

    eta = 1.0 + beta.loc[list(cfg.goods)] / wbar.loc[list(cfg.goods)]
    eta.name = "eta"

    EM = pd.DataFrame(np.nan, index=cfg.goods, columns=cfg.goods, dtype=float)
    EH = pd.DataFrame(np.nan, index=cfg.goods, columns=cfg.goods, dtype=float)
    for i in cfg.goods:
        for j in cfg.goods:
            indicador = 1.0 if i == j else 0.0
            EM.loc[i, j] = -indicador + G.loc[i, j] / wbar.loc[i] - beta.loc[i] * wbar.loc[j] / wbar.loc[i]
            EH.loc[i, j] = EM.loc[i, j] + eta.loc[i] * wbar.loc[j]

    if eta.isna().any() or EM.isna().any().any() or EH.isna().any().any():
        raise ValueError("As elasticidades ainda têm NA.")

    diagnostico_elasticidades = pd.DataFrame(
        {
            "objeto": ["alpha", "beta", "wbar", "eta", "gamma", "marshalliana", "compensada"],
            "n_na": [
                int(alpha.isna().sum()),
                int(beta.isna().sum()),
                int(wbar.isna().sum()),
                int(eta.isna().sum()),
                int(G.isna().sum().sum()),
                int(EM.isna().sum().sum()),
                int(EH.isna().sum().sum()),
            ],
            "n_nao_finito": [
                int((~np.isfinite(alpha)).sum()),
                int((~np.isfinite(beta)).sum()),
                int((~np.isfinite(wbar)).sum()),
                int((~np.isfinite(eta)).sum()),
                int((~np.isfinite(G.to_numpy())).sum()),
                int((~np.isfinite(EM.to_numpy())).sum()),
                int((~np.isfinite(EH.to_numpy())).sum()),
            ],
        }
    )

    alpha_tbl = alpha.reset_index()
    alpha_tbl.columns = ["produto", "alpha"]
    beta_tbl = beta.reset_index()
    beta_tbl.columns = ["produto", "beta"]
    wbar_tbl = wbar.reset_index()
    wbar_tbl.columns = ["produto", "wbar"]
    wbar_tbl["amostra"] = wbar_sample
    eta_tbl = eta.reset_index()
    eta_tbl.columns = ["produto", "eta"]

    write_csv(diagnostico_elasticidades, cfg.tagged_table("diagnostico_elasticidades"))
    write_csv(alpha_tbl, cfg.tagged_table("alpha_hsym"))
    write_csv(beta_tbl, cfg.tagged_table("beta_hsym"))
    write_csv(wbar_tbl, cfg.tagged_table("participacoes_medias_elast"))
    write_csv(eta_tbl, cfg.tagged_table("elasticidade_dispendio_hsym"))
    write_csv(G.reset_index(names="produto_linha"), cfg.tagged_table("gamma_hsym"))
    write_csv(EM.reset_index(names="produto_linha"), cfg.tagged_table("elasticidades_marshallianas_hsym"))
    write_csv(EH.reset_index(names="produto_linha"), cfg.tagged_table("elasticidades_compensadas_hsym"))
    write_csv(matrix_to_long(G, "gamma"), cfg.tagged_table("gamma_hsym_long"))
    write_csv(matrix_to_long(EM, "elasticidade_marshalliana"), cfg.tagged_table("elasticidades_marshallianas_hsym_long"))
    write_csv(matrix_to_long(EH, "elasticidade_compensada"), cfg.tagged_table("elasticidades_compensadas_hsym_long"))

    out = {
        "alpha": alpha,
        "beta": beta,
        "gamma": G,
        "wbar": wbar,
        "eta": eta,
        "EM": EM,
        "EH": EH,
        "wbar_sample": wbar_sample,
    }
    save_pickle(out, cfg.tagged_model("elasticidades_hsym"))
    print(f"Elasticidades AIDS calculadas sem NA. Amostra wbar: {wbar_sample}")
    return out


if __name__ == "__main__":
    calculate_elasticities()
