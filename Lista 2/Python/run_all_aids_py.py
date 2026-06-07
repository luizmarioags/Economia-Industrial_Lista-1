# Elaborado por:
# Luiz Mario Andrade (Matrícula: 252029360)
# Felipe Santos (Matrícula: 232010719)
# Luiza Nodari (Matrícula: 242011335)
# Diogo Martins (Matrícula: 232001578)
# Sarah Moura (Matrícula: 211060316)
# Pedro Bijos (Matrícula: 241003849)

from pathlib import Path

from py_aids_replication.run_all_aids import run_all


if __name__ == "__main__":
    # Este arquivo fica em Python/. A raiz do pacote é a pasta imediatamente acima.
    project_root = Path(__file__).resolve().parents[1]
    run_all(root=project_root, output_tag="PY", run_stata_comparison=True)
