"""
Plots comparativos avançados entre Stata, R e Python.

Objetivo
--------
Este script melhora os gráficos comparativos do pacote de replicação. Em vez de
sobrepor Stata/R/Python no mesmo eixo — o que pode esconder linhas quando os
resultados são muito parecidos — ele gera gráficos em painéis, com um subplot
para cada software.

Também gera tabelas e gráficos adicionais para comparar os resultados:
  1. painéis por software para beta_p, erro-padrão, F usual, F efetivo MOP,
     p-valor de beta_p e p-valor Hansen J;
  2. gráfico de intervalos AR, incluindo intervalos abertos quando disponíveis;
  3. diferenças em relação ao Stata para beta_p, se_p, F_usual, F_eff e Hansen p;
  4. resumo de MAE/RMSE/desvio máximo por software e métrica;
  5. heatmaps de diferenças absolutas e relativas em relação ao Stata;
  6. gráficos de dispersão R/Python versus Stata com linha de 45 graus.

Como usar a partir da raiz do pacote
------------------------------------
    python Comparativo/02_plots_comparativos_software_avancado.py

Ou, explicitando diretórios:
    python Comparativo/02_plots_comparativos_software_avancado.py \
        --tables-dir output/tables \
        --figures-dir output/figures/comparative_software_advanced

Também aceita um zip com a pasta tables/:
    python Comparativo/02_plots_comparativos_software_avancado.py \
        --tables-zip tables.zip
"""

from __future__ import annotations

import argparse
import math
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple
from datetime import datetime

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


# ---------------------------------------------------------------------
# Configurações gerais
# ---------------------------------------------------------------------
MODEL_ORDER = [f"Z{i}" for i in range(1, 8)]
SOFTWARE_ORDER = ["Stata", "R", "Python"]

METRICS_MAIN = [
    "beta_p", "se_p", "pval_p", "F_usual", "p_F", "F_eff_MOP", "hansen_p"
]

METRIC_LABELS = {
    "beta_p": r"$\beta_p$",
    "se_p": r"Erro-padrão robusto de $\beta_p$",
    "pval_p": r"p-valor de $\beta_p$",
    "F_usual": "F usual do primeiro estágio",
    "p_F": "p-valor do F usual",
    "F_eff_MOP": "F efetivo MOP",
    "hansen_p": "p-valor do teste J de Hansen",
}

REFERENCE_LINES = {
    "beta_p": [(0.0, "zero")],
    "pval_p": [(0.05, "p = 0,05")],
    "F_usual": [(10.0, "F = 10")],
    "p_F": [(0.05, "p = 0,05")],
    "hansen_p": [(0.05, "p = 0,05")],
}

QUESTION09_PATTERNS = {
    "Stata": ["stata_question_09_comparative.csv", "stata_iv_results_weakivtest.csv", "stata_iv_results.csv"],
    "R": ["r_question_09_comparative.csv", "r_iv_results.csv"],
    "Python": ["python_question_09_comparative.csv", "python_iv_results.csv"],
}

QUESTION11_PATTERNS = {
    "Stata": ["stata_question_11_ar_intervals.csv"],
    "R": ["r_question_11_ar_intervals.csv"],
    "Python": ["python_question_11_ar_intervals.csv"],
}

COLUMN_ALIASES = {
    # identificação
    "model": "model", "modelo": "model", "instrumentos": "model", "instruments": "model", "spec": "model",
    # amostra/instrumentos
    "n": "N", "N": "N", "obs": "N", "observations": "N",
    "k": "k_inst", "k_inst": "k_inst", "n_inst": "k_inst", "num_inst": "k_inst",
    # coeficiente/precisão
    "beta_p": "beta_p", "b": "beta_p", "coef": "beta_p", "coefficient": "beta_p", "estimate": "beta_p", "ln_pch": "beta_p",
    "se_p": "se_p", "se": "se_p", "std_err": "se_p", "stderr": "se_p", "std.error": "se_p", "robust_se": "se_p",
    "pval_p": "pval_p", "p_value": "pval_p", "pval": "pval_p", "p_beta": "pval_p",
    # intervalos convencionais
    "ci_low": "ci_low", "ci_lower": "ci_low", "lower": "ci_low", "lb": "ci_low", "low_95": "ci_low",
    "ci_high": "ci_high", "ci_upper": "ci_high", "upper": "ci_high", "ub": "ci_high", "high_95": "ci_high",
    # primeiro estágio / MOP
    "F_usual": "F_usual", "f_usual": "F_usual", "F_first": "F_usual", "first_stage_F": "F_usual", "first_stage_f": "F_usual",
    "p_F": "p_F", "p_f": "p_F", "p_first": "p_F",
    "F_eff": "F_eff_MOP", "f_eff": "F_eff_MOP", "F_eff_MOP": "F_eff_MOP", "f_eff_mop": "F_eff_MOP", "mop_f": "F_eff_MOP",
    "cv5": "cv5", "cv10": "cv10", "cv20": "cv20",
    # Hansen
    "hansen_J": "hansen_J", "hansen_j": "hansen_J", "J": "hansen_J", "j": "hansen_J",
    "hansen_p": "hansen_p", "Hansen_p": "hansen_p", "jp": "hansen_p", "J_p": "hansen_p", "p_J": "hansen_p", "p_hansen": "hansen_p",
    # AR
    "ar_low": "ar_low", "ar_high": "ar_high",
    "ar_low_grid": "ar_low_grid", "ar_high_grid": "ar_high_grid",
    "beta0_minp": "beta0_minp", "p_min": "p_min", "p_max": "p_max",
    "grid_min": "grid_min", "grid_max": "grid_max", "grid_step": "grid_step",
    "open_left": "open_left", "open_right": "open_right", "empty_interval": "empty_interval",
    "n_expand": "n_expand", "npoints_final": "npoints_final",
}

NUMERIC_COLUMNS_Q09 = [
    "N", "k_inst", "beta_p", "se_p", "pval_p", "ci_low", "ci_high",
    "F_usual", "p_F", "F_eff_MOP", "cv5", "cv10", "cv20", "hansen_J", "hansen_p",
]

NUMERIC_COLUMNS_AR = [
    "N", "k_inst", "ar_low", "ar_high", "ar_low_grid", "ar_high_grid", "beta0_minp",
    "p_min", "p_max", "grid_min", "grid_max", "grid_step", "n_expand", "npoints_final",
    "open_left", "open_right", "empty_interval",
]


def log_step(message: str) -> None:
    print(f"\n[Comparativo avançado | {datetime.now():%H:%M:%S}] {message}", flush=True)


def _read_csv_flex(path: Path) -> pd.DataFrame:
    try:
        df = pd.read_csv(path)
        if len(df.columns) == 1:
            df = pd.read_csv(path, sep=";")
    except UnicodeDecodeError:
        df = pd.read_csv(path, encoding="latin1")
        if len(df.columns) == 1:
            df = pd.read_csv(path, sep=";", encoding="latin1")
    return df


def _to_numeric(series: pd.Series) -> pd.Series:
    if series.dtype == object:
        cleaned = (
            series.astype(str)
            .str.strip()
            .str.replace("%", "", regex=False)
            .str.replace(" ", "", regex=False)
            .str.replace(",", ".", regex=False)
            .replace({"": np.nan, ".": np.nan, "nan": np.nan, "None": np.nan, "NA": np.nan})
        )
        return pd.to_numeric(cleaned, errors="coerce")
    return pd.to_numeric(series, errors="coerce")


def _standardize_columns(df: pd.DataFrame) -> pd.DataFrame:
    rename = {}
    for col in df.columns:
        key = str(col).strip()
        rename[col] = COLUMN_ALIASES.get(key, COLUMN_ALIASES.get(key.lower(), key))
    return df.rename(columns=rename)


def _standardize_model_column(df: pd.DataFrame) -> pd.DataFrame:
    if "model" not in df.columns:
        df = df.copy()
        df["model"] = [f"Z{i}" for i in range(1, len(df) + 1)]

    df = df.copy()
    df["model"] = (
        df["model"].astype(str)
        .str.strip()
        .str.upper()
        .str.replace(" ", "", regex=False)
        .str.replace("GMM_", "", regex=False)
        .str.replace("2SLS_", "", regex=False)
    )
    df = df[df["model"].isin(MODEL_ORDER)].copy()
    df["model"] = pd.Categorical(df["model"], categories=MODEL_ORDER, ordered=True)
    return df.sort_values("model")


def _candidate_paths(tables_dir: Path, software: str, patterns: Dict[str, List[str]]) -> List[Path]:
    names = patterns[software]
    candidates: List[Path] = []

    for name in names:
        candidates.append(tables_dir / name)

    for subdir in [software, software.lower(), software.upper()]:
        for name in names:
            candidates.append(tables_dir / subdir / name)

    if tables_dir.exists():
        for name in names:
            candidates.extend(tables_dir.rglob(name))

    unique: List[Path] = []
    seen = set()
    for path in candidates:
        key = str(path.resolve()) if path.exists() else str(path)
        if key not in seen:
            seen.add(key)
            unique.append(path)
    return unique


def _choose_best_path(tables_dir: Path, software: str, patterns: Dict[str, List[str]]) -> Optional[Path]:
    existing = [p for p in _candidate_paths(tables_dir, software, patterns) if p.exists()]
    if not existing:
        return None

    def score(path: Path) -> Tuple[int, float]:
        name = path.name.lower()
        priority = 0
        if "question_09_comparative" in name or "question_11_ar" in name:
            priority += 100
        if software.lower() in name:
            priority += 10
        return priority, path.stat().st_mtime

    return sorted(existing, key=score, reverse=True)[0]


def read_question09(tables_dir: Path) -> Tuple[pd.DataFrame, Dict[str, Optional[Path]]]:
    frames: List[pd.DataFrame] = []
    used: Dict[str, Optional[Path]] = {}

    for software in SOFTWARE_ORDER:
        path = _choose_best_path(tables_dir, software, QUESTION09_PATTERNS)
        used[software] = path
        if path is None:
            continue
        raw = _read_csv_flex(path)
        df = _standardize_columns(raw)
        for col in NUMERIC_COLUMNS_Q09:
            if col not in df.columns:
                df[col] = np.nan
            df[col] = _to_numeric(df[col])
        df = _standardize_model_column(df)
        if df.empty:
            continue
        missing_ci = df["ci_low"].isna() | df["ci_high"].isna()
        can_build_ci = df["beta_p"].notna() & df["se_p"].notna()
        idx = missing_ci & can_build_ci
        df.loc[idx, "ci_low"] = df.loc[idx, "beta_p"] - 1.96 * df.loc[idx, "se_p"]
        df.loc[idx, "ci_high"] = df.loc[idx, "beta_p"] + 1.96 * df.loc[idx, "se_p"]
        df["software"] = software
        frames.append(df)

    if not frames:
        raise FileNotFoundError(f"Nenhuma tabela da questão 09 encontrada em {tables_dir}.")

    out = pd.concat(frames, ignore_index=True)
    out["software"] = pd.Categorical(out["software"], categories=SOFTWARE_ORDER, ordered=True)
    out = out.sort_values(["model", "software"])
    return out, used


def read_question11_ar(tables_dir: Path) -> Tuple[pd.DataFrame, Dict[str, Optional[Path]]]:
    frames: List[pd.DataFrame] = []
    used: Dict[str, Optional[Path]] = {}

    for software in SOFTWARE_ORDER:
        path = _choose_best_path(tables_dir, software, QUESTION11_PATTERNS)
        used[software] = path
        if path is None:
            continue
        raw = _read_csv_flex(path)
        df = _standardize_columns(raw)
        for col in NUMERIC_COLUMNS_AR:
            if col not in df.columns:
                df[col] = np.nan
            df[col] = _to_numeric(df[col])
        df = _standardize_model_column(df)
        if df.empty:
            continue
        df["software"] = software
        frames.append(df)

    if not frames:
        return pd.DataFrame(), used

    out = pd.concat(frames, ignore_index=True)
    out["software"] = pd.Categorical(out["software"], categories=SOFTWARE_ORDER, ordered=True)
    out = out.sort_values(["model", "software"])
    return out, used


def _x_positions(models: Iterable[str]) -> np.ndarray:
    pos = {m: i for i, m in enumerate(MODEL_ORDER)}
    return np.asarray([pos[str(m)] for m in models], dtype=float)


def _global_ylim(df: pd.DataFrame, metric: str, include_ci: bool = False) -> Optional[Tuple[float, float]]:
    values: List[float] = []
    if metric in df.columns:
        values.extend(df[metric].dropna().astype(float).tolist())
    if include_ci and {"ci_low", "ci_high"}.issubset(df.columns):
        values.extend(df["ci_low"].dropna().astype(float).tolist())
        values.extend(df["ci_high"].dropna().astype(float).tolist())
    for ref, _ in REFERENCE_LINES.get(metric, []):
        values.append(ref)
    values = [v for v in values if np.isfinite(v)]
    if not values:
        return None
    lo, hi = min(values), max(values)
    if lo == hi:
        pad = abs(lo) * 0.1 + 1.0
    else:
        pad = (hi - lo) * 0.12
    return lo - pad, hi + pad


def _add_references(ax, metric: str) -> None:
    for y, label in REFERENCE_LINES.get(metric, []):
        ax.axhline(y, linestyle="--", linewidth=1, alpha=0.8)
        ax.text(0.01, y, f" {label}", transform=ax.get_yaxis_transform(), va="bottom", fontsize=8)


def plot_metric_facets(
    df: pd.DataFrame,
    metric: str,
    out_path: Path,
    title: str,
    ylabel: str,
    with_ci: bool = False,
) -> None:
    if metric not in df.columns or not df[metric].notna().any():
        return

    ylims = _global_ylim(df, metric, include_ci=with_ci)
    fig, axes = plt.subplots(1, len(SOFTWARE_ORDER), figsize=(15, 4.8), sharey=True)

    for ax, software in zip(axes, SOFTWARE_ORDER):
        sub = df[(df["software"] == software) & df[metric].notna()].copy()
        ax.set_title(software)
        ax.set_xticks(range(len(MODEL_ORDER)))
        ax.set_xticklabels(MODEL_ORDER)
        ax.grid(axis="y", alpha=0.25)
        _add_references(ax, metric)

        if sub.empty:
            ax.text(0.5, 0.5, "sem dados", ha="center", va="center", transform=ax.transAxes)
            continue

        x = _x_positions(sub["model"].astype(str))
        y = sub[metric].astype(float).to_numpy()
        if with_ci and {"ci_low", "ci_high"}.issubset(sub.columns):
            yerr = np.vstack([
                y - sub["ci_low"].astype(float).to_numpy(),
                sub["ci_high"].astype(float).to_numpy() - y,
            ])
            ax.errorbar(x, y, yerr=yerr, marker="o", capsize=4, linewidth=1.5)
        else:
            ax.plot(x, y, marker="o", linewidth=1.8)

        for xi, yi in zip(x, y):
            if np.isfinite(yi):
                ax.annotate(f"{yi:.3g}", (xi, yi), textcoords="offset points", xytext=(0, 7), ha="center", fontsize=8)

    if ylims is not None:
        axes[0].set_ylim(*ylims)
    axes[0].set_ylabel(ylabel)
    fig.suptitle(title, y=1.03, fontsize=14)
    fig.tight_layout()
    fig.savefig(out_path, dpi=300, bbox_inches="tight")
    plt.close(fig)


def plot_beta_facets(df: pd.DataFrame, figs_dir: Path) -> None:
    plot_metric_facets(
        df, "beta_p", figs_dir / "facet_beta_p_ci_by_software.png",
        title=r"$\beta_p$ e IC 95% por software", ylabel=r"$\beta_p$", with_ci=True,
    )


def plot_all_metric_facets(df: pd.DataFrame, figs_dir: Path) -> None:
    plot_beta_facets(df, figs_dir)
    plot_metric_facets(df, "se_p", figs_dir / "facet_standard_errors_by_software.png",
                       "Precisão convencional por software", METRIC_LABELS["se_p"])
    plot_metric_facets(df, "pval_p", figs_dir / "facet_pval_beta_p_by_software.png",
                       r"p-valor de $\beta_p$ por software", METRIC_LABELS["pval_p"])
    plot_metric_facets(df, "F_usual", figs_dir / "facet_first_stage_F_usual_by_software.png",
                       "F usual do primeiro estágio por software", METRIC_LABELS["F_usual"])
    plot_metric_facets(df, "p_F", figs_dir / "facet_first_stage_p_value_by_software.png",
                       "p-valor do F usual por software", METRIC_LABELS["p_F"])
    plot_metric_facets(df, "F_eff_MOP", figs_dir / "facet_F_eff_MOP_by_software.png",
                       "F efetivo MOP por software", METRIC_LABELS["F_eff_MOP"])
    plot_metric_facets(df, "hansen_p", figs_dir / "facet_hansen_p_by_software.png",
                       "p-valor do teste J de Hansen por software", METRIC_LABELS["hansen_p"])


def plot_ar_intervals_facets(ar: pd.DataFrame, figs_dir: Path) -> None:
    if ar.empty or not {"ar_low", "ar_high"}.intersection(ar.columns):
        return

    # Determina escala usando limites reais e limites observados na grade.
    values = []
    for col in ["ar_low", "ar_high", "ar_low_grid", "ar_high_grid"]:
        if col in ar.columns:
            values.extend(ar[col].dropna().astype(float).tolist())
    values = [v for v in values if np.isfinite(v)]
    if not values:
        return
    lo, hi = min(values), max(values)
    pad = (hi - lo) * 0.15 if hi > lo else 1.0

    fig, axes = plt.subplots(1, len(SOFTWARE_ORDER), figsize=(15, 4.8), sharex=True, sharey=True)
    for ax, software in zip(axes, SOFTWARE_ORDER):
        sub = ar[ar["software"] == software].copy()
        ax.set_title(software)
        ax.axvline(0, linewidth=1, alpha=0.5)
        ax.grid(axis="x", alpha=0.25)
        ax.set_yticks(range(len(MODEL_ORDER)))
        ax.set_yticklabels(MODEL_ORDER)

        if sub.empty:
            ax.text(0.5, 0.5, "sem dados", ha="center", va="center", transform=ax.transAxes)
            continue

        for _, row in sub.iterrows():
            model = str(row["model"])
            y = MODEL_ORDER.index(model)
            empty = bool(row.get("empty_interval", 0) == 1) if not pd.isna(row.get("empty_interval", np.nan)) else False
            if empty:
                ax.text(0, y, "vazio", va="center", ha="center", fontsize=8)
                continue

            left_open = bool(row.get("open_left", 0) == 1) if not pd.isna(row.get("open_left", np.nan)) else False
            right_open = bool(row.get("open_right", 0) == 1) if not pd.isna(row.get("open_right", np.nan)) else False
            left = row.get("ar_low", np.nan)
            right = row.get("ar_high", np.nan)
            left_grid = row.get("ar_low_grid", np.nan)
            right_grid = row.get("ar_high_grid", np.nan)
            if pd.isna(left):
                left = left_grid if not pd.isna(left_grid) else lo
            if pd.isna(right):
                right = right_grid if not pd.isna(right_grid) else hi
            if pd.isna(left) or pd.isna(right):
                continue

            ax.hlines(y, float(left), float(right), linewidth=3)
            ax.plot(float(left), y, marker="<" if left_open else "|", markersize=9)
            ax.plot(float(right), y, marker=">" if right_open else "|", markersize=9)
            label_l = "-∞" if left_open else f"{float(left):.3g}"
            label_r = "+∞" if right_open else f"{float(right):.3g}"
            ax.text(float(right), y + 0.13, f"[{label_l}, {label_r}]", fontsize=8, ha="right")

    axes[0].set_xlim(lo - pad, hi + pad)
    axes[0].set_ylabel("Modelo")
    fig.suptitle("Intervalos Anderson-Rubin por software", y=1.03, fontsize=14)
    fig.tight_layout()
    fig.savefig(figs_dir / "facet_AR_intervals_by_software.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def compute_differences_vs_stata(df: pd.DataFrame, metrics: Sequence[str]) -> pd.DataFrame:
    stata = df[df["software"] == "Stata"][["model"] + [m for m in metrics if m in df.columns]].copy()
    if stata.empty:
        return pd.DataFrame()
    stata = stata.rename(columns={m: f"{m}_stata" for m in metrics if m in stata.columns})

    rows = []
    for software in ["R", "Python"]:
        sub = df[df["software"] == software][["model"] + [m for m in metrics if m in df.columns]].copy()
        if sub.empty:
            continue
        merged = sub.merge(stata, on="model", how="inner")
        for _, row in merged.iterrows():
            for m in metrics:
                if m not in sub.columns or f"{m}_stata" not in merged.columns:
                    continue
                val = row.get(m, np.nan)
                base = row.get(f"{m}_stata", np.nan)
                if pd.isna(val) or pd.isna(base):
                    continue
                diff = float(val) - float(base)
                abs_diff = abs(diff)
                rel = abs_diff / max(abs(float(base)), 1e-12)
                rows.append({
                    "software": software,
                    "model": row["model"],
                    "metric": m,
                    "value": float(val),
                    "stata_value": float(base),
                    "diff_vs_stata": diff,
                    "abs_diff_vs_stata": abs_diff,
                    "rel_abs_diff_vs_stata": rel,
                })
    return pd.DataFrame(rows)


def compute_accuracy_summary(diff: pd.DataFrame) -> pd.DataFrame:
    if diff.empty:
        return pd.DataFrame()
    return (
        diff.groupby(["software", "metric"], observed=False)
        .agg(
            n=("abs_diff_vs_stata", "count"),
            mae=("abs_diff_vs_stata", "mean"),
            rmse=("diff_vs_stata", lambda x: math.sqrt(np.mean(np.square(x)))),
            max_abs=("abs_diff_vs_stata", "max"),
            mean_relative_abs=("rel_abs_diff_vs_stata", "mean"),
        )
        .reset_index()
        .sort_values(["metric", "software"])
    )


def plot_difference_heatmap(diff: pd.DataFrame, figs_dir: Path, column: str, filename: str, title: str) -> None:
    if diff.empty or column not in diff.columns:
        return
    temp = diff.copy()
    temp["row"] = temp["software"].astype(str) + " - " + temp["metric"].astype(str)
    pivot = temp.pivot_table(index="row", columns="model", values=column, aggfunc="mean", observed=False)
    pivot = pivot.reindex(columns=MODEL_ORDER)
    if pivot.empty:
        return

    fig_h = max(4.5, 0.35 * len(pivot.index) + 1.5)
    fig, ax = plt.subplots(figsize=(10, fig_h))
    im = ax.imshow(pivot.to_numpy(dtype=float), aspect="auto")
    ax.set_xticks(range(len(pivot.columns)))
    ax.set_xticklabels(pivot.columns)
    ax.set_yticks(range(len(pivot.index)))
    ax.set_yticklabels(pivot.index)
    ax.set_title(title)
    cbar = fig.colorbar(im, ax=ax)
    cbar.ax.set_ylabel(column)

    data = pivot.to_numpy(dtype=float)
    for i in range(data.shape[0]):
        for j in range(data.shape[1]):
            val = data[i, j]
            if np.isfinite(val):
                ax.text(j, i, f"{val:.2g}", ha="center", va="center", fontsize=7)
    fig.tight_layout()
    fig.savefig(figs_dir / filename, dpi=300, bbox_inches="tight")
    plt.close(fig)


def plot_mae_summary(summary: pd.DataFrame, figs_dir: Path) -> None:
    if summary.empty:
        return

    metrics = [m for m in METRICS_MAIN if m in summary["metric"].unique()]
    if not metrics:
        metrics = sorted(summary["metric"].unique())
    x = np.arange(len(metrics))
    width = 0.35

    fig, ax = plt.subplots(figsize=(11, 5.2))
    for i, software in enumerate(["R", "Python"]):
        sub = summary[summary["software"] == software].set_index("metric")
        vals = [sub.loc[m, "mae"] if m in sub.index else np.nan for m in metrics]
        ax.bar(x + (i - 0.5) * width, vals, width=width, label=software)

    ax.set_xticks(x)
    ax.set_xticklabels([METRIC_LABELS.get(m, m) for m in metrics], rotation=25, ha="right")
    ax.set_ylabel("MAE em relação ao Stata")
    ax.set_title("Erro absoluto médio das saídas em relação ao Stata")
    ax.legend()
    ax.grid(axis="y", alpha=0.25)
    fig.tight_layout()
    fig.savefig(figs_dir / "summary_MAE_vs_Stata_by_metric.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def plot_scatter_vs_stata(df: pd.DataFrame, figs_dir: Path, metrics: Sequence[str]) -> None:
    stata = df[df["software"] == "Stata"].copy()
    if stata.empty:
        return
    for metric in metrics:
        if metric not in df.columns or not df[metric].notna().any():
            continue
        base = stata[["model", metric]].rename(columns={metric: "stata"})
        fig, ax = plt.subplots(figsize=(6, 5.5))
        plotted = False
        vals_all = []
        for software in ["R", "Python"]:
            sub = df[df["software"] == software][["model", metric]].rename(columns={metric: "value"})
            merged = sub.merge(base, on="model", how="inner").dropna()
            if merged.empty:
                continue
            plotted = True
            ax.scatter(merged["stata"], merged["value"], label=software)
            for _, row in merged.iterrows():
                ax.annotate(str(row["model"]), (row["stata"], row["value"]), textcoords="offset points", xytext=(4, 4), fontsize=8)
            vals_all.extend(merged["stata"].tolist())
            vals_all.extend(merged["value"].tolist())
        if not plotted:
            plt.close(fig)
            continue
        vals_all = [float(v) for v in vals_all if np.isfinite(v)]
        lo, hi = min(vals_all), max(vals_all)
        pad = (hi - lo) * 0.1 if hi > lo else 1.0
        ax.plot([lo - pad, hi + pad], [lo - pad, hi + pad], linestyle="--", linewidth=1)
        ax.set_xlim(lo - pad, hi + pad)
        ax.set_ylim(lo - pad, hi + pad)
        ax.set_xlabel(f"Stata: {METRIC_LABELS.get(metric, metric)}")
        ax.set_ylabel(f"R/Python: {METRIC_LABELS.get(metric, metric)}")
        ax.set_title(f"R/Python versus Stata — {METRIC_LABELS.get(metric, metric)}")
        ax.legend()
        ax.grid(alpha=0.25)
        fig.tight_layout()
        fig.savefig(figs_dir / f"scatter_vs_Stata_{metric}.png", dpi=300, bbox_inches="tight")
        plt.close(fig)


def write_markdown_report(
    figs_dir: Path,
    docs_dir: Path,
    used_q09: Dict[str, Optional[Path]],
    used_ar: Dict[str, Optional[Path]],
    df: pd.DataFrame,
    diff: pd.DataFrame,
    summary: pd.DataFrame,
) -> None:
    docs_dir.mkdir(parents=True, exist_ok=True)
    lines = []
    lines.append("# Relatório dos plots comparativos avançados\n\n")
    lines.append("## Arquivos usados — Questão 09\n\n")
    for software in SOFTWARE_ORDER:
        path = used_q09.get(software)
        lines.append(f"- {software}: {path if path is not None else 'não encontrado'}\n")
    lines.append("\n## Arquivos usados — Questão 11 / AR\n\n")
    for software in SOFTWARE_ORDER:
        path = used_ar.get(software)
        lines.append(f"- {software}: {path if path is not None else 'não encontrado'}\n")

    lines.append("\n## Gráficos gerados\n\n")
    for p in sorted(figs_dir.glob("*.png")):
        lines.append(f"- `{p.name}`\n")

    if not summary.empty:
        lines.append("\n## Resumo MAE/RMSE em relação ao Stata\n\n")
        lines.append(summary.to_markdown(index=False))
        lines.append("\n")

    if diff.empty:
        lines.append("\nNão foi possível calcular diferenças contra Stata; verifique se a tabela do Stata está disponível.\n")

    (docs_dir / "relatorio_plots_comparativos_avancado.md").write_text("".join(lines), encoding="utf-8")


def _infer_root_from_script() -> Path:
    here = Path(__file__).resolve()
    candidates = [here.parent, here.parent.parent, Path.cwd()]
    for cand in candidates:
        if (cand / "output" / "tables").exists() or (cand / "data").exists():
            return cand
    return Path.cwd()


def _extract_tables_zip(zip_path: Path) -> tempfile.TemporaryDirectory:
    temp = tempfile.TemporaryDirectory()
    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(temp.name)
    return temp


def parse_args() -> argparse.Namespace:
    root = _infer_root_from_script()
    parser = argparse.ArgumentParser(description="Plots comparativos avançados Stata/R/Python.")
    parser.add_argument("--tables-dir", type=Path, default=root / "output" / "tables",
                        help="Diretório com as tabelas CSV. Padrão: output/tables.")
    parser.add_argument("--tables-zip", type=Path, default=None,
                        help="Opcional: zip contendo uma pasta tables/ com os CSVs.")
    parser.add_argument("--figures-dir", type=Path, default=root / "output" / "figures" / "comparative_software_advanced",
                        help="Diretório de saída dos gráficos.")
    parser.add_argument("--docs-dir", type=Path, default=root / "docs",
                        help="Diretório de saída do relatório markdown.")
    parser.add_argument("--output-tables-dir", type=Path, default=root / "output" / "tables",
                        help="Diretório onde as tabelas consolidadas serão salvas.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    temp_dir_obj: Optional[tempfile.TemporaryDirectory] = None
    tables_dir = args.tables_dir
    if args.tables_zip is not None:
        log_step(f"Extraindo zip de tabelas: {args.tables_zip}")
        temp_dir_obj = _extract_tables_zip(args.tables_zip)
        extracted_root = Path(temp_dir_obj.name)
        if (extracted_root / "tables").exists():
            tables_dir = extracted_root / "tables"
        else:
            tables_dir = extracted_root

    figs_dir = args.figures_dir
    docs_dir = args.docs_dir
    out_tables = args.output_tables_dir
    figs_dir.mkdir(parents=True, exist_ok=True)
    docs_dir.mkdir(parents=True, exist_ok=True)
    out_tables.mkdir(parents=True, exist_ok=True)

    log_step(f"Lendo tabelas em: {tables_dir}")
    df, used_q09 = read_question09(tables_dir)
    ar, used_ar = read_question11_ar(tables_dir)

    df.to_csv(out_tables / "comparative_software_results_advanced.csv", index=False)
    if not ar.empty:
        ar.to_csv(out_tables / "comparative_AR_intervals_advanced.csv", index=False)

    log_step("Gerando painéis por software")
    plot_all_metric_facets(df, figs_dir)
    plot_ar_intervals_facets(ar, figs_dir)

    log_step("Calculando diferenças contra Stata")
    metrics = [m for m in METRICS_MAIN if m in df.columns]
    diff = compute_differences_vs_stata(df, metrics)
    summary = compute_accuracy_summary(diff)
    if not diff.empty:
        diff.to_csv(out_tables / "comparative_differences_vs_stata_long.csv", index=False)
        plot_difference_heatmap(
            diff, figs_dir, "abs_diff_vs_stata", "heatmap_abs_diff_vs_Stata.png",
            "Diferença absoluta em relação ao Stata"
        )
        plot_difference_heatmap(
            diff, figs_dir, "rel_abs_diff_vs_stata", "heatmap_relative_abs_diff_vs_Stata.png",
            "Diferença relativa absoluta em relação ao Stata"
        )
        plot_scatter_vs_stata(df, figs_dir, ["beta_p", "se_p", "F_usual", "F_eff_MOP", "hansen_p"])
    if not summary.empty:
        summary.to_csv(out_tables / "comparative_accuracy_summary_vs_stata.csv", index=False)
        plot_mae_summary(summary, figs_dir)

    write_markdown_report(figs_dir, docs_dir, used_q09, used_ar, df, diff, summary)

    log_step(f"Gráficos gerados em: {figs_dir}")
    log_step(f"Tabelas consolidadas em: {out_tables}")
    log_step(f"Relatório em: {docs_dir / 'relatorio_plots_comparativos_avancado.md'}")

    if temp_dir_obj is not None:
        temp_dir_obj.cleanup()


if __name__ == "__main__":
    main()
