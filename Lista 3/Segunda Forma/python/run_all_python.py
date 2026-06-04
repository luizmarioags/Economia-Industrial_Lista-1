"""Run all - Lista Berry/BLP em Python.
Execute a partir da pasta python/ ou da raiz do pacote:
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


def main() -> None:
    config.clean_outputs()
    log_path = config.LOG_DIR / "run_all_python.log"
    with open(log_path, "w", encoding="utf-8") as log:
        class Tee:
            def __init__(self, *files): self.files = files
            def write(self, data):
                for f in self.files: f.write(data); f.flush()
            def flush(self):
                for f in self.files: f.flush()
        old_stdout = sys.stdout
        old_stderr = sys.stderr
        sys.stdout = Tee(old_stdout, log)
        sys.stderr = Tee(old_stderr, log)
        try:
            print("#########################################################################")
            print("#                            INÍCIO                                     #")
            print("#             Lista Berry/BLP - Replicação em Python                    #")
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
