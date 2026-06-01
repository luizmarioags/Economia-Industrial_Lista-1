"""Preparação da base para o sistema AIDS."""

from __future__ import annotations

import numpy as np
import pandas as pd

from .config import AIDSConfig, default_config
from .utils import ensure_columns, write_csv


def prepare_aids_data(cfg: AIDSConfig | None = None) -> pd.DataFrame:
    cfg = cfg or default_config()
    cfg.ensure_dirs()

    if not cfg.raw_csv.exists():
        raise FileNotFoundError(
            f"Arquivo bruto não encontrado: {cfg.raw_csv}. "
            "Coloque meatdata.csv em data/raw/."
        )

    dados = pd.read_csv(cfg.raw_csv).sort_values("year").reset_index(drop=True)

    # Cria dispêndio x_g = p_g q_g quando a coluna de dispêndio não existe.
    for g in cfg.goods:
        x_name = f"x{g}"
        p_name = f"{g}p"
        q_name = f"{g}q"
        if x_name not in dados.columns:
            ensure_columns(dados, [p_name, q_name], context="base bruta")
            dados[x_name] = dados[p_name] * dados[q_name]

    x_cols = [f"x{g}" for g in cfg.goods]
    ensure_columns(dados, ["year", *x_cols], context="base bruta/preparada")

    dados["xtotal_calc"] = dados[x_cols].sum(axis=1)
    for g in cfg.goods:
        dados[f"w_{g}"] = dados[f"x{g}"] / dados["xtotal_calc"]

    w_cols = [f"w_{g}" for g in cfg.goods]
    dados["share_sum"] = dados[w_cols].sum(axis=1)
    dados["share_gap"] = dados["share_sum"] - 1.0
    dados["share_problem"] = dados["share_gap"].abs() > 1e-8

    if "xtotal" in dados.columns:
        dados["diff_xtotal"] = dados["xtotal_calc"] - dados["xtotal"]

    # Logs de preços e logs normalizados pela média temporal.
    for g in cfg.goods:
        p_name = f"{g}p"
        ensure_columns(dados, [p_name], context="base bruta/preparada")
        ln_name = f"ln_p_{g}"
        lngp_name = f"lngp_{g}"
        dados[ln_name] = np.log(dados[p_name])
        dados[lngp_name] = dados[ln_name] - dados[ln_name].mean(skipna=True)

    # Participações médias usadas no índice de Stone.
    wbar = {g: dados[f"w_{g}"].mean(skipna=True) for g in cfg.goods}
    for g in cfg.goods:
        dados[f"wbar_{g}"] = wbar[g]

    dados["lnP_stone"] = sum(wbar[g] * dados[f"ln_p_{g}"] for g in cfg.goods)
    dados["ln_xtotal"] = np.log(dados["xtotal_calc"])
    dados["ln_real_x"] = dados["ln_xtotal"] - dados["lnP_stone"]

    if "pce" in dados.columns:
        dados["meat_pce_share"] = dados["xtotal_calc"] / dados["pce"]

    # Diferenças contra o produto omitido e defasagens dos log-preços normalizados.
    for g in cfg.goods:
        dados[f"d_{g}_{cfg.omit_good}"] = dados[f"lngp_{g}"] - dados[f"lngp_{cfg.omit_good}"]
        dados[f"L1_lngp_{g}"] = dados[f"lngp_{g}"].shift(1)
        dados[f"L2_lngp_{g}"] = dados[f"lngp_{g}"].shift(2)

    for g in cfg.est_goods:
        dados[f"y_{g}"] = dados[f"w_{g}"]

    participacoes_medias = pd.DataFrame(
        {"produto": list(cfg.goods), "wbar": [wbar[g] for g in cfg.goods]}
    )

    diagnostico_soma = pd.DataFrame(
        {
            "min_share_sum": [dados["share_sum"].min(skipna=True)],
            "max_share_sum": [dados["share_sum"].max(skipna=True)],
            "max_abs_gap": [dados["share_gap"].abs().max(skipna=True)],
            "n_problem": [int(dados["share_problem"].sum(skipna=True))],
        }
    )

    write_csv(dados, cfg.proc_csv)
    dados.to_pickle(cfg.proc_pickle)
    write_csv(participacoes_medias, cfg.tagged_table("participacoes_medias"))
    write_csv(diagnostico_soma, cfg.tagged_table("diagnostico_soma_participacoes"))

    return dados


if __name__ == "__main__":
    prepare_aids_data()
    print("Base AIDS preparada e salva com sucesso.")
