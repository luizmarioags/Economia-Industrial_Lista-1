# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Define caminhos, constantes e diretórios usados em toda a replicação Python.
# Path(__file__).resolve() torna o código robusto ao diretório de execução.
# mkdir(..., exist_ok=True) cria logs, figuras, tabelas e dados tratados antes das exportações.

"""
Configuração do pacote de replicação - Lista Berry/BLP.
Execute a partir da raiz do pacote:
    python python/run_all_python.py
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_FILE = ROOT / "data" / "exemplo.csv"
OUT_ROOT = ROOT / "outputs"
OUT = OUT_ROOT / "python"
LOG_DIR = OUT / "logs"
FIG_PDF = OUT / "figures" / "pdf"
FIG_PNG = OUT / "figures" / "png"
TAB_CSV = OUT / "tables" / "csv"
TAB_TEX = OUT / "tables" / "tex"
OUT_DATA = OUT / "data"

S0 = 0.2429
CHAR_VARS = ["cals", "fat", "sugar"]
PRICE_VAR = "price"
SHARE_VAR = "share"
SEGMENT_VAR = "segment"
FIRM_VAR = "firm"
PRODUCT_VAR = "product"

for d in [LOG_DIR, FIG_PDF, FIG_PNG, TAB_CSV, TAB_TEX, OUT_DATA]:
    d.mkdir(parents=True, exist_ok=True)
