"""Diagnósticos dos resultados do sistema AIDS em Python."""

from __future__ import annotations

import numpy as np
import pandas as pd

from .config import AIDSConfig, default_config
from .utils import chi2_sf, load_pickle, matrix_rank, write_csv


def safe_scalar(x) -> float:
    try:
        arr = np.asarray(x).ravel()
        if arr.size == 0:
            return np.nan
        return float(arr[0])
    except Exception:
        return np.nan


def resumo_modelo(model, nome: str) -> pd.DataFrame:
    theta = model.theta.to_numpy(dtype=float)
    se = model.se.to_numpy(dtype=float)
    X = model.design.X.to_numpy(dtype=float)
    Z = model.design.Z.to_numpy(dtype=float)
    ZX = Z.T @ X
    try:
        cond_ZZ = float(np.linalg.cond(Z.T @ Z))
    except Exception:
        cond_ZZ = np.nan
    try:
        cond_ZX = float(np.linalg.cond(ZX))
    except Exception:
        cond_ZX = np.nan
    return pd.DataFrame(
        {
            "modelo": [nome],
            "N_empilhado": [len(model.resid)],
            "parametros": [len(theta)],
            "momentos": [model.design.Z.shape[1]],
            "J": [safe_scalar(model.J)],
            "df_J": [safe_scalar(model.df_J)],
            "p_J": [safe_scalar(model.p_J)],
            "max_abs_t": [float(np.nanmax(np.abs(theta / se)))],
            "rank_X": [matrix_rank(X)],
            "rank_Z": [matrix_rank(Z)],
            "rank_ZX": [matrix_rank(ZX)],
            "cond_ZZ": [cond_ZZ],
            "cond_ZX": [cond_ZX],
        }
    )


def run_diagnostics(cfg: AIDSConfig | None = None) -> dict[str, pd.DataFrame]:
    cfg = cfg or default_config()
    cfg.ensure_dirs()

    model_unrestricted = load_pickle(cfg.tagged_model("model_unrestricted"))
    model_homogeneity = load_pickle(cfg.tagged_model("model_homogeneity"))
    model_hsym = load_pickle(cfg.tagged_model("model_hsym"))
    model_hsym_L2 = load_pickle(cfg.tagged_model("model_hsym_L2"))
    elasticidades = load_pickle(cfg.tagged_model("elasticidades_hsym"))

    resumo = pd.concat(
        [
            resumo_modelo(model_unrestricted, "irrestrito"),
            resumo_modelo(model_homogeneity, "homogeneidade"),
            resumo_modelo(model_hsym, "homog_simetria_L1"),
            resumo_modelo(model_hsym_L2, "homog_simetria_L2"),
        ],
        ignore_index=True,
    )

    Jdiff_hom = model_homogeneity.J - model_unrestricted.J
    df_hom = model_homogeneity.df_J - model_unrestricted.df_J
    Jdiff_sym_cond = model_hsym.J - model_homogeneity.J
    df_sym_cond = model_hsym.df_J - model_homogeneity.df_J
    testes_J_diff = pd.DataFrame(
        {
            "teste": ["Homogeneidade contra irrestrito", "Simetria adicional dado homogeneidade"],
            "estatistica": [Jdiff_hom, Jdiff_sym_cond],
            "gl": [df_hom, df_sym_cond],
            "p_valor": [chi2_sf(Jdiff_hom, df_hom), chi2_sf(Jdiff_sym_cond, df_sym_cond)],
        }
    )

    eta = elasticidades["eta"]
    EM = elasticidades["EM"]
    EH = elasticidades["EH"]
    wbar = elasticidades["wbar"]

    diag_elast = pd.DataFrame(
        {
            "produto": list(eta.index),
            "elasticidade_dispendio": eta.to_numpy(dtype=float),
            "marshalliana_propria": np.diag(EM.to_numpy(dtype=float)),
            "compensada_propria": np.diag(EH.to_numpy(dtype=float)),
        }
    )
    diag_elast["problema_dispendio_negativo"] = diag_elast["elasticidade_dispendio"] < 0
    diag_elast["problema_preco_proprio_marshalliano_positivo"] = diag_elast["marshalliana_propria"] > 0
    diag_elast["problema_preco_proprio_compensado_positivo"] = diag_elast["compensada_propria"] > 0

    S_slutsky = EH.mul(wbar, axis=0)
    S = S_slutsky.to_numpy(dtype=float)
    max_assimetria_slutsky = float(np.nanmax(np.abs(S - S.T)))
    autovalores = np.linalg.eigvalsh((S + S.T) / 2)

    regularidade = pd.DataFrame(
        {
            "criterio": [
                "max_assimetria_wi_EHij",
                *[f"autovalor_slutsky_{i}" for i in range(1, len(autovalores) + 1)],
                "curvatura_negativa_semidefinida",
            ],
            "valor": [
                max_assimetria_slutsky,
                *autovalores.tolist(),
                float(np.all(autovalores <= 1e-8)),
            ],
        }
    )

    write_csv(resumo, cfg.tagged_table("diagnostico_modelos"))
    write_csv(testes_J_diff, cfg.tagged_table("diagnostico_testes_J_diff"))
    write_csv(diag_elast, cfg.tagged_table("diagnostico_elasticidades_economicidade"))
    write_csv(regularidade, cfg.tagged_table("diagnostico_regularidade"))

    print(resumo)
    print(testes_J_diff)
    print(diag_elast)
    print(regularidade)

    return {
        "resumo": resumo,
        "testes_J_diff": testes_J_diff,
        "diag_elast": diag_elast,
        "regularidade": regularidade,
    }


if __name__ == "__main__":
    run_diagnostics()
