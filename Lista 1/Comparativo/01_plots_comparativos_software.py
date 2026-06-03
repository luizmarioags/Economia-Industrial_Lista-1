"""
Gera gráficos comparativos entre os resultados obtidos em Stata, R e Python.

Como usar, a partir da raiz do pacote:

    python Comparativo/01_plots_comparativos_software.py

Importante:
    Rode antes os scripts principais de Stata, R e Python. Se apenas Python
    tiver sido executado, os gráficos mostrarão apenas Python. Este script
    agora procura as tabelas tanto em output/tables/ quanto em subpastas como
    output/tables/Stata/, output/tables/R/ e output/tables/Python/.

Arquivos principais esperados:
    - stata_question_09_comparative.csv
    - r_question_09_comparative.csv
    - python_question_09_comparative.csv

O que compara:
    - beta_p estimado nos modelos Z1-Z7;
    - intervalo de confiança convencional de beta_p;
    - erro-padrão de beta_p;
    - F usual do primeiro estágio;
    - F efetivo de Montiel Olea-Pflueger, quando disponível;
    - p-valor do teste J de Hansen, quando disponível;
    - diferenças de beta_p em relação ao Stata, quando Stata estiver disponível.
"""

from __future__ import annotations

from pathlib import Path
from typing import Dict, Iterable, List, Optional, Tuple

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime


def log_step(message: str) -> None:
    """Imprime uma marcação legível no console."""
    print(f"\n[Comparativo | {datetime.now():%H:%M:%S}] {message}", flush=True)


# ---------------------------------------------------------------------
# Caminhos principais do pacote.
# ---------------------------------------------------------------------
ROOT = Path(__file__).resolve().parents[1]
TABS = ROOT / "output" / "tables"
FIGS = ROOT / "output" / "figures" / "comparative_software"
LOGS = ROOT / "output" / "logs"
DOCS = ROOT / "docs"

FIGS.mkdir(parents=True, exist_ok=True)
LOGS.mkdir(parents=True, exist_ok=True)
DOCS.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------------
# Ordenação dos modelos e dos softwares.
# ---------------------------------------------------------------------
MODEL_ORDER = [f"Z{i}" for i in range(1, 8)]
SOFTWARE_ORDER = ["Stata", "R", "Python"]

# ---------------------------------------------------------------------
# Nomes de arquivos que podem conter a tabela da questão 9.
# Inclui nomes do pacote novo e nomes usados em versões anteriores.
# ---------------------------------------------------------------------
SOFTWARE_PATTERNS: Dict[str, List[str]] = {
    "Stata": [
        "stata_question_09_comparative.csv",
        "stata_iv_results_weakivtest.csv",
        "stata_iv_results.csv",
    ],
    "R": [
        "r_question_09_comparative.csv",
        "r_iv_results.csv",
    ],
    "Python": [
        "python_question_09_comparative.csv",
        "python_iv_results.csv",
    ],
}

# ---------------------------------------------------------------------
# Padronização de nomes de colunas. As saídas dos softwares podem variar.
# ---------------------------------------------------------------------
COLUMN_ALIASES = {
    # Identificação do modelo.
    "model": "model",
    "modelo": "model",
    "instrumentos": "model",
    "instruments": "model",
    "spec": "model",

    # Amostra e quantidade de instrumentos.
    "n": "N",
    "obs": "N",
    "observations": "N",
    "N": "N",
    "k": "k_inst",
    "k_inst": "k_inst",
    "n_inst": "k_inst",
    "num_inst": "k_inst",

    # Coeficiente de interesse.
    "beta_p": "beta_p",
    "b": "beta_p",
    "coef": "beta_p",
    "coefficient": "beta_p",
    "estimate": "beta_p",
    "ln_pch": "beta_p",
    "lnpc": "beta_p",

    # Erro-padrão.
    "se_p": "se_p",
    "se": "se_p",
    "std_err": "se_p",
    "stderr": "se_p",
    "std.error": "se_p",
    "robust_se": "se_p",

    # Intervalo de confiança.
    "ci_low": "ci_low",
    "ci_lower": "ci_low",
    "lower": "ci_low",
    "lb": "ci_low",
    "low_95": "ci_low",
    "ci_l": "ci_low",
    "ci_high": "ci_high",
    "ci_upper": "ci_high",
    "upper": "ci_high",
    "ub": "ci_high",
    "high_95": "ci_high",
    "ci_u": "ci_high",

    # Primeiro estágio e instrumentos fracos.
    "F_usual": "F_usual",
    "f_usual": "F_usual",
    "F_first": "F_usual",
    "first_stage_F": "F_usual",
    "first_stage_f": "F_usual",
    "F_eff": "F_eff_MOP",
    "f_eff": "F_eff_MOP",
    "F_eff_MOP": "F_eff_MOP",
    "f_eff_mop": "F_eff_MOP",
    "mop_f": "F_eff_MOP",

    # Hansen J.
    "hansen_J": "hansen_J",
    "hansen_j": "hansen_J",
    "J": "hansen_J",
    "j": "hansen_J",
    "hansen_p": "hansen_p",
    "Hansen_p": "hansen_p",
    "jp": "hansen_p",
    "J_p": "hansen_p",
    "p_J": "hansen_p",
    "p_hansen": "hansen_p",
}

REQUIRED_COLUMNS = [
    "model", "N", "k_inst", "beta_p", "se_p", "ci_low", "ci_high",
    "F_usual", "F_eff_MOP", "hansen_J", "hansen_p",
]
NUMERIC_COLUMNS = [
    "N", "k_inst", "beta_p", "se_p", "ci_low", "ci_high",
    "F_usual", "F_eff_MOP", "hansen_J", "hansen_p",
]


def _clean_old_figures() -> None:
    """Remove gráficos comparativos antigos para evitar arquivos defasados."""
    for file in FIGS.glob("comparative_*.png"):
        file.unlink(missing_ok=True)


def _read_csv_flex(path: Path) -> pd.DataFrame:
    """Lê CSV aceitando separador vírgula ou ponto e vírgula."""
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
    """Converte números com ponto ou vírgula decimal para numérico."""
    if series.dtype == object:
        cleaned = (
            series.astype(str)
            .str.strip()
            .str.replace("%", "", regex=False)
            .str.replace(" ", "", regex=False)
            .str.replace(",", ".", regex=False)
            .replace({"": np.nan, ".": np.nan, "nan": np.nan, "None": np.nan})
        )
        return pd.to_numeric(cleaned, errors="coerce")
    return pd.to_numeric(series, errors="coerce")


def _infer_software_from_path(path: Path) -> Optional[str]:
    """Infere o software pelo nome do arquivo ou das pastas."""
    text = "/".join(part.lower() for part in path.parts)
    if "stata" in text:
        return "Stata"
    if "/r/" in text or "r_question" in path.name.lower() or path.name.lower().startswith("r_"):
        return "R"
    if "python" in text:
        return "Python"
    return None


def _candidate_paths(software: str) -> List[Path]:
    """Retorna caminhos candidatos para uma tabela de um software."""
    names = SOFTWARE_PATTERNS[software]
    candidates: List[Path] = []

    # Caminhos diretos na raiz de output/tables.
    for name in names:
        candidates.append(TABS / name)

    # Caminhos em subpastas padronizadas.
    for subdir in [software, software.lower(), software.upper()]:
        for name in names:
            candidates.append(TABS / subdir / name)

    # Busca recursiva: cobre estruturas herdadas do repositório antigo.
    if TABS.exists():
        for name in names:
            candidates.extend(TABS.rglob(name))

    # Remove duplicatas preservando ordem.
    unique: List[Path] = []
    seen = set()
    for path in candidates:
        key = str(path.resolve()) if path.exists() else str(path)
        if key not in seen:
            seen.add(key)
            unique.append(path)
    return unique


def _choose_best_existing_path(software: str) -> Optional[Path]:
    """Escolhe o melhor arquivo disponível para um software."""
    existing = [p for p in _candidate_paths(software) if p.exists()]
    if not existing:
        return None

    # Prioriza arquivos da lista nova, depois os mais recentes.
    def score(path: Path) -> Tuple[int, float]:
        name = path.name.lower()
        priority = 0
        if "question_09_comparative" in name:
            priority += 100
        if software.lower() in name:
            priority += 10
        return priority, path.stat().st_mtime

    return sorted(existing, key=score, reverse=True)[0]


def _standardize_columns(df: pd.DataFrame, software: str) -> pd.DataFrame:
    """Padroniza nomes e tipos de uma tabela importada."""
    rename = {}
    for col in df.columns:
        original = str(col).strip()
        key = original.strip()
        key_lower = key.lower()
        rename[col] = COLUMN_ALIASES.get(key, COLUMN_ALIASES.get(key_lower, key))
    df = df.rename(columns=rename)

    # Se uma saída antiga não tiver coluna de modelo, tenta criar Z1...Z7.
    if "model" not in df.columns:
        df = df.copy()
        df["model"] = [f"Z{i}" for i in range(1, len(df) + 1)]

    # Garante colunas mínimas.
    for col in REQUIRED_COLUMNS:
        if col not in df.columns:
            df[col] = np.nan

    # Converte números.
    for col in NUMERIC_COLUMNS:
        df[col] = _to_numeric(df[col])

    # Padroniza modelos: Z1, Z2, ..., Z7.
    df["model"] = (
        df["model"].astype(str)
        .str.strip()
        .str.upper()
        .str.replace(" ", "", regex=False)
    )
    df = df[df["model"].isin(MODEL_ORDER)].copy()

    # Se intervalo de confiança não veio, reconstrói pelo beta e erro-padrão.
    missing_ci = df["ci_low"].isna() | df["ci_high"].isna()
    can_build_ci = df["beta_p"].notna() & df["se_p"].notna()
    idx = missing_ci & can_build_ci
    df.loc[idx, "ci_low"] = df.loc[idx, "beta_p"] - 1.96 * df.loc[idx, "se_p"]
    df.loc[idx, "ci_high"] = df.loc[idx, "beta_p"] + 1.96 * df.loc[idx, "se_p"]

    df["software"] = software
    df["model"] = pd.Categorical(df["model"], categories=MODEL_ORDER, ordered=True)
    return df.sort_values("model")


def read_all_results() -> Tuple[pd.DataFrame, Dict[str, Optional[Path]]]:
    """Lê tabelas de Stata, R e Python e junta em uma base única."""
    frames: List[pd.DataFrame] = []
    used_paths: Dict[str, Optional[Path]] = {}

    for software in SOFTWARE_ORDER:
        path = _choose_best_existing_path(software)
        used_paths[software] = path
        if path is None:
            continue

        raw = _read_csv_flex(path)
        std = _standardize_columns(raw, software)
        if not std.empty:
            frames.append(std)

    if not frames:
        raise FileNotFoundError(
            "Nenhuma tabela comparativa foi encontrada. Rode antes ao menos uma "
            "rotina principal: Stata/00_master.do, R/00_run_all.R ou "
            "Python/src/run_all.py."
        )

    combined = pd.concat(frames, ignore_index=True)
    combined["software"] = pd.Categorical(
        combined["software"], categories=SOFTWARE_ORDER, ordered=True
    )
    combined = combined.sort_values(["model", "software"])
    combined.to_csv(TABS / "comparative_software_results.csv", index=False)

    return combined, used_paths


def _x_positions(df: pd.DataFrame) -> np.ndarray:
    """Converte Z1-Z7 em posições numéricas ordenadas."""
    map_pos = {m: i for i, m in enumerate(MODEL_ORDER)}
    return df["model"].astype(str).map(map_pos).to_numpy(dtype=float)


def _has_data(df: pd.DataFrame, column: str) -> bool:
    """Verifica se existe dado não nulo para uma coluna."""
    return column in df.columns and df[column].notna().any()


def plot_availability(df: pd.DataFrame) -> None:
    """Mostra quais softwares têm resultados para cada modelo."""
    availability = (
        df.assign(available=df["beta_p"].notna().astype(int))
        .pivot_table(index="software", columns="model", values="available", aggfunc="max", fill_value=0, observed=False)
        .reindex(index=SOFTWARE_ORDER, columns=MODEL_ORDER, fill_value=0)
    )

    fig, ax = plt.subplots(figsize=(9, 3.8))
    ax.imshow(availability.to_numpy(), aspect="auto")
    ax.set_xticks(range(len(MODEL_ORDER)))
    ax.set_xticklabels(MODEL_ORDER)
    ax.set_yticks(range(len(SOFTWARE_ORDER)))
    ax.set_yticklabels(SOFTWARE_ORDER)
    ax.set_xlabel("Conjunto de instrumentos")
    ax.set_title("Disponibilidade dos resultados por software")

    for i, software in enumerate(SOFTWARE_ORDER):
        for j, model in enumerate(MODEL_ORDER):
            txt = "ok" if availability.iloc[i, j] == 1 else "--"
            ax.text(j, i, txt, ha="center", va="center")

    fig.tight_layout()
    fig.savefig(FIGS / "comparative_availability_by_software.png", dpi=300)
    plt.close(fig)


def plot_beta_with_ci(df: pd.DataFrame) -> None:
    """Compara beta_p e intervalos de confiança por software."""
    if not _has_data(df, "beta_p"):
        return

    fig, ax = plt.subplots(figsize=(10, 6))
    offsets = {"Stata": -0.22, "R": 0.0, "Python": 0.22}

    for software in SOFTWARE_ORDER:
        sub = df[(df["software"] == software) & df["beta_p"].notna()].copy()
        if sub.empty:
            continue

        x = _x_positions(sub) + offsets[software]
        y = sub["beta_p"].to_numpy(dtype=float)

        if sub["ci_low"].notna().any() and sub["ci_high"].notna().any():
            yerr = np.vstack([
                y - sub["ci_low"].to_numpy(dtype=float),
                sub["ci_high"].to_numpy(dtype=float) - y,
            ])
            ax.errorbar(x, y, yerr=yerr, fmt="o", capsize=4, label=software)
        else:
            ax.plot(x, y, marker="o", linestyle="", label=software)

    ax.axhline(0, linewidth=1)
    ax.set_xticks(range(len(MODEL_ORDER)))
    ax.set_xticklabels(MODEL_ORDER)
    ax.set_xlabel("Conjunto de instrumentos")
    ax.set_ylabel(r"Estimativa de $\beta_p$")
    ax.set_title(r"Comparação de $\beta_p$ entre Stata, R e Python")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "comparative_beta_p_ci.png", dpi=300)
    plt.close(fig)


def plot_standard_errors(df: pd.DataFrame) -> None:
    """Compara erros-padrão robustos de beta_p."""
    if not _has_data(df, "se_p"):
        return

    fig, ax = plt.subplots(figsize=(10, 6))
    for software in SOFTWARE_ORDER:
        sub = df[(df["software"] == software) & df["se_p"].notna()].copy()
        if sub.empty:
            continue
        ax.plot(sub["model"].astype(str), sub["se_p"], marker="o", label=software)

    ax.set_xlabel("Conjunto de instrumentos")
    ax.set_ylabel(r"Erro-padrão robusto de $\beta_p$")
    ax.set_title(r"Precisão convencional das estimativas de $\beta_p$")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "comparative_beta_p_standard_errors.png", dpi=300)
    plt.close(fig)


def plot_f_usual(df: pd.DataFrame) -> None:
    """Compara o F usual do primeiro estágio."""
    if not _has_data(df, "F_usual"):
        return

    fig, ax = plt.subplots(figsize=(10, 6))
    for software in SOFTWARE_ORDER:
        sub = df[(df["software"] == software) & df["F_usual"].notna()].copy()
        if sub.empty:
            continue
        ax.plot(sub["model"].astype(str), sub["F_usual"], marker="o", label=software)

    ax.axhline(10, linestyle="--", linewidth=1, label="Referência F=10")
    ax.set_xlabel("Conjunto de instrumentos")
    ax.set_ylabel("F usual do primeiro estágio")
    ax.set_title("Comparação do F usual do primeiro estágio")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "comparative_first_stage_F_usual.png", dpi=300)
    plt.close(fig)


def plot_f_eff_mop(df: pd.DataFrame) -> None:
    """Plota o F efetivo MOP quando disponível."""
    if not _has_data(df, "F_eff_MOP"):
        return

    fig, ax = plt.subplots(figsize=(10, 6))
    for software in SOFTWARE_ORDER:
        sub = df[(df["software"] == software) & df["F_eff_MOP"].notna()].copy()
        if sub.empty:
            continue
        ax.plot(sub["model"].astype(str), sub["F_eff_MOP"], marker="o", label=software)

    ax.set_xlabel("Conjunto de instrumentos")
    ax.set_ylabel("F efetivo MOP")
    ax.set_title("F efetivo de Montiel Olea-Pflueger")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "comparative_F_eff_MOP.png", dpi=300)
    plt.close(fig)


def plot_hansen_p(df: pd.DataFrame) -> None:
    """Compara p-valores do teste J de Hansen."""
    if not _has_data(df, "hansen_p"):
        return

    fig, ax = plt.subplots(figsize=(10, 6))
    for software in SOFTWARE_ORDER:
        sub = df[(df["software"] == software) & df["hansen_p"].notna()].copy()
        if sub.empty:
            continue
        ax.plot(sub["model"].astype(str), sub["hansen_p"], marker="o", label=software)

    ax.axhline(0.05, linestyle="--", linewidth=1, label="p = 0,05")
    ax.set_xlabel("Conjunto de instrumentos")
    ax.set_ylabel("p-valor do teste J de Hansen")
    ax.set_title("Comparação do teste J de Hansen")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "comparative_hansen_p_values.png", dpi=300)
    plt.close(fig)


def plot_differences_vs_stata(df: pd.DataFrame) -> None:
    """Compara beta_p de R/Python contra Stata, quando Stata existe."""
    stata = df[(df["software"] == "Stata") & df["beta_p"].notna()][["model", "beta_p"]].rename(
        columns={"beta_p": "beta_p_stata"}
    )
    if stata.empty:
        return

    other = df[df["software"].isin(["R", "Python"]) & df["beta_p"].notna()].copy()
    if other.empty:
        return

    diff = other.merge(stata, on="model", how="inner")
    if diff.empty:
        return

    diff["diff_vs_stata"] = diff["beta_p"] - diff["beta_p_stata"]
    diff["abs_diff_vs_stata"] = diff["diff_vs_stata"].abs()
    diff.to_csv(TABS / "comparative_beta_p_differences_vs_stata.csv", index=False)

    fig, ax = plt.subplots(figsize=(10, 6))
    for software in ["R", "Python"]:
        sub = diff[diff["software"] == software]
        if sub.empty:
            continue
        ax.plot(sub["model"].astype(str), sub["diff_vs_stata"], marker="o", label=software)

    ax.axhline(0, linewidth=1)
    ax.set_xlabel("Conjunto de instrumentos")
    ax.set_ylabel(r"$\beta_p$ do software − $\beta_p$ do Stata")
    ax.set_title(r"Diferença de $\beta_p$ em relação ao Stata")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "comparative_beta_p_difference_vs_stata.png", dpi=300)
    plt.close(fig)


def write_log_and_report(df: pd.DataFrame, used_paths: Dict[str, Optional[Path]]) -> None:
    """Escreve log e relatório indicando quais arquivos foram usados."""
    found = [s for s, p in used_paths.items() if p is not None]
    missing = [s for s, p in used_paths.items() if p is None]

    lines = []
    lines.append("Relatório dos plots comparativos\n")
    lines.append("================================\n\n")
    lines.append("Arquivos usados:\n")
    for software in SOFTWARE_ORDER:
        path = used_paths.get(software)
        if path is None:
            lines.append(f"- {software}: não encontrado\n")
        else:
            lines.append(f"- {software}: {path.relative_to(ROOT)}\n")

    lines.append("\nSoftwares encontrados: " + (", ".join(found) if found else "nenhum") + "\n")
    if missing:
        lines.append("Softwares sem tabela comparativa: " + ", ".join(missing) + "\n")
        lines.append(
            "\nSe algum gráfico aparece apenas com Python, isso normalmente significa que "
            "as rotinas de Stata e/ou R ainda não foram executadas, ou que as tabelas "
            "não estão salvas em output/tables/.\n"
        )

    lines.append("\nGráficos gerados, conforme disponibilidade de dados:\n")
    generated = sorted(p.name for p in FIGS.glob("comparative_*.png"))
    for name in generated:
        lines.append(f"- {name}\n")

    lines.append("\nTabela consolidada:\n")
    lines.append("- output/tables/comparative_software_results.csv\n")

    text = "".join(lines)
    (LOGS / "comparative_software_plots.log").write_text(text, encoding="utf-8")
    (DOCS / "relatorio_plots_comparativos.md").write_text(text, encoding="utf-8")


def main() -> None:
    log_step("Plots comparativos: iniciando")
    log_step("Objetivo: comparar beta_p, EP, IC 95%, F usual, F efetivo MOP e Hansen J entre Stata, R e Python")
    """Executa toda a rotina de comparação."""
    log_step("Limpando gráficos comparativos antigos")
    _clean_old_figures()
    df, used_paths = read_all_results()

    plot_availability(df)
    plot_beta_with_ci(df)
    plot_standard_errors(df)
    plot_f_usual(df)
    plot_f_eff_mop(df)
    plot_hansen_p(df)
    plot_differences_vs_stata(df)
    write_log_and_report(df, used_paths)

    print("Plots comparativos gerados em:", FIGS)
    print("Tabela consolidada:", TABS / "comparative_software_results.csv")
    print("Relatório:", DOCS / "relatorio_plots_comparativos.md")


if __name__ == "__main__":
    main()
