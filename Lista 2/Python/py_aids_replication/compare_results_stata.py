"""Compara tabelas geradas pelo Python com tabelas exportadas pelo Stata."""

from __future__ import annotations

import numpy as np
import pandas as pd

from .config import AIDSConfig, default_config
from .utils import find_existing, read_csv_if_exists, standardize_table, write_csv


def padroniza_modelos_stata(df: pd.DataFrame | None) -> pd.DataFrame | None:
    if df is None or "modelo" not in df.columns:
        return df
    out = df.copy()
    out["modelo"] = out["modelo"].replace(
        {
            "aids_unrestricted": "irrestrito",
            "aids_homogeneity": "homogeneidade",
            "aids_hsym": "homog_simetria",
            "aids_hsym_L2": "homog_simetria_L2",
        }
    )
    return out


def le_csv_se_existir(path) -> pd.DataFrame | None:
    return standardize_table(read_csv_if_exists(path)) if path is not None else None


def compara_por_chaves(
    r_df: pd.DataFrame | None,
    s_df: pd.DataFrame | None,
    chaves: list[str],
    valores: list[str],
    nome_saida: str,
    cfg: AIDSConfig,
) -> pd.DataFrame | None:
    if r_df is None or s_df is None:
        print(f"Pulando {nome_saida}: arquivo Python ou Stata não encontrado.")
        return None

    chaves = [c for c in chaves if c in r_df.columns and c in s_df.columns]
    valores = [v for v in valores if v in r_df.columns and v in s_df.columns]
    if not chaves or not valores:
        print(f"Pulando {nome_saida}: chaves ou valores não encontrados em ambas as tabelas.")
        return None

    r2 = r_df[chaves + valores].copy().rename(columns={v: f"{v}_PY" for v in valores})
    s2 = s_df[chaves + valores].copy().rename(columns={v: f"{v}_Stata" for v in valores})
    comp = pd.merge(r2, s2, on=chaves, how="outer")

    for v in valores:
        rcol = f"{v}_PY"
        scol = f"{v}_Stata"
        dcol = f"dif_{v}"
        acol = f"abs_dif_{v}"
        comp[dcol] = pd.to_numeric(comp[rcol], errors="coerce") - pd.to_numeric(comp[scol], errors="coerce")
        comp[acol] = comp[dcol].abs()

    write_csv(comp, cfg.tables / nome_saida)
    resumo = pd.DataFrame(
        {
            "tabela": nome_saida,
            "variavel": valores,
            "max_abs_dif": [comp[f"abs_dif_{v}"].max(skipna=True) for v in valores],
        }
    )
    print(resumo)
    return comp


def compare_results(cfg: AIDSConfig | None = None) -> dict[str, pd.DataFrame | None]:
    cfg = cfg or default_config()
    cfg.ensure_dirs()
    tag = cfg.output_tag

    coef_PY = le_csv_se_existir(cfg.tagged_table("coeficientes"))
    coef_Stata = le_csv_se_existir(
        find_existing(
            cfg.tables / name
            for name in [
                "coeficientes_stata.csv",
                "coeficientes_Stata.csv",
                "coeficientes_aids_stata.csv",
                "coeficientes_aids_Stata.csv",
            ]
        )
    )

    comp_PY = le_csv_se_existir(cfg.tagged_table("comparacao_modelos"))
    comp_Stata = le_csv_se_existir(
        find_existing(
            cfg.tables / name
            for name in [
                "comparacao_modelos_stata.csv",
                "comparacao_modelos_Stata.csv",
                "comparacao_aids_stata.csv",
                "comparacao_aids_Stata.csv",
            ]
        )
    )

    em_PY = le_csv_se_existir(cfg.tagged_table("elasticidades_marshallianas_hsym"))
    em_Stata = le_csv_se_existir(
        find_existing(
            cfg.tables / name
            for name in [
                "elasticidades_marshallianas_hsym_stata.csv",
                "elasticidades_marshallianas_hsym_Stata.csv",
                "elasticidades_marshallianas_stata.csv",
                "elasticidades_marshallianas_Stata.csv",
            ]
        )
    )

    eh_PY = le_csv_se_existir(cfg.tagged_table("elasticidades_compensadas_hsym"))
    eh_Stata = le_csv_se_existir(
        find_existing(
            cfg.tables / name
            for name in [
                "elasticidades_compensadas_hsym_stata.csv",
                "elasticidades_compensadas_hsym_Stata.csv",
                "elasticidades_compensadas_stata.csv",
                "elasticidades_compensadas_Stata.csv",
            ]
        )
    )

    eta_PY = le_csv_se_existir(cfg.tagged_table("elasticidade_dispendio_hsym"))
    eta_Stata = le_csv_se_existir(
        find_existing(
            cfg.tables / name
            for name in [
                "elasticidade_dispendio_hsym_stata.csv",
                "elasticidade_dispendio_hsym_Stata.csv",
                "elasticidade_dispendio_stata.csv",
                "elasticidade_dispendio_Stata.csv",
            ]
        )
    )

    coef_Stata = padroniza_modelos_stata(coef_Stata)
    comp_Stata = padroniza_modelos_stata(comp_Stata)
    em_Stata = padroniza_modelos_stata(em_Stata)
    eh_Stata = padroniza_modelos_stata(eh_Stata)
    eta_Stata = padroniza_modelos_stata(eta_Stata)

    outputs = {
        "coeficientes": compara_por_chaves(
            coef_PY,
            coef_Stata,
            chaves=["modelo", "parametro"],
            valores=["estimativa", "erro_padrao", "estat_t", "t", "z"],
            nome_saida=f"comparacao_{tag}_vs_Stata_coeficientes.csv",
            cfg=cfg,
        ),
        "modelos": compara_por_chaves(
            comp_PY,
            comp_Stata,
            chaves=["modelo"],
            valores=["n", "n_empilhado", "parametros", "momentos", "j", "df_j", "p_j"],
            nome_saida=f"comparacao_{tag}_vs_Stata_modelos.csv",
            cfg=cfg,
        ),
        "marshallianas": compara_por_chaves(
            em_PY,
            em_Stata,
            chaves=["produto_linha"],
            valores=["bfvl", "pork", "poult", "fish"],
            nome_saida=f"comparacao_{tag}_vs_Stata_elasticidades_marshallianas.csv",
            cfg=cfg,
        ),
        "compensadas": compara_por_chaves(
            eh_PY,
            eh_Stata,
            chaves=["produto_linha"],
            valores=["bfvl", "pork", "poult", "fish"],
            nome_saida=f"comparacao_{tag}_vs_Stata_elasticidades_compensadas.csv",
            cfg=cfg,
        ),
        "dispendio": compara_por_chaves(
            eta_PY,
            eta_Stata,
            chaves=["produto"],
            valores=["eta", "elasticidade_dispendio"],
            nome_saida=f"comparacao_{tag}_vs_Stata_elasticidades_dispendio.csv",
            cfg=cfg,
        ),
    }

    print(f"Comparação concluída. Veja os arquivos comparacao_{tag}_vs_Stata_*.csv em: {cfg.tables}")
    return outputs


if __name__ == "__main__":
    compare_results()
