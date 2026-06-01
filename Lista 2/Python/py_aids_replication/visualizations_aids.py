"""Visualizações e tabelas auxiliares do sistema AIDS em Python."""

from __future__ import annotations

import math
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

from .config import AIDSConfig, default_config
from .utils import (
    AIDS_COLORS,
    GOOD_COLORS,
    PRODUTO_LABELS,
    load_pickle,
    nome_modelo,
    nome_parametro,
    nome_produto,
    rotulo_variavel_produto,
    write_csv,
)


def _setup_axes(ax, title: str, xlabel: str | None = None, ylabel: str | None = None) -> None:
    ax.set_title(title, fontsize=12, fontweight="bold")
    if xlabel is not None:
        ax.set_xlabel(xlabel, fontsize=10)
    if ylabel is not None:
        ax.set_ylabel(ylabel, fontsize=10)
    ax.grid(True, which="major", alpha=0.35, linewidth=0.5)
    ax.tick_params(axis="both", labelsize=9)


def save_plot(fig, filename: str, cfg: AIDSConfig, width: float = 9, height: float = 6) -> None:
    cfg.ensure_dirs()
    fig.set_size_inches(width, height)
    fig.tight_layout()
    fig.savefig(cfg.figures_pdf / f"{filename}.pdf", bbox_inches="tight", facecolor="white")
    fig.savefig(cfg.figures_png / f"{filename}.png", dpi=300, bbox_inches="tight", facecolor="white")
    plt.close(fig)


def series_long(data: pd.DataFrame, vars_: list[str], value_name: str) -> pd.DataFrame:
    return data[["year", *vars_]].melt(id_vars="year", var_name="serie", value_name=value_name)


def _add_legend_right(ax) -> None:
    ax.legend(loc="center left", bbox_to_anchor=(1.02, 0.5), frameon=False)


def _line_by_group(df: pd.DataFrame, y: str, group: str, title: str, ylabel: str, filename: str, cfg: AIDSConfig) -> None:
    fig, ax = plt.subplots()
    for key, sub in df.groupby(group, sort=False):
        color = AIDS_COLORS.get(str(key), GOOD_COLORS.get(str(key), None))
        ax.plot(sub["year"], sub[y], marker="o", linewidth=1.5, markersize=3, label=str(key), color=color)
    _setup_axes(ax, title, "Ano", ylabel)
    _add_legend_right(ax)
    save_plot(fig, filename, cfg)


def _fit_line(ax, x: np.ndarray, y: np.ndarray, color: str = "#B03060") -> None:
    mask = np.isfinite(x) & np.isfinite(y)
    if mask.sum() >= 2:
        b1, b0 = np.polyfit(x[mask], y[mask], deg=1)
        xs = np.linspace(np.nanmin(x[mask]), np.nanmax(x[mask]), 100)
        ax.plot(xs, b1 * xs + b0, color=color, linewidth=1.5)


def _facet_scatter(
    df: pd.DataFrame,
    x: str,
    y: str,
    facet: str,
    title: str,
    xlabel: str,
    ylabel: str,
    filename: str,
    cfg: AIDSConfig,
) -> None:
    groups = list(df[facet].dropna().unique())
    n = len(groups)
    ncols = 2 if n > 1 else 1
    nrows = math.ceil(n / ncols)
    fig, axes = plt.subplots(nrows, ncols, squeeze=False)
    for ax, group in zip(axes.ravel(), groups):
        sub = df[df[facet] == group]
        xv = sub[x].to_numpy(dtype=float)
        yv = sub[y].to_numpy(dtype=float)
        ax.scatter(xv, yv, color="navy", s=22)
        _fit_line(ax, xv, yv)
        _setup_axes(ax, str(group), xlabel, ylabel)
    for ax in axes.ravel()[len(groups) :]:
        ax.axis("off")
    fig.suptitle(title, fontsize=12, fontweight="bold", y=1.02)
    save_plot(fig, filename, cfg, width=10, height=6)


def corr_heatmap(data: pd.DataFrame, vars_: list[str], title: str, filename: str, cfg: AIDSConfig) -> None:
    C = data[vars_].corr()
    C_long = (
        C.reset_index(names="linha")
        .melt(id_vars="linha", var_name="coluna", value_name="correlacao")
        .assign(
            linha=lambda d: rotulo_variavel_produto(d["linha"].tolist()),
            coluna=lambda d: rotulo_variavel_produto(d["coluna"].tolist()),
        )
    )
    write_csv(C_long, cfg.tables / f"{filename}.csv")

    labels_x = C_long["coluna"].drop_duplicates().tolist()
    labels_y = C_long["linha"].drop_duplicates().tolist()
    mat = C_long.pivot(index="linha", columns="coluna", values="correlacao").loc[labels_y, labels_x]
    fig, ax = plt.subplots()
    im = ax.imshow(mat.to_numpy(dtype=float), vmin=-1, vmax=1, cmap="coolwarm")
    ax.set_xticks(range(len(labels_x)), labels_x, rotation=45, ha="right")
    ax.set_yticks(range(len(labels_y)), labels_y)
    for i in range(mat.shape[0]):
        for j in range(mat.shape[1]):
            ax.text(j, i, f"{mat.iloc[i, j]:.2f}", ha="center", va="center", fontsize=8)
    _setup_axes(ax, title)
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04, label="Correlação")
    save_plot(fig, filename, cfg)


def heat_matrix(long_data: pd.DataFrame, value_col: str, title: str, filename: str, cfg: AIDSConfig) -> None:
    col_order = ["bfvl", "pork", "poult", "fish"]
    row_order = ["fish", "poult", "pork", "bfvl"]
    mat = long_data.pivot(index="produto_linha", columns="produto_coluna", values=value_col).reindex(index=row_order, columns=col_order)
    fig, ax = plt.subplots()
    values = mat.to_numpy(dtype=float)
    vmax = np.nanmax(np.abs(values)) if np.isfinite(values).any() else 1
    im = ax.imshow(values, cmap="coolwarm", vmin=-vmax, vmax=vmax)
    ax.set_xticks(range(len(col_order)), col_order)
    ax.set_yticks(range(len(row_order)), row_order)
    for i in range(values.shape[0]):
        for j in range(values.shape[1]):
            if np.isfinite(values[i, j]):
                ax.text(j, i, f"{values[i, j]:.2f}", ha="center", va="center", fontsize=9)
    _setup_axes(ax, title, "Preço: nome da variável", "Demanda: nome da variável")
    fig.colorbar(im, ax=ax, fraction=0.046, pad=0.04, label="Valor")
    save_plot(fig, filename, cfg)


def _bar_plot(df: pd.DataFrame, x: str, y: str, title: str, xlabel: str, ylabel: str, filename: str, cfg: AIDSConfig, hline: float | None = None) -> None:
    fig, ax = plt.subplots()
    ax.bar(df[x].astype(str), df[y].to_numpy(dtype=float), color="navy", alpha=0.75)
    if hline is not None:
        ax.axhline(hline, linestyle="--", color="black", linewidth=1)
    _setup_axes(ax, title, xlabel, ylabel)
    ax.tick_params(axis="x", rotation=30)
    save_plot(fig, filename, cfg)


def generate_visualizations(cfg: AIDSConfig | None = None) -> None:
    cfg = cfg or default_config()
    cfg.ensure_dirs()
    tag = cfg.output_tag

    if not cfg.proc_pickle.exists():
        raise FileNotFoundError(f"Base processada não encontrada: {cfg.proc_pickle}")
    dados = pd.read_pickle(cfg.proc_pickle)
    model_hsym = load_pickle(cfg.tagged_model("model_hsym"))
    _elasticidades = load_pickle(cfg.tagged_model("elasticidades_hsym"))

    shares_long = series_long(dados, [f"w_{g}" for g in cfg.goods], "participacao")
    shares_long["produto"] = nome_produto(shares_long["serie"].str.replace(r"^w_", "", regex=True).tolist())
    _line_by_group(
        shares_long,
        "participacao",
        "produto",
        "Participações no dispêndio com carnes",
        "Participação do produto no gasto total com carnes",
        "PY_01_participacoes_dispendio" if tag == "PY" else "R_01_participacoes_dispendio",
        cfg,
    )

    prices_long = series_long(dados, [f"{g}p" for g in cfg.goods], "preco")
    prices_long["produto"] = nome_produto(prices_long["serie"].str.replace(r"p$", "", regex=True).tolist())
    _line_by_group(prices_long, "preco", "produto", "Índices de preços das carnes", "Índice de preço do produto", f"{tag}_02_precos", cfg)

    lngp_long = series_long(dados, [f"lngp_{g}" for g in cfg.goods], "lngp")
    lngp_long["produto"] = nome_produto(lngp_long["serie"].str.replace(r"^lngp_", "", regex=True).tolist())
    fig, ax = plt.subplots()
    ax.axhline(0, linestyle="--", color="black", linewidth=1)
    for prod, sub in lngp_long.groupby("produto", sort=False):
        ax.plot(sub["year"], sub["lngp"], marker="o", linewidth=1.5, markersize=3, label=prod, color=AIDS_COLORS.get(prod))
    _setup_axes(ax, "Preços em log normalizados pela média temporal", "Ano", "Desvio logarítmico do preço em relação à média")
    _add_legend_right(ax)
    save_plot(fig, f"{tag}_03_log_precos_normalizados", cfg)

    exp_long = series_long(dados, [f"x{g}" for g in cfg.goods], "dispendio")
    exp_long["produto"] = nome_produto(exp_long["serie"].str.replace(r"^x", "", regex=True).tolist())
    _line_by_group(exp_long, "dispendio", "produto", "Dispêndio anual por tipo de carne", "Dispêndio do produto", f"{tag}_04_dispendios_produto", cfg)

    fig, ax = plt.subplots()
    ax.plot(dados["year"], dados["xtotal_calc"], marker="o", color="navy", linewidth=1.5, markersize=3)
    _setup_axes(ax, "Dispêndio total com os quatro produtos de carne", "Ano", "Dispêndio total com carnes")
    save_plot(fig, f"{tag}_05_dispendio_total_carnes", cfg)

    stone_long = dados[["year", "lnP_stone", "ln_real_x"]].melt(id_vars="year", var_name="serie", value_name="valor")
    stone_long["serie"] = stone_long["serie"].replace({"lnP_stone": "Índice de Stone", "ln_real_x": "Dispêndio real com carnes"})
    _line_by_group(stone_long, "valor", "serie", "Índice de Stone e dispêndio real com carnes", "Valor em logaritmo", f"{tag}_06_stone_dispendio_real", cfg)

    if "meat_pce_share" in dados.columns:
        fig, ax = plt.subplots()
        ax.plot(dados["year"], dados["meat_pce_share"], marker="o", color="navy", linewidth=1.5, markersize=3)
        _setup_axes(ax, "Peso do dispêndio com carnes no consumo agregado", "Ano", "Participação do gasto com carnes no consumo agregado")
        save_plot(fig, f"{tag}_07_peso_carnes_pce", cfg)

    fig, ax = plt.subplots()
    ax.axhline(1, linestyle="--", color="black", linewidth=1)
    ax.plot(dados["year"], dados["share_sum"], marker="o", color="navy", linewidth=1.5, markersize=3)
    _setup_axes(ax, "Checagem da soma das participações no dispêndio", "Ano", "Soma das participações")
    save_plot(fig, f"{tag}_08_checagem_soma_participacoes", cfg)

    price_cols = [f"{g}p" for g in cfg.goods]
    share_cols = [f"w_{g}" for g in cfg.goods]
    tmp = dados[["year", *price_cols, *share_cols]].melt(id_vars="year", var_name="variavel", value_name="valor")
    tmp["produto"] = nome_produto(tmp["variavel"].str.replace(r"^w_", "", regex=True).str.replace(r"p$", "", regex=True).tolist())
    tmp["tipo"] = np.where(tmp["variavel"].str.startswith("w_"), "participacao", "preco")
    scatter = tmp.pivot_table(index=["year", "produto"], columns="tipo", values="valor").reset_index()
    _facet_scatter(scatter, "preco", "participacao", "produto", "Relação entre preço e participação no dispêndio", "Índice de preço do produto", "Participação no gasto total com carnes", f"{tag}_09_dispersao_preco_participacao", cfg)

    corr_heatmap(dados, [f"w_{g}" for g in cfg.goods], "Correlação entre participações", f"{tag}_10_correlacao_participacoes", cfg)
    corr_heatmap(dados, [f"lngp_{g}" for g in cfg.goods], "Correlação entre log-preços normalizados", f"{tag}_11_correlacao_log_precos", cfg)
    corr_heatmap(dados, [f"L1_lngp_{g}" for g in cfg.goods], "Correlação entre instrumentos defasados", f"{tag}_12_correlacao_instrumentos", cfg)

    coef_path = cfg.tagged_table("coeficientes")
    coeficientes = pd.read_csv(coef_path)
    coef_hsym = coeficientes[coeficientes["modelo"] == "homog_simetria"].copy()
    coef_hsym["lb"] = coef_hsym["estimativa"] - 1.96 * coef_hsym["erro_padrao"]
    coef_hsym["ub"] = coef_hsym["estimativa"] + 1.96 * coef_hsym["erro_padrao"]
    coef_hsym["parametro_rotulo"] = nome_parametro(coef_hsym["parametro"].tolist())
    coef_hsym["produto_legenda"] = "Outros"
    coef_hsym.loc[coef_hsym["parametro"].isin(["a_bfvl", "g11", "g12", "g14", "b_bfvl"]), "produto_legenda"] = "Carne bovina e vitela"
    coef_hsym.loc[coef_hsym["parametro"].isin(["a_pork", "g22", "g24", "b_pork"]), "produto_legenda"] = "Carne suína"
    coef_hsym.loc[coef_hsym["parametro"].isin(["a_fish", "g44", "b_fish"]), "produto_legenda"] = "Pescados"
    coef_hsym = coef_hsym.sort_values("estimativa")
    fig, ax = plt.subplots(figsize=(9, 7))
    y_pos = np.arange(len(coef_hsym))
    for prod, sub in coef_hsym.groupby("produto_legenda"):
        idx = [coef_hsym.index.get_loc(i) for i in sub.index]
        ax.errorbar(
            sub["estimativa"],
            np.array(idx),
            xerr=[sub["estimativa"] - sub["lb"], sub["ub"] - sub["estimativa"]],
            fmt="o",
            color=AIDS_COLORS.get(prod, "black"),
            ecolor="dimgray",
            label=prod,
        )
    ax.axvline(0, linestyle="--", color="black", linewidth=1)
    ax.set_yticks(y_pos, coef_hsym["parametro_rotulo"].tolist())
    _setup_axes(ax, "Coeficientes estimados no modelo com homogeneidade e simetria", "Estimativa do coeficiente", "Nome do parâmetro")
    _add_legend_right(ax)
    save_plot(fig, f"{tag}_13_coeficientes_hsym", cfg, width=11, height=7)

    comparacao = pd.read_csv(cfg.tagged_table("comparacao_modelos"))
    comparacao["modelo_rotulo"] = nome_modelo(comparacao["modelo"].tolist())
    _bar_plot(comparacao, "modelo_rotulo", "J", "Estatística objetivo do GMM", "Especificação estimada", "Estatística objetivo", f"{tag}_14_estatistica_J_modelos", cfg)
    _bar_plot(comparacao, "modelo_rotulo", "p_J", "p-valor do teste de sobreidentificação", "Especificação estimada", "p-valor", f"{tag}_15_pvalor_J_modelos", cfg, hline=0.05)

    l1_cols = [
        "w_bfvl", "w_pork", "w_fish", "ln_real_x", "lngp_bfvl", "lngp_pork", "lngp_poult", "lngp_fish",
        "L1_lngp_bfvl", "L1_lngp_pork", "L1_lngp_poult", "L1_lngp_fish",
    ]
    data_L1 = dados.dropna(subset=l1_cols).reset_index(drop=True)
    n = int(len(model_hsym.design.y) / len(cfg.est_goods))
    fit_tbl = pd.DataFrame(
        {
            "year": np.tile(data_L1["year"].to_numpy(), len(cfg.est_goods)),
            "produto": nome_produto(np.repeat(list(cfg.est_goods), n).tolist()),
            "observado": model_hsym.design.y.to_numpy(dtype=float),
            "previsto": model_hsym.fitted.to_numpy(dtype=float),
            "residuo": model_hsym.resid.to_numpy(dtype=float),
        }
    )
    write_csv(fit_tbl, cfg.tagged_table("ajuste_residuos_hsym"))

    _facet_scatter(fit_tbl, "previsto", "observado", "produto", "Observado versus previsto", "Previsto", "Observado", f"{tag}_16_observado_previsto", cfg)

    fig, ax = plt.subplots()
    ax.axhline(0, linestyle="--", color="black", linewidth=1)
    for prod, sub in fit_tbl.groupby("produto", sort=False):
        ax.plot(sub["year"], sub["residuo"], marker="o", linewidth=1.5, markersize=3, label=prod, color=AIDS_COLORS.get(prod))
    _setup_axes(ax, "Resíduos por equação estimada", "Ano", "Diferença entre participação observada e prevista")
    _add_legend_right(ax)
    save_plot(fig, f"{tag}_17_residuos_series", cfg)

    groups = list(fit_tbl["produto"].dropna().unique())
    fig, axes = plt.subplots(2, 2, squeeze=False)
    for ax, prod in zip(axes.ravel(), groups):
        sub = fit_tbl[fit_tbl["produto"] == prod]
        vals = sub["residuo"].to_numpy(dtype=float)
        ax.hist(vals, bins=12, density=True, color="navy", edgecolor="white", alpha=0.75)
        try:
            from scipy.stats import gaussian_kde
            mask = np.isfinite(vals)
            if mask.sum() >= 3 and np.nanstd(vals[mask]) > 0:
                kde = gaussian_kde(vals[mask])
                xs = np.linspace(vals[mask].min(), vals[mask].max(), 100)
                ax.plot(xs, kde(xs), color="red", linewidth=1.5)
        except Exception:
            pass
        _setup_axes(ax, prod, "Resíduo", "Densidade")
    for ax in axes.ravel()[len(groups) :]:
        ax.axis("off")
    fig.suptitle("Distribuição dos resíduos", fontsize=12, fontweight="bold", y=1.02)
    save_plot(fig, f"{tag}_18_hist_residuos", cfg, width=10, height=6)

    _facet_scatter(fit_tbl, "previsto", "residuo", "produto", "Resíduos versus valores previstos", "Previsto", "Resíduo", f"{tag}_19_residuos_vs_previsto", cfg)

    eta_tbl = pd.read_csv(cfg.tagged_table("elasticidade_dispendio_hsym"))
    _bar_plot(eta_tbl, "produto", "eta", "Elasticidade em relação ao dispêndio real", "Produto", "Elasticidade-dispêndio", f"{tag}_20_elasticidades_dispendio", cfg, hline=1)

    gamma_long = pd.read_csv(cfg.tagged_table("gamma_hsym_long"))
    em_long = pd.read_csv(cfg.tagged_table("elasticidades_marshallianas_hsym_long"))
    eh_long = pd.read_csv(cfg.tagged_table("elasticidades_compensadas_hsym_long"))
    heat_matrix(gamma_long, "gamma", "Matriz dos efeitos de preços", f"{tag}_21_matriz_gamma", cfg)
    heat_matrix(em_long, "elasticidade_marshalliana", "Elasticidades não compensadas", f"{tag}_22_elasticidades_marshallianas", cfg)
    heat_matrix(eh_long, "elasticidade_compensada", "Elasticidades compensadas", f"{tag}_23_elasticidades_compensadas", cfg)

    diag_fs = pd.read_csv(cfg.tagged_table("diagnostico_primeira_etapa"))
    diag_fs["instrumento_rotulo"] = diag_fs["instrumento"].replace({"L1": "Preços defasados em t-1", "L1_L2": "Preços defasados em t-1 e t-2"})
    diag_fs["preco_legenda"] = nome_produto(diag_fs["preco"].tolist())

    for value, title, ylabel, fname, hline in [
        ("F_excluidos", "Força dos instrumentos na primeira etapa", "Estatística F dos instrumentos defasados", f"{tag}_24_primeira_etapa_F", 10),
        ("r2_parcial", "Poder explicativo adicional dos instrumentos", "R² parcial dos instrumentos defasados", f"{tag}_25_primeira_etapa_R2_parcial", None),
    ]:
        fig, ax = plt.subplots()
        insts = list(diag_fs["instrumento_rotulo"].drop_duplicates())
        prods = list(diag_fs["preco_legenda"].drop_duplicates())
        x = np.arange(len(insts))
        width = 0.8 / max(len(prods), 1)
        for k, prod in enumerate(prods):
            vals = []
            for inst in insts:
                sub = diag_fs[(diag_fs["instrumento_rotulo"] == inst) & (diag_fs["preco_legenda"] == prod)]
                vals.append(float(sub[value].iloc[0]) if len(sub) else np.nan)
            ax.bar(x + (k - (len(prods) - 1) / 2) * width, vals, width=width, label=prod, color=AIDS_COLORS.get(prod))
        if hline is not None:
            ax.axhline(hline, linestyle="--", color="black", linewidth=1)
        ax.set_xticks(x, insts, rotation=10, ha="right")
        _setup_axes(ax, title, "Conjunto de instrumentos usado", ylabel)
        _add_legend_right(ax)
        save_plot(fig, fname, cfg)

    testes = pd.read_csv(cfg.tagged_table("testes_wald_restricoes"))
    _bar_plot(testes, "teste", "p_valor", "p-valores dos testes de restrições", "Restrição", "p-valor", f"{tag}_26_pvalores_testes_restricoes", cfg, hline=0.05)

    print(f"Visualizações salvas em {cfg.figures_pdf} e {cfg.figures_png}.")


if __name__ == "__main__":
    generate_visualizations()
