"""Resume diferenças máximas entre Python e Stata já comparados."""

from __future__ import annotations

import pandas as pd

from .config import AIDSConfig, default_config
from .utils import read_csv_if_exists, write_csv


def summarize_comparison(cfg: AIDSConfig | None = None) -> pd.DataFrame:
    cfg = cfg or default_config()
    cfg.ensure_dirs()
    tag = cfg.output_tag

    def ler(nome: str) -> pd.DataFrame | None:
        path = cfg.tables / nome
        if not path.exists():
            print(f"Arquivo não encontrado: {path}")
            return None
        return pd.read_csv(path)

    coef = ler(f"comparacao_{tag}_vs_Stata_coeficientes.csv")
    eta = ler(f"comparacao_{tag}_vs_Stata_elasticidades_dispendio.csv")
    em = ler(f"comparacao_{tag}_vs_Stata_elasticidades_marshallianas.csv")
    eh = ler(f"comparacao_{tag}_vs_Stata_elasticidades_compensadas.csv")

    resumos: list[pd.DataFrame] = []
    if coef is not None and not coef.empty:
        cols = [c for c in ["abs_dif_estimativa", "abs_dif_erro_padrao", "abs_dif_estat_t"] if c in coef.columns]
        if cols:
            out = coef.groupby("modelo", as_index=False)[cols].max()
            out.insert(0, "grupo", "coeficientes")
            resumos.append(out)

    if eta is not None and not eta.empty:
        col = "abs_dif_eta" if "abs_dif_eta" in eta.columns else None
        if col:
            resumos.append(pd.DataFrame({"grupo": ["elasticidade_dispendio"], "objeto": ["elasticidade_dispendio"], "max_abs_dif": [eta[col].max(skipna=True)]}))

    def max_dif_matriz(df: pd.DataFrame, nome: str) -> pd.DataFrame:
        cols = [c for c in df.columns if c.startswith("abs_dif_")]
        if not cols:
            return pd.DataFrame({"grupo": [nome], "objeto": [nome], "max_abs_dif": [pd.NA]})
        return pd.DataFrame({"grupo": [nome], "objeto": [nome], "max_abs_dif": [df[cols].max().max()]})

    if em is not None:
        resumos.append(max_dif_matriz(em, "marshallianas"))
    if eh is not None:
        resumos.append(max_dif_matriz(eh, "compensadas"))

    saida = pd.concat(resumos, ignore_index=True, sort=False) if resumos else pd.DataFrame()
    write_csv(saida, cfg.tables / f"resumo_comparacao_{tag}_vs_Stata.csv")
    print(saida)
    return saida


if __name__ == "__main__":
    summarize_comparison()
