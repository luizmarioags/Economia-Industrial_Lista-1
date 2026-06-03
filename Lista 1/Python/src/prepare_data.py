"""Prepara a base chicken para a Lista 1."""
import numpy as np
import pandas as pd
from config import RAW, PROC, log_step, log_vars

def prepare_data() -> pd.DataFrame:
    log_step("Preparação dos dados: iniciando")
    dta_path = RAW / "chicken.dta"
    csv_path = RAW / "chicken.csv"

    if dta_path.exists():
        df = pd.read_stata(dta_path)
    else:
        df = pd.read_csv(csv_path, sep=";")

    df.columns = [c.lower() for c in df.columns]

    if "tim" in df.columns and "time" not in df.columns:
        df["time"] = df["tim"]
    if "eatex" in df.columns and "meatex" not in df.columns:
        df["meatex"] = df["eatex"]

    for col in df.columns:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    if "year" in df: df.loc[df["year"] > 9999, "year"] /= 1000
    if "q" in df: df.loc[df["q"] > 1000, "q"] /= 100000
    if "y" in df: df.loc[df["y"] > 100000, "y"] /= 1000
    if "pchick" in df: df.loc[df["pchick"] > 10000, "pchick"] /= 100000
    if "pbeef" in df: df.loc[df["pbeef"] > 10000, "pbeef"] /= 100000
    if "pcor" in df: df.loc[df["pcor"] > 10000, "pcor"] /= 100000
    if "pf" in df: df.loc[df["pf"] > 10000, "pf"] /= 100000
    if "cpi" in df: df.loc[df["cpi"] > 10000, "cpi"] /= 100000
    if "pop" in df: df.loc[df["pop"] > 10000, "pop"] /= 10000
    if "time" in df: df.loc[df["time"] > 10000, "time"] /= 100000

    df = df.sort_values("year").reset_index(drop=True)

    df["ln_q"] = np.log(df["q"])
    df["ln_y"] = np.log(df["y"])
    df["ln_pch"] = np.log(df["pchick"] / df["cpi"])
    df["ln_pb"] = np.log(df["pbeef"] / df["cpi"])
    df["z"] = np.log(df["pcor"] / df["cpi"])

    df["z_sq"] = df["z"] ** 2
    df["z_cu"] = df["z"] ** 3
    df["z_lag"] = df["z"].shift(1)
    df["z_lag_sq"] = df["z_lag"] ** 2

    out = PROC / "chicken_prepared_python.csv"
    df.to_csv(out, index=False)
    return df

if __name__ == "__main__":
    prepare_data()
