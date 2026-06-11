"""01 - Tratamento da base e construção dos instrumentos BLP."""
from __future__ import annotations
import numpy as np
import pandas as pd
import config


def main() -> pd.DataFrame:
    if not config.DATA.exists():
        raise FileNotFoundError(f"Arquivo não encontrado: {config.DATA}. Coloque o CSV em data/exemplo.csv")

    raw = pd.read_csv(config.DATA, dtype=str)
    if raw.shape[1] < 11:
        raise ValueError("O CSV precisa ter pelo menos 11 colunas na ordem esperada. Veja data/README_data.md")

    cols = [
        "idProduct", "firm", "product", "price", "shelf_price", "ad_price",
        "share_pct", "segment", "cals", "fat", "sugar",
    ]
    raw = raw.rename(columns={raw.columns[i]: cols[i] for i in range(11)})

    for v in ["idProduct", "price", "shelf_price", "ad_price", "share_pct", "cals", "fat", "sugar"]:
        raw[v] = pd.to_numeric(raw[v].astype(str).str.replace(",", ".", regex=False), errors="coerce")

    df = raw.loc[(raw["firm"].str.lower() != "basketof") & raw["segment"].notna()].copy()
    df = df.dropna(subset=["price", "share_pct", "cals", "fat", "sugar"])

    df["share"] = df["share_pct"] / 100.0
    df["outside_share"] = config.S0
    df["delta"] = np.log(df["share"]) - np.log(config.S0)
    df["cons"] = 1.0
    df["neg_price"] = -df["price"]
    df["idfirm"] = pd.Categorical(df["firm"]).codes + 1
    df["idsegment"] = pd.Categorical(df["segment"]).codes + 1

    for x in config.XVARS:
        df[f"total_firm_{x}"] = df.groupby("firm")[x].transform("sum")
        df[f"total_all_{x}"] = df[x].sum()
        df[f"n_firm_{x}"] = df.groupby("firm")[x].transform("size")
        df[f"own_{x}"] = df[f"total_firm_{x}"] - df[x]
        df.loc[df[f"n_firm_{x}"] <= 1, f"own_{x}"] = 0
        df[f"rival_{x}"] = df[f"total_all_{x}"] - df[f"total_firm_{x}"]

    df["n_products_firm"] = df.groupby("firm")["firm"].transform("size")
    df["n_total_products"] = len(df)
    df["n_rival_products"] = df["n_total_products"] - df["n_products_firm"]
    df["nest_share"] = df.groupby("segment")["share"].transform("sum")
    df["share_within_nest"] = df["share"] / df["nest_share"]
    df["log_share_within_nest"] = np.log(df["share_within_nest"])
    df["n_products_nest"] = df.groupby("segment")["segment"].transform("size")
    df["n_same_nest_other"] = df["n_products_nest"] - 1
    df["n_rival_nest"] = df["n_total_products"] - df["n_products_nest"]

    for x in config.XVARS:
        df[f"total_nest_{x}"] = df.groupby("segment")[x].transform("sum")
        df[f"nest_own_{x}"] = df[f"total_nest_{x}"] - df[x]
        df[f"nest_rival_{x}"] = df[f"total_all_{x}"] - df[f"total_nest_{x}"]

    first = ["idProduct", "firm", "product", "segment", "price", "neg_price", "share", "delta", "cals", "fat", "sugar"]
    df = df[first + [c for c in df.columns if c not in first]]

    df.to_pickle(config.OUTDATA / "prepared_data_python.pkl")
    df.to_csv(config.OUTDATA / "prepared_data_python.csv", index=False)
    print(f"Base preparada: {len(df)} produtos.")
    return df


if __name__ == "__main__":
    main()
