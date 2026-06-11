"""06 - Gráficos principais em PDF e PNG."""
from __future__ import annotations
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.stats import norm
import config
from gmm_core import load_models


def savefig(name: str, width: float = 9, height: float = 6) -> None:
    fig = plt.gcf()
    fig.set_size_inches(width, height)
    fig.tight_layout()
    fig.savefig(config.FIGPDF / f"{name}.pdf")
    fig.savefig(config.FIGPNG / f"{name}.png", dpi=320)
    plt.close(fig)


def _ols_line(x: pd.Series, y: pd.Series):
    coef = np.polyfit(x, y, 1)
    grid = np.linspace(x.min(), x.max(), 100)
    return grid, coef[0] * grid + coef[1]


def main():
    df = pd.read_pickle(config.OUTDATA / "prepared_data_python.pkl")
    models = load_models()
    work_path = config.OUTDATA / "python_elasticities_markups_work.pkl"
    work = pd.read_pickle(work_path) if work_path.exists() else df.copy()

    plt.figure()
    plt.scatter(df["price"], df["share"])
    plt.xlabel("Preço de transação")
    plt.ylabel("Market share (s_j)")
    plt.title("Share e preço por segmento")
    savefig("01_share_vs_transaction_price")

    top = df.sort_values("share", ascending=False).head(15)
    plt.figure()
    plt.barh(top["product"], top["share"])
    plt.gca().invert_yaxis()
    plt.xlabel("Market share")
    plt.title("Maiores produtos por market share")
    savefig("02_top15_market_shares")

    groups = [g["price"].to_numpy() for _, g in df.groupby("segment")]
    labels = [str(k) for k, _ in df.groupby("segment")]
    plt.figure()
    plt.boxplot(groups, tick_labels=labels)
    plt.xlabel("Segmento")
    plt.ylabel("Preço de transação")
    plt.title("Distribuição de preços por nest/segmento")
    savefig("03_price_by_segment")

    plt.figure()
    plt.scatter(df["price"], df["delta"])
    x, y = _ols_line(df["price"], df["delta"])
    plt.plot(x, y)
    plt.xlabel("Preço de transação")
    plt.ylabel("delta_j = ln(s_j) - ln(s_0)")
    plt.title("Inversão logit de Berry e preço")
    savefig("04_delta_vs_price")

    rows = []
    for name, m in models.items():
        alpha = m.coefficients.get("alpha", np.nan)
        if np.isfinite(alpha):
            rows.append({"model": name, "alpha": alpha})
    price_comp = pd.DataFrame(rows)
    price_comp.to_csv(config.OUTDATA / "price_parameter_comparison_python_graph.csv", index=False)
    if len(price_comp):
        plt.figure()
        plt.barh(price_comp["model"], price_comp["alpha"])
        plt.axvline(0, linestyle="--")
        plt.xlabel("Parâmetro alpha estimado")
        plt.title("Comparação das estimativas de alpha")
        savefig("05_price_coefficient_comparison")

    elas_file = config.TABCSV / "04_elasticity_matrix_simple_logit_subset.csv"
    if elas_file.exists():
        e = pd.read_csv(elas_file)
        piv = e.pivot(index="row_product", columns="column_product", values="elasticity")
        plt.figure()
        plt.imshow(piv.to_numpy(), aspect="auto")
        plt.colorbar(label="Elasticidade")
        plt.xticks(range(len(piv.columns)), piv.columns, rotation=90)
        plt.yticks(range(len(piv.index)), piv.index)
        plt.title("Matriz de elasticidades - logit simples")
        savefig("06_elasticity_matrix_subset", 10, 8)

    if "own_elasticity_simple_logit" in work.columns:
        tmp = work.sort_values("own_elasticity_simple_logit")
        plt.figure()
        plt.barh(tmp["product"], tmp["own_elasticity_simple_logit"])
        plt.xlabel("epsilon_jj")
        plt.title("Elasticidades-preço próprias")
        savefig("07_own_price_elasticities", 10, 8)

        vals = work["own_elasticity_simple_logit"].dropna()
        plt.figure()
        plt.hist(vals, bins=20, density=True)
        vals.plot(kind="density")
        plt.xlabel("epsilon_jj")
        plt.title("Distribuição das elasticidades próprias")
        savefig("18_own_elasticity_hist_density")

        plt.figure()
        plt.boxplot(vals)
        plt.ylabel("epsilon_jj")
        plt.title("Boxplot das elasticidades próprias")
        savefig("20_own_elasticity_boxplot")

    if {"markup_monoproduct", "markup_multiproduct"}.issubset(work.columns):
        tmp = work.sort_values("markup_multiproduct")
        y = np.arange(len(tmp))
        plt.figure()
        plt.barh(y - 0.2, tmp["markup_monoproduct"], height=0.4, label="monoproduto")
        plt.barh(y + 0.2, tmp["markup_multiproduct"], height=0.4, label="multiproduto")
        plt.yticks(y, tmp["product"])
        plt.xlabel("Markup")
        plt.legend()
        plt.title("Markups monoproduto e multiproduto")
        savefig("08_markups_mono_vs_multi", 10, 8)

        plt.figure()
        plt.scatter(work["price"], work["markup_multiproduct"])
        x, yhat = _ols_line(work["price"], work["markup_multiproduct"])
        plt.plot(x, yhat)
        plt.xlabel("Preço")
        plt.ylabel("Markup multiproduto")
        plt.title("Preço e markup multiproduto")
        savefig("09_price_vs_multiproduct_markup")

        vals = work["markup_multiproduct"].dropna()
        plt.figure()
        plt.hist(vals, bins=20, density=True)
        vals.plot(kind="density")
        plt.xlabel("Markup multiproduto")
        plt.title("Distribuição dos markups multiproduto")
        savefig("19_markup_multiproduct_hist_density")

        plt.figure()
        plt.boxplot(vals)
        plt.ylabel("Markup multiproduto")
        plt.title("Boxplot do markup multiproduto")
        savefig("21_markup_multiproduct_boxplot")

    fs_path = config.OUTDATA / "first_stage_diagnostics_python.pkl"
    if fs_path.exists():
        fs = pd.read_pickle(fs_path)
        fs.to_csv(config.OUTDATA / "first_stage_diagnostics_for_graph_python.csv", index=False)
        labels = fs["endogenous_variable"] + "\n" + fs["specification"]
        plt.figure()
        plt.barh(labels, fs["robust_Wald_F_manual"])
        plt.xlabel("F robusto")
        plt.title("F/Wald-F robusto do primeiro estágio")
        savefig("10_first_stage_robust_f")

    v = np.linspace(-8, 8, 300)
    s = np.exp(v) / (1 + np.exp(v))
    plt.figure()
    plt.plot(v, s)
    plt.xlabel("V_j - ln(C_j)")
    plt.ylabel("s_j previsto")
    plt.title("Curva clássica do logit")
    savefig("11_classic_logit_curve_share_vs_utility")

    if "GMM_both_2" in models:
        b = models["GMM_both_2"].coefficients
        alpha = float(b["alpha"])
        focal = df.sort_values("share", ascending=False).iloc[0]
        price_grid = np.linspace(df["price"].min(), df["price"].max(), 200)
        delta = b["b0"] + b["bcals"] * focal["cals"] + b["bfat"] * focal["fat"] + b["bsugar"] * focal["sugar"] - alpha * price_grid
        share = np.exp(delta) / (1 + np.exp(delta))
        dsdprice = -alpha * share * (1 - share)

        plt.figure()
        plt.plot(price_grid, share)
        plt.xlabel("p_j simulado")
        plt.ylabel("s_j previsto")
        plt.title(f"Resposta do share ao preço: {focal['product']}")
        savefig("12_focal_product_share_vs_price")

        # Sem linha pontilhada de referência: a curva fica mais legível.
        plt.figure()
        plt.plot(price_grid, dsdprice)
        plt.xlabel("p_j simulado")
        plt.ylabel("ds_j/dp_j")
        plt.title(f"Efeito marginal do preço: {focal['product']}")
        savefig("13_focal_product_marginal_effect_vs_price")

        pred = df.copy()
        pred["delta_hat"] = b["b0"] + b["bcals"] * pred["cals"] + b["bfat"] * pred["fat"] + b["bsugar"] * pred["sugar"] - alpha * pred["price"]
        pred["share_pred"] = np.exp(pred["delta_hat"]) / (1 + np.exp(pred["delta_hat"]).sum())
        plt.figure()
        plt.scatter(pred["share"], pred["share_pred"])
        lim = [min(pred["share"].min(), pred["share_pred"].min()), max(pred["share"].max(), pred["share_pred"].max())]
        plt.plot(lim, lim, linestyle="--")
        plt.xlabel("s_j observado")
        plt.ylabel("s_j previsto")
        plt.title("Shares observados vs previstos - logit simples")
        savefig("14_observed_vs_predicted_shares_simple_logit")

    res_path = config.OUTDATA / "python_after_simple_gmm.pkl"
    if res_path.exists():
        res = pd.read_pickle(res_path)
        vals = res["xi_gmm_both"].dropna()
        plt.figure()
        plt.hist(vals, bins=20, density=True)
        vals.plot(kind="density")
        plt.xlabel("xi_j estimado")
        plt.title("Distribuição do resíduo estrutural")
        savefig("15_structural_residual_hist_density")

        sample = np.sort(vals.to_numpy())
        n = len(sample)
        theoretical = norm.ppf((np.arange(1, n + 1) - 0.5) / n)
        plt.figure()
        plt.scatter(theoretical, sample)
        plt.plot([theoretical.min(), theoretical.max()], [theoretical.min(), theoretical.max()], linestyle="--")
        plt.xlabel("Quantis normais")
        plt.ylabel("Quantis amostrais")
        plt.title("QQ plot do resíduo estrutural")
        savefig("16_structural_residual_qqplot")

    print("Gráficos principais exportados.")


if __name__ == "__main__":
    main()
