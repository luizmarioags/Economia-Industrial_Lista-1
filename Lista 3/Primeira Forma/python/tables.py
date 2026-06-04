# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Exporta tabelas padronizadas em CSV e TEX para outputs/python/tables.
# Toda tabela substantiva usa o mesmo nome-base em CSV e TEX.
# Matrizes de elasticidades são salvas em formato longo para comparabilidade entre Python, R e Stata.

from pathlib import Path
import pandas as pd
from config import TAB_CSV, TAB_TEX


def _escape_latex_text(value):
    s = str(value)
    repl = {
        "\\": r"\textbackslash{}",
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
        "~": r"\textasciitilde{}",
        "^": r"\textasciicircum{}",
    }
    for old, new in repl.items():
        s = s.replace(old, new)
    return s


def dataframe_to_latex(df, path, caption=None, label=None, digits=4):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    d = df.copy()
    raw_cols = [str(c) for c in d.columns]
    seen = {}
    unique_cols = []
    for c in raw_cols:
        seen[c] = seen.get(c, 0) + 1
        unique_cols.append(c if seen[c] == 1 else f"{c}_{seen[c]}")
    d.columns = unique_cols
    for c in d.columns:
        if d[c].dtype == object:
            d[c] = d[c].map(_escape_latex_text)
    longtable = len(d) > 60
    tex = d.to_latex(
        index=False,
        escape=False,
        float_format=lambda x: f"{x:.{digits}f}",
        longtable=longtable,
    )
    lines = []
    if not longtable:
        lines.append("\\begin{table}[!htbp]\n\\centering")
        if caption:
            lines.append(f"\\caption{{{_escape_latex_text(caption)}}}")
        if label:
            lines.append(f"\\label{{{label}}}")
        lines.append("\\small")
        lines.append(tex)
        lines.append("\\end{table}\n")
    else:
        if caption or label:
            insert = ""
            if caption:
                insert += f"\\caption{{{_escape_latex_text(caption)}}}"
            if label:
                insert += f"\\label{{{label}}}"
            insert += r"\\"
            tex = tex.replace("\\toprule", insert + "\n\\toprule", 1)
        lines.append("\\scriptsize")
        lines.append(tex)
    path.write_text("\n".join(lines), encoding="utf-8")


def save_table(df, name, caption=None, label=None, digits=4):
    csv_path = TAB_CSV / f"{name}.csv"
    tex_path = TAB_TEX / f"{name}.tex"
    df.to_csv(csv_path, index=False)
    dataframe_to_latex(df, tex_path, caption=caption, label=label, digits=digits)
    return csv_path, tex_path


def matrix_to_long(matrix_df, value_name="elasticity"):
    d = matrix_df.copy()
    d.index.name = "row_product"
    return d.reset_index().melt(
        id_vars="row_product",
        var_name="column_product",
        value_name=value_name,
    )
