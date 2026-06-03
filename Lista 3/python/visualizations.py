# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Centraliza a geração dos gráficos principais e extras em matplotlib.
# savefig salva cada figura em PNG 300 dpi e PDF na estrutura outputs/python/figures.
# plot_core cobre gráficos diretamente associados às questões; plot_extra adiciona diagnósticos complementares.

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path
from config import FIG_PDF, FIG_PNG


def savefig(name):
    # Salva primeiro em PNG 300 dpi. Em seguida, cria o PDF a partir do PNG para
    # evitar travamentos ocasionais do backend PDF do matplotlib em gráficos com muitos rótulos.
    # O resultado continua sendo adequado para relatório e mantém a mesma figura em PDF e PNG.
    from PIL import Image
    FIG_PNG.mkdir(parents=True, exist_ok=True)
    FIG_PDF.mkdir(parents=True, exist_ok=True)
    print(f"[python] salvando gráfico {name}", flush=True)
    png_path = FIG_PNG / f"{name}.png"
    pdf_path = FIG_PDF / f"{name}.pdf"
    plt.savefig(png_path, dpi=300)
    with Image.open(png_path) as im:
        im.convert("RGB").save(pdf_path, "PDF", resolution=300.0)
    plt.close("all")


def plot_hist_density(values, xlabel, title, name, bins=12, vertical_zero=False):
    """Histograma em escala de densidade com curva kernel sobreposta."""
    from scipy import stats
    values = np.asarray(values, dtype=float)
    values = values[np.isfinite(values)]
    plt.figure(figsize=(8, 5))
    plt.hist(values, bins=bins, density=True, alpha=0.55, label="Histograma")
    if values.size >= 3 and np.nanstd(values) > 0:
        xs = np.linspace(values.min(), values.max(), 250)
        kde = stats.gaussian_kde(values)
        plt.plot(xs, kde(xs), linewidth=2, label="Densidade kernel")
    if vertical_zero:
        plt.axvline(0, linewidth=1)
    plt.xlabel(xlabel)
    plt.ylabel("Densidade")
    plt.title(title)
    plt.legend(frameon=False)
    savefig(name)


def plot_core(df, results_compare=None, elasticity_matrix=None, markup_df=None, diag_df=None):
    # 1. Preço e share.
    plt.figure(figsize=(8, 5))
    for seg, g in df.groupby("segment"):
        plt.scatter(g["price"], g["share"], label=seg, s=45)
    plt.xlabel("Preço de transação")
    plt.ylabel("Market share interno (em relação ao mercado total)")
    plt.title("Share e preço por segmento")
    plt.legend(title="Segmento", frameon=False)
    savefig("01_share_vs_transaction_price")

    # 2. Top shares.
    top = df.sort_values("share", ascending=False).head(15).iloc[::-1]
    plt.figure(figsize=(9, 6))
    plt.barh(top["product"], top["share"])
    plt.xlabel("Market share")
    plt.title("Maiores produtos por market share")
    savefig("02_top15_market_shares")

    # 3. Preços por segmento.
    plt.figure(figsize=(7, 5))
    segs = list(df["segment"].dropna().unique())
    plt.boxplot([df.loc[df["segment"] == s, "price"] for s in segs], labels=segs)
    plt.ylabel("Preço de transação")
    plt.title("Distribuição de preços por nest/segmento")
    savefig("03_price_by_segment")

    # 4. Relação delta-preço.
    plt.figure(figsize=(8, 5))
    plt.scatter(df["price"], df["delta"], s=45)
    z = np.polyfit(df["price"], df["delta"], 1)
    xs = np.linspace(df["price"].min(), df["price"].max(), 100)
    plt.plot(xs, z[0]*xs + z[1])
    plt.xlabel("Preço de transação")
    plt.ylabel(r"$\delta_j = \ln(s_j)-\ln(s_0)$")
    plt.title("Inversão logit de Berry e preço")
    savefig("04_delta_vs_price")

    if results_compare is not None:
        d = results_compare.copy()
        plt.figure(figsize=(10, 5))
        plt.bar(d["model"], d["price_coef"])
        plt.axhline(0, linewidth=1)
        plt.xticks(rotation=35, ha="right")
        plt.ylabel("Coeficiente do preço (= -alpha)")
        plt.title("Comparação das estimativas de preço")
        savefig("05_price_coefficient_comparison")

    if elasticity_matrix is not None:
        sel = elasticity_matrix.iloc[:12, :12]
        plt.figure(figsize=(8, 7))
        plt.imshow(sel.values, aspect="auto")
        plt.colorbar(label="Elasticidade")
        plt.xticks(range(sel.shape[1]), sel.columns, rotation=70, ha="right", fontsize=8)
        plt.yticks(range(sel.shape[0]), sel.index, fontsize=8)
        plt.title("Matriz de elasticidades-preço - subconjunto")
        savefig("06_elasticity_matrix_subset")

        own = np.diag(elasticity_matrix.values)
        ord_idx = np.argsort(own)[:15]
        plt.figure(figsize=(9, 6))
        plt.barh(df.iloc[ord_idx]["product"], own[ord_idx])
        plt.xlabel("Elasticidade própria")
        plt.title("Elasticidades próprias mais intensas")
        savefig("07_own_price_elasticities")

        # 18. Distribuição das elasticidades próprias: histograma + densidade kernel.
        plot_hist_density(own, "Elasticidade própria",
                          "Distribuição das elasticidades próprias",
                          "18_own_elasticity_hist_density",
                          bins=12, vertical_zero=True)

        # 20. Boxplot das elasticidades próprias para manter a leitura de dispersão/outliers.
        plt.figure(figsize=(7, 5))
        plt.boxplot(own, vert=True)
        plt.axhline(0, linewidth=1)
        plt.ylabel("Elasticidade própria")
        plt.title("Boxplot das elasticidades próprias")
        plt.xticks([1], ["Logit simples"])
        savefig("20_own_elasticity_boxplot")

    if markup_df is not None:
        m = markup_df.sort_values("markup_multiproduct", ascending=False).head(15).iloc[::-1]
        y = np.arange(len(m))
        plt.figure(figsize=(9, 6))
        plt.barh(y - 0.18, m["markup_monoproduct"], height=0.36, label="Monoproduto")
        plt.barh(y + 0.18, m["markup_multiproduct"], height=0.36, label="Multiproduto")
        plt.yticks(y, m["product"])
        plt.xlabel("Markup implícito")
        plt.title("Comparação de markups implícitos")
        plt.legend(frameon=False)
        savefig("08_markups_mono_vs_multi")

        plt.figure(figsize=(8, 5))
        plt.scatter(markup_df["price"], markup_df["markup_multiproduct"], s=45)
        plt.xlabel("Preço observado")
        plt.ylabel("Markup multiproduto")
        plt.title("Preço observado e markup multiproduto")
        savefig("09_price_vs_multiproduct_markup")

        # 19. Distribuição dos markups multiproduto: histograma + densidade kernel.
        plot_hist_density(markup_df["markup_multiproduct"], "Markup multiproduto",
                          "Distribuição dos markups multiproduto",
                          "19_markup_multiproduct_hist_density",
                          bins=12, vertical_zero=True)

        # 21. Boxplot dos markups multiproduto.
        plt.figure(figsize=(7, 5))
        plt.boxplot(markup_df["markup_multiproduct"], vert=True)
        plt.axhline(0, linewidth=1)
        plt.ylabel("Markup multiproduto")
        plt.title("Boxplot dos markups multiproduto")
        plt.xticks([1], ["Multiproduto"])
        savefig("21_markup_multiproduct_boxplot")

    if diag_df is not None:
        plt.figure(figsize=(7, 5))
        plt.bar(diag_df["endogenous_variable"], diag_df["robust_Wald_F_manual"])
        plt.axhline(10, linestyle="--", linewidth=1)
        plt.ylabel("F robusto manual")
        plt.title("Diagnóstico de força dos instrumentos")
        savefig("10_first_stage_robust_f")


def plot_extra(df, first_stage_fitted=None, residuals=None, instruments=None):
    print("[python] extra 01 concentração por firma", flush=True)
    # A. Concentração por firma.
    firm = df.groupby("firm", as_index=False)["share"].sum().sort_values("share")
    plt.figure(figsize=(7, 5))
    plt.barh(firm["firm"], firm["share"])
    plt.xlabel("Share agregado")
    plt.title("Concentração de market share por firma")
    savefig("extra_01_firm_share_concentration")

    print("[python] extra 02 nests", flush=True)
    # B. Concentração por segmento/nest.
    seg = df.groupby("segment", as_index=False)["share"].sum().sort_values("share")
    plt.figure(figsize=(7, 5))
    plt.bar(seg["segment"], seg["share"])
    plt.ylabel("Share agregado")
    plt.title("Tamanho dos nests")
    savefig("extra_02_nest_sizes")

    print("[python] extra 03 características", flush=True)
    # C. Características por segmento.
    for x in ["cals", "fat", "sugar"]:
        means = df.groupby("segment", as_index=False)[x].mean()
        plt.figure(figsize=(7, 5))
        plt.bar(means["segment"], means[x])
        plt.ylabel(x)
        plt.title(f"Média de {x} por segmento")
        savefig(f"extra_03_mean_{x}_by_segment")

    print("[python] extra 04 correlação instrumentos", flush=True)
    # D. Matriz de correlação dos instrumentos.
    if instruments is not None:
        corr = df[instruments].corr().values
        labs = instruments
        plt.figure(figsize=(9, 8))
        plt.imshow(corr, vmin=-1, vmax=1, aspect="auto")
        plt.colorbar(label="Correlação")
        plt.xticks(range(len(labs)), labs, rotation=75, ha="right", fontsize=7)
        plt.yticks(range(len(labs)), labs, fontsize=7)
        plt.title("Correlação entre instrumentos excluídos")
        savefig("extra_04_instrument_correlation_matrix")

    print("[python] extra 05 resíduos", flush=True)
    # E. Resíduos estruturais por preço/firma.
    if residuals is not None:
        plt.figure(figsize=(8, 5))
        plt.scatter(df["price"], residuals, s=45)
        plt.axhline(0, linewidth=1)
        plt.xlabel("Preço de transação")
        plt.ylabel("Resíduo estrutural estimado")
        plt.title("Resíduos estruturais e preço")
        savefig("extra_05_structural_residuals_vs_price")
        print("[python] extra 05 scatter concluído", flush=True)

        # Boxplot de resíduos por firma
        firms = list(df["firm"].unique())
        plt.figure(figsize=(8, 5))
        plt.boxplot([residuals[df["firm"].values == f] for f in firms], tick_labels=firms)
        plt.ylabel("Resíduo estrutural")
        plt.title("Resíduos estruturais por firma")
        savefig("extra_06_structural_residuals_by_firm")
        print("[python] extra 06 box concluído", flush=True)

    print("[python] extra 07 primeiro estágio", flush=True)
    # F. Fitted vs actual no primeiro estágio.
    if first_stage_fitted is not None:
        plt.figure(figsize=(7, 5))
        plt.scatter(df["price"], first_stage_fitted, s=45)
        lo = min(df["price"].min(), first_stage_fitted.min())
        hi = max(df["price"].max(), first_stage_fitted.max())
        plt.plot([lo, hi], [lo, hi], linewidth=1)
        plt.xlabel("Preço observado")
        plt.ylabel("Preço ajustado no primeiro estágio")
        plt.title("Primeiro estágio: preço observado vs ajustado")
        savefig("extra_07_first_stage_price_fit")
        print("[python] extra 07 concluído", flush=True)



def plot_logit_model_diagnostics(df, simple_result, residuals=None):
    """Gera gráficos clássicos e diagnósticos do modelo logit multinomial.

    Os gráficos mantêm características e rivais fixos e simulam apenas a utilidade
    média ou o preço do produto focal. Isso evita confundir a curva teórica do logit
    com a nuvem bruta observada, onde preço, características e composição de rivais
    variam simultaneamente.
    """
    from scipy import stats

    beta = dict(zip(simple_result.coef_names, simple_result.coef))
    price_coef = beta.get("price", np.nan)  # coeficiente estimado do preço, isto é, -alpha
    xbeta_no_price = np.full(len(df), beta.get("const", 0.0), dtype=float)
    for x in ["cals", "fat", "sugar"]:
        xbeta_no_price += beta.get(x, 0.0) * df[x].to_numpy(dtype=float)
    vhat = xbeta_no_price + price_coef * df["price"].to_numpy(dtype=float)
    expv = np.exp(vhat)
    denom = 1.0 + expv.sum()
    pred_share = expv / denom

    focal_idx = int(df["share"].to_numpy().argmax())
    focal_name = str(df.iloc[focal_idx]["product"])
    C = 1.0 + expv.sum() - expv[focal_idx]

    # 11. Curva clássica em S: share previsto contra a utilidade relativa
    # V_j - ln(C_j), onde C_j = 1 + soma dos exp(V_k) dos rivais e outside good.
    # Nessa escala, s_j = 1/(1 + exp(-(V_j - ln C_j))).
    rel_grid = np.linspace(-6.0, 6.0, 250)
    s_grid = 1.0 / (1.0 + np.exp(-rel_grid))
    rel_observed_index = vhat[focal_idx] - np.log(C)
    plt.figure(figsize=(8, 5))
    plt.plot(rel_grid, s_grid, linewidth=2)
    plt.scatter([rel_observed_index], [pred_share[focal_idx]], s=60, label="ponto estimado")
    plt.axvline(rel_observed_index, linestyle="--", linewidth=1)
    plt.xlabel(r"Utilidade relativa $V_j - \ln(C_j)$")
    plt.ylabel("Share previsto")
    plt.title(f"Curva clássica do logit - {focal_name}")
    plt.legend(frameon=False)
    savefig("11_classic_logit_curve_share_vs_utility")

    # 12. Curva de resposta ao preço do produto focal.
    p0 = float(df.iloc[focal_idx]["price"])
    p_grid = np.linspace(max(0.01, 0.5 * p0), 1.5 * p0, 250)
    v_price = xbeta_no_price[focal_idx] + price_coef * p_grid
    s_price = np.exp(v_price) / (C + np.exp(v_price))
    plt.figure(figsize=(8, 5))
    plt.plot(p_grid, s_price, linewidth=2)
    plt.scatter([p0], [df.iloc[focal_idx]["share"]], s=60, label="observado")
    plt.axvline(p0, linestyle="--", linewidth=1)
    plt.xlabel("Preço simulado do produto focal")
    plt.ylabel("Share previsto")
    plt.title(f"Resposta do share ao preço - {focal_name}")
    plt.legend(frameon=False)
    savefig("12_focal_product_share_vs_price")

    # 13. Efeito marginal ds_j/dp_j ao longo da curva de preço.
    marginal_effect = price_coef * s_price * (1.0 - s_price)
    plt.figure(figsize=(8, 5))
    plt.plot(p_grid, marginal_effect, linewidth=2)
    plt.axhline(0, linewidth=1)
    plt.axvline(p0, linestyle="--", linewidth=1)
    plt.xlabel("Preço simulado do produto focal")
    plt.ylabel(r"Efeito marginal $\partial s_j / \partial p_j$")
    plt.title(f"Efeito marginal do preço - {focal_name}")
    savefig("13_focal_product_marginal_effect_vs_price")

    # 14. Share observado versus share previsto pelo logit simples.
    plt.figure(figsize=(7, 5))
    plt.scatter(pred_share, df["share"], s=45)
    lo = float(min(pred_share.min(), df["share"].min()))
    hi = float(max(pred_share.max(), df["share"].max()))
    plt.plot([lo, hi], [lo, hi], linewidth=1)
    plt.xlabel("Share previsto pelo logit simples")
    plt.ylabel("Share observado")
    plt.title("Share observado versus previsto")
    savefig("14_observed_vs_predicted_shares_simple_logit")

    if residuals is not None:
        residuals = np.asarray(residuals, dtype=float)
        # 15. Histograma dos resíduos estruturais com curva de densidade kernel.
        plot_hist_density(residuals, "Resíduo estrutural estimado",
                          "Distribuição dos resíduos estruturais",
                          "15_structural_residual_hist_density",
                          bins=12, vertical_zero=True)

        # 16. QQ plot dos resíduos estruturais.
        qq = stats.probplot(residuals, dist="norm")
        theoretical = qq[0][0]
        ordered = qq[0][1]
        slope, intercept = qq[1][0], qq[1][1]
        plt.figure(figsize=(7, 5))
        plt.scatter(theoretical, ordered, s=35)
        plt.plot(theoretical, intercept + slope * theoretical, linewidth=1)
        plt.xlabel("Quantis teóricos normais")
        plt.ylabel("Quantis dos resíduos")
        plt.title("QQ plot dos resíduos estruturais")
        savefig("16_structural_residual_qqplot")

    # 17. Curvas de resposta ao preço dos cinco maiores produtos.
    top_idx = df.sort_values("share", ascending=False).head(5).index.to_list()
    plt.figure(figsize=(8, 5))
    for idx in top_idx:
        pos = int(df.index.get_loc(idx))
        p_i = float(df.loc[idx, "price"])
        p_grid_i = np.linspace(max(0.01, 0.5 * p_i), 1.5 * p_i, 200)
        C_i = 1.0 + expv.sum() - expv[pos]
        v_i = xbeta_no_price[pos] + price_coef * p_grid_i
        s_i = np.exp(v_i) / (C_i + np.exp(v_i))
        plt.plot(p_grid_i, s_i, label=str(df.loc[idx, "product"]))
    plt.xlabel("Preço simulado")
    plt.ylabel("Share previsto")
    plt.title("Curvas de resposta ao preço - top 5 produtos")
    plt.legend(frameon=False, fontsize=8)
    savefig("17_price_response_curves_top5_products")
