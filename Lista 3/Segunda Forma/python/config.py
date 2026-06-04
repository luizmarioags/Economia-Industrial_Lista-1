"""Configuração comum da replicação Berry/BLP em Python."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S0 = 0.2429
XVARS = ["cals", "fat", "sugar"]
PRICE = "price"
DELTA = "delta"
ZOWN = ["own_cals", "own_fat", "own_sugar"]
ZRIVAL = ["rival_cals", "rival_fat", "rival_sugar"]
ZBOTH = ZOWN + ZRIVAL
ZNEST = [
    "n_same_nest_other", "n_rival_nest",
    "nest_own_cals", "nest_own_fat", "nest_own_sugar",
    "nest_rival_cals", "nest_rival_fat", "nest_rival_sugar",
]
ZNESTALL = ZBOTH + ZNEST

DATA = ROOT / "data" / "exemplo.csv"
OUTROOT = ROOT / "outputs"
OUT = OUTROOT / "python"
LOG_DIR = OUT / "logs"
FIGROOT = OUT / "figures"
FIGPDF = FIGROOT / "pdf"
FIGPNG = FIGROOT / "png"
TABROOT = OUT / "tables"
TABCSV = TABROOT / "csv"
TABTEX = TABROOT / "tex"
OUTDATA = OUT / "data"

for d in [OUTROOT, OUT, LOG_DIR, FIGROOT, FIGPDF, FIGPNG, TABROOT, TABCSV, TABTEX, OUTDATA]:
    d.mkdir(parents=True, exist_ok=True)

def clean_outputs() -> None:
    for folder, suffixes in [(TABCSV, [".csv"]), (TABTEX, [".tex"]), (FIGPDF, [".pdf"]), (FIGPNG, [".png"]), (OUTDATA, [])]:
        if suffixes:
            for p in folder.iterdir():
                if p.suffix.lower() in suffixes:
                    p.unlink(missing_ok=True)
