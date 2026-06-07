"""Executor geral do pacote Python de replicação AIDS."""

# Elaborado por:
# Luiz Mario Andrade (Matrícula: 252029360)
# Felipe Santos (Matrícula: 232010719)
# Luiza Nodari (Matrícula: 242011335)
# Diogo Martins (Matrícula: 232001578)
# Sarah Moura (Matrícula: 211060316)
# Pedro Bijos (Matrícula: 241003849)
from __future__ import annotations

from pathlib import Path

from .config import AIDSConfig, default_config
from .compare_results_stata import compare_results
from .diagnostics_aids import run_diagnostics
from .elasticities_aids import calculate_elasticities
from .estimate_aids import estimate_all
from .prepare_aids_data import prepare_aids_data
from .summary_compare import summarize_comparison
from .visualizations_aids import generate_visualizations


def run_all(
    root: str | Path | None = None,
    output_tag: str = "PY",
    run_stata_comparison: bool = True,
) -> None:
    cfg = default_config(root=root, output_tag=output_tag)
    cfg.ensure_dirs()

    prepare_aids_data(cfg)
    estimate_all(cfg)
    calculate_elasticities(cfg, wbar_sample="full")
    generate_visualizations(cfg)
    run_diagnostics(cfg)

    if run_stata_comparison:
        compare_results(cfg)
        summarize_comparison(cfg)

    print("Pacote AIDS em Python concluído com sucesso.")


if __name__ == "__main__":
    run_all()
