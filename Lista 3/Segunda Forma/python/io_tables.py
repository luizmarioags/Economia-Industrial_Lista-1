"""Exportação de tabelas CSV e LaTeX simples."""
from __future__ import annotations
from pathlib import Path
import pandas as pd


def latex_escape(value) -> str:
    s = "" if pd.isna(value) else str(value)
    repl = {
        "\\": r"\textbackslash{}",
        "_": r"\_",
        "%": r"\%",
        "&": r"\&",
        "#": r"\#",
        "$": r"\$",
        "{": r"\{",
        "}": r"\}",
    }
    for a, b in repl.items():
        s = s.replace(a, b)
    return s


def fmt(value, digits: int = 4) -> str:
    if pd.isna(value):
        return ""
    if isinstance(value, (float, int)):
        return f"{value:.{digits}f}"
    return latex_escape(value)


def write_latex_table(df: pd.DataFrame, path: Path, caption: str, label: str, digits: int = 4) -> None:
    align = "l" + "r" * max(0, len(df.columns) - 1)
    lines = [
        "% Tabela gerada automaticamente pela replicação em Python",
        r"\begingroup",
        r"\scriptsize",
        rf"\begin{{longtable}}{{@{{}}{align}@{{}}}}",
        rf"\caption{{{latex_escape(caption)}}}\label{{{label}}}\\",
        r"\toprule",
        " & ".join(latex_escape(c) for c in df.columns) + r" \\",
        r"\midrule",
        r"\endfirsthead",
        r"\toprule",
        " & ".join(latex_escape(c) for c in df.columns) + r" \\",
        r"\midrule",
        r"\endhead",
    ]
    for _, row in df.iterrows():
        lines.append(" & ".join(fmt(v, digits) for v in row.tolist()) + r" \\")
    lines += [r"\bottomrule", r"\end{longtable}", r"\endgroup"]
    path.write_text("\n".join(lines), encoding="utf-8")


def export_csv_tex(df: pd.DataFrame, csv_path: Path, tex_path: Path, caption: str, label: str, digits: int = 4) -> None:
    df.to_csv(csv_path, index=False)
    write_latex_table(df, tex_path, caption, label, digits)
