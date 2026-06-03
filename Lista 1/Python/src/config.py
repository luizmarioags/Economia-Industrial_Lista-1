"""Configuração de caminhos e funções de marcação do pacote Python."""
from pathlib import Path
from datetime import datetime

# A raiz é dois níveis acima deste arquivo: Python/src/config.py -> raiz.
ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "data" / "raw"
PROC = ROOT / "data" / "processed"
TABS = ROOT / "output" / "tables"
FIGS = ROOT / "output" / "figures"
LOGS = ROOT / "output" / "logs"

def log_step(message: str) -> None:
    print(f"\n[Python | {datetime.now():%H:%M:%S}] {message}", flush=True)

def log_vars(label: str, variables) -> None:
    if isinstance(variables, str):
        variables = [variables]
    print(f"[Python | {datetime.now():%H:%M:%S}] {label}: {', '.join(map(str, variables))}", flush=True)

for path in [PROC, TABS, FIGS, LOGS]:
    path.mkdir(parents=True, exist_ok=True)
