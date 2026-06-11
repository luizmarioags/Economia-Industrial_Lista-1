# /*******************************************************************************
# Arquivo: python/run_all_python.py
# Objetivo: rodar, em ordem, toda a resolução Python da Lista 3 - Nested Logit/Berry.
# Elaborado por:
# Luiz Mario Andrade (Matrícula: 252029360)
# Felipe Santos (Matrícula: 232010719)
# Luiza Nodari (Matrícula: 242011335)
# Diogo Martins (Matrícula: 232001578)
# Sarah Moura (Matrícula: 211060316)
# Pedro Bijos (Matrícula: 241003849)
# *******************************************************************************/
"""Run all - Lista 3 Nested Logit/Berry em Python.

Execute a partir da raiz do pacote:
    python python/run_all_python.py
"""
from __future__ import annotations
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import config
from prepare_data import main as prepare_data
from estimate_logit_iv_gmm import main as estimate_simple
from nested_gmm import main as estimate_nested
from elasticities_markups import main as elasticities_markups
from diagnostics_weakiv import main as diagnostics
from standard_tables import main as standard_tables
from visualizations import main as visualizations
from extra_visualizations import main as extra_visualizations


class Tee:
    def __init__(self, *files):
        self.files = files

    def write(self, data):
        for f in self.files:
            f.write(data)
            f.flush()

    def flush(self):
        for f in self.files:
            f.flush()


def main() -> None:
    config.clean_outputs()
    log_path = config.LOG_DIR / "run_all_python.log"
    with open(log_path, "w", encoding="utf-8") as log:
        old_stdout = sys.stdout
        old_stderr = sys.stderr
        sys.stdout = Tee(old_stdout, log)
        sys.stderr = Tee(old_stderr, log)
        try:
            print("#########################################################################")
            print("#                            INÍCIO                                     #")
            print("#             Lista 3 - Nested Logit/Berry - Python                     #")
            print("#########################################################################")
            prepare_data()
            estimate_simple()
            estimate_nested()
            elasticities_markups()
            diagnostics()
            standard_tables()
            visualizations()
            extra_visualizations()
            print("#########################################################################")
            print("#                            FIM                                        #")
            print("#########################################################################")
        finally:
            sys.stdout = old_stdout
            sys.stderr = old_stderr


if __name__ == "__main__":
    main()
