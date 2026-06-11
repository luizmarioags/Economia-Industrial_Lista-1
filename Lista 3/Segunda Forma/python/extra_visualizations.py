"""07 - Gráficos extras para inspeção estatística e econômica."""
from __future__ import annotations
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import config
from gmm_core import fit_ols
from visualizations import savefig


def main():
    df = pd.read_pickle(config.OUTDATA / "prepared_data_python.pkl")
    work_path = config.OUTDATA / "python_after_simple_gmm.pkl"
    work = pd.read_pickle(work_path) if work_path.exists() else df.copy()

    firm_share = df.groupby("firm", as_index=False).agg(
        total_share=("share", "sum"), n_products=("product", "size")
    ).sort_values("total_share")
    plt.figure()
    plt.barh(firm_share["firm"], firm_share["total_share"])
    plt.xlabel("Share total")
    plt.title("Concentração de share por firma")
    savefig("extra_01_firm_share_concentration")

    nest_sizes = df.groupby("segment", as_index=False).agg(
        n_products=("product", "size"), total_share=("share", "sum")
    ).sort_values("n_products")
    plt.figure()
    plt.barh(nest_sizes["segment"], nest_sizes["n_products"])
    plt.xlabel("Produtos")
    plt.title("Número de produtos por nest/segmento")
    savefig("extra_02_nest_sizes")

    for x in config.XVARS:
        seg = df.groupby("segment", as_index=False)[x].mean().sort_values(x)
        plt.figure()
        plt.barh(seg["segment"], seg[x])
        plt.xlabel(f"Média de {x}")
        plt.title(f"Média de {x} por segmento")
        savefig(f"extra_03_mean_{x}_by_segment")

    inst = df[config.ZBOTH + config.ZNEST]
    cor = inst.corr()
    plt.figure()
    plt.imshow(cor.to_numpy(), aspect="auto", vmin=-1, vmax=1)
    plt.colorbar(label="Correlação")
    plt.xticks(range(len(cor.columns)), cor.columns, rotation=90)
    plt.yticks(range(len(cor.index)), cor.index)
    plt.title("Matriz de correlação dos instrumentos")
    savefig("extra_04_instrument_correlation_matrix", 10, 8)

    if "xi_gmm_both" in work.columns:
        plt.figure()
        plt.scatter(work["price"], work["xi_gmm_both"])
        coef = np.polyfit(work["price"], work["xi_gmm_both"], 1)
        x = np.linspace(work["price"].min(), work["price"].max(), 100)
        plt.plot(x, coef[0] * x + coef[1])
        plt.axhline(0, linestyle="--")
        plt.xlabel("Preço")
        plt.ylabel("xi_j estimado")
        plt.title("Resíduos estruturais vs preço")
        savefig("extra_05_structural_residuals_vs_price")

        groups = [g["xi_gmm_both"].dropna().to_numpy() for _, g in work.groupby("firm")]
        labels = [str(k) for k, _ in work.groupby("firm")]
        plt.figure()
        plt.boxplot(groups, tick_labels=labels, vert=False)
        plt.xlabel("xi_j estimado")
        plt.title("Resíduos estruturais por firma")
        savefig("extra_06_structural_residuals_by_firm")

    fs = fit_ols(df, "neg_price", ["cons"] + config.XVARS + config.ZBOTH, ["cons"] + config.XVARS + config.ZBOTH)
    X = df[["cons"] + config.XVARS + config.ZBOTH].to_numpy(float)
    neg_price_hat = X @ np.array([fs.coefficients[v] for v in fs.bnames])
    price_hat = -neg_price_hat
    plt.figure()
    plt.scatter(df["price"], price_hat)
    lim = [min(df["price"].min(), price_hat.min()), max(df["price"].max(), price_hat.max())]
    plt.plot(lim, lim, linestyle="--")
    plt.xlabel("Preço observado")
    plt.ylabel("Preço previsto")
    plt.title("Primeiro estágio: preço observado vs previsto")
    savefig("extra_07_first_stage_price_fit")

    print("Gráficos extras exportados.")


if __name__ == "__main__":
    main()
