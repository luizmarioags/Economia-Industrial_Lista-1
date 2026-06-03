# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Lê o CSV, renomeia colunas, remove o bem externo da amostra interna e constrói delta.
# As funções construct_blp_instruments e construct_nested_variables criam os instrumentos e variáveis exigidos na lista.
# A base preparada é salva em outputs/python/data para auditoria e reuso.

import numpy as np
import pandas as pd
from config import DATA_FILE, S0, CHAR_VARS, OUT_DATA


def load_and_prepare(data_file=DATA_FILE):
    df = pd.read_csv(data_file)
    df = df.rename(columns={
        "Unnamed: 0": "id",
        "Unnamed: 1": "firm",
        "Unnamed: 2": "product",
        "average transaction price": "price",
        "ave shelf price": "shelf_price",
        "ave ad price": "ad_price",
        "in sample market share": "share_pct",
        "sgmnt": "segment",
        "suger": "sugar",
    })

    # Mantém apenas os produtos internos. A última linha da base é o bem externo.
    df = df.loc[df["firm"].astype(str).str.lower().ne("basketof")].copy()
    df = df.dropna(subset=["price", "share_pct", "segment"] + CHAR_VARS)

    for col in ["price", "shelf_price", "ad_price", "share_pct"] + CHAR_VARS:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df = df.dropna(subset=["price", "share_pct"] + CHAR_VARS).copy()

    df["share"] = df["share_pct"] / 100.0
    df["outside_share"] = S0
    df["delta"] = np.log(df["share"]) - np.log(S0)

    # Identificadores estáveis.
    df["firm_id"] = pd.Categorical(df["firm"]).codes + 1
    df["segment_id"] = pd.Categorical(df["segment"]).codes + 1

    df = construct_blp_instruments(df)
    df = construct_nested_variables(df)

    OUT_DATA.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT_DATA / "prepared_data_python.csv", index=False)
    return df


def construct_blp_instruments(df):
    df = df.copy()
    n = len(df)
    for x in CHAR_VARS:
        firm_sum = df.groupby("firm")[x].transform("sum")
        total_sum = df[x].sum()
        df[f"own_{x}"] = firm_sum - df[x]
        df[f"rival_{x}"] = total_sum - firm_sum

        # Tratamento explícito de firmas monoproduto: a soma dos demais produtos da firma é zero.
        firm_count = df.groupby("firm")[x].transform("count")
        df.loc[firm_count <= 1, f"own_{x}"] = 0.0

    df["n_products_firm"] = df.groupby("firm")["product"].transform("count")
    df["n_rival_products"] = n - df["n_products_firm"]
    return df


def construct_nested_variables(df):
    df = df.copy()
    df["nest_share"] = df.groupby("segment")["share"].transform("sum")
    df["share_within_nest"] = df["share"] / df["nest_share"]
    df["log_share_within_nest"] = np.log(df["share_within_nest"])
    n = len(df)
    df["n_products_nest"] = df.groupby("segment")["product"].transform("count")
    df["n_same_nest_other"] = df["n_products_nest"] - 1
    df["n_rival_nest"] = n - df["n_products_nest"]

    for x in CHAR_VARS:
        nest_sum = df.groupby("segment")[x].transform("sum")
        total_sum = df[x].sum()
        df[f"nest_own_{x}"] = nest_sum - df[x]
        df[f"nest_rival_{x}"] = total_sum - nest_sum
    return df


if __name__ == "__main__":
    d = load_and_prepare()
    print(d.head())
    print(d.shape)
