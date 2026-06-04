"""08 - Tabelas padronizadas em CSV e TEX."""
from __future__ import annotations
import numpy as np
import pandas as pd
import config
from gmm_core import load_models, tidy_model, safe_inv
from io_tables import export_csv_tex


def nested_shares(price_vec: np.ndarray, base_df: pd.DataFrame, coef: dict) -> np.ndarray:
    sigma = float(coef["sigma"])
    scale = max(1 - sigma, 1e-8)
    delta = coef["b0"] + coef["bcals"]*base_df["cals"].to_numpy(float) + coef["bfat"]*base_df["fat"].to_numpy(float) + coef["bsugar"]*base_df["sugar"].to_numpy(float) + coef["bp"]*price_vec
    s = np.zeros(len(base_df))
    ids = base_df["idsegment"].to_numpy()
    nests = np.unique(ids)
    Dg = np.zeros(len(nests))
    within = np.zeros(len(base_df))
    for i, g in enumerate(nests):
        idx = np.where(ids == g)[0]
        expinner = np.exp(delta[idx] / scale)
        den = expinner.sum()
        within[idx] = expinner / den
        Dg[i] = den ** scale
    gp = Dg / (1 + Dg.sum())
    for i, g in enumerate(nests):
        idx = np.where(ids == g)[0]
        s[idx] = within[idx] * gp[i]
    return s


def main():
    models = load_models()
    df = pd.read_pickle(config.OUTDATA / "prepared_data_python.pkl")

    all_coef = pd.concat([tidy_model(m, name) for name, m in models.items()], ignore_index=True)
    export_csv_tex(all_coef, config.TABCSV / "01_all_coefficients.csv", config.TABTEX / "01_all_coefficients.tex", "Coeficientes estimados", "tab:all-coef")

    rows = []
    for name, m in models.items():
        b = m.coefficients
        se = m.se
        coef_price = b.get("bp", b.get("price", np.nan))
        se_price = se.get("bp", se.get("price", np.nan))
        rows.append({
            "model": name,
            "price_coef_minus_alpha": coef_price,
            "alpha": -coef_price,
            "price_se": se_price,
            "gmm_objective": m.Q,
            "sigma_nested": b.get("sigma", np.nan),
        })
    price_parameter = pd.DataFrame(rows)
    export_csv_tex(price_parameter, config.TABCSV / "02_price_parameter_comparison.csv", config.TABTEX / "02_price_parameter_comparison.tex", "Comparação do parâmetro de preço", "tab:price-compare")

    if "GMM_both_2" not in models:
        raise RuntimeError("GMM_both_2 não encontrado.")
    alpha = -models["GMM_both_2"].coefficients["bp"]

    rows_df = df.reset_index(drop=True).rename_axis("row_id").reset_index()
    cols_df = df.reset_index(drop=True).rename_axis("col_id").reset_index()
    rows_df["row_id"] += 1
    cols_df["col_id"] += 1
    simple = rows_df[["row_id", "product", "price", "share"]].merge(cols_df[["col_id", "product", "price", "share"]], how="cross", suffixes=("_row", "_col"))
    simple["elasticity"] = np.where(simple["row_id"] == simple["col_id"], -alpha*simple["price_row"]*(1-simple["share_row"]), alpha*simple["price_col"]*simple["share_col"])
    out_simple = simple.rename(columns={"product_row": "row_product", "product_col": "column_product"})[["row_product", "column_product", "elasticity"]]
    export_csv_tex(out_simple, config.TABCSV / "03_elasticity_matrix_simple_logit.csv", config.TABTEX / "03_elasticity_matrix_simple_logit.tex", "Matriz de elasticidades - logit simples", "tab:elas-simple")

    sub = df.sort_values("share", ascending=False).head(12).reset_index(drop=True)
    rows_sub = sub.rename_axis("row_id").reset_index(); rows_sub["row_id"] += 1
    cols_sub = sub.rename_axis("col_id").reset_index(); cols_sub["col_id"] += 1
    simple_sub = rows_sub[["row_id", "product", "price", "share"]].merge(cols_sub[["col_id", "product", "price", "share"]], how="cross", suffixes=("_row", "_col"))
    simple_sub["elasticity"] = np.where(simple_sub["row_id"] == simple_sub["col_id"], -alpha*simple_sub["price_row"]*(1-simple_sub["share_row"]), alpha*simple_sub["price_col"]*simple_sub["share_col"])
    out_sub = simple_sub.rename(columns={"product_row": "row_product", "product_col": "column_product"})[["row_product", "column_product", "elasticity"]]
    export_csv_tex(out_sub, config.TABCSV / "04_elasticity_matrix_simple_logit_subset.csv", config.TABTEX / "04_elasticity_matrix_simple_logit_subset.tex", "Matriz de elasticidades - logit simples - subconjunto", "tab:elas-simple-subset")

    own_simple = df.assign(own_elasticity_simple_logit=-alpha*df["price"]*(1-df["share"])).sort_values("share", ascending=False)[["product", "firm", "segment", "price", "share", "own_elasticity_simple_logit"]]
    export_csv_tex(own_simple, config.TABCSV / "05_own_elasticities_simple_logit.csv", config.TABTEX / "05_own_elasticities_simple_logit.tex", "Elasticidades próprias - logit simples", "tab:own-elas-simple")

    if "GMM_nested_2" not in models:
        raise RuntimeError("GMM_nested_2 não encontrado.")
    coefn = models["GMM_nested_2"].coefficients
    p0 = df["price"].to_numpy(float)
    s0 = nested_shares(p0, df, coefn)
    n = len(df)
    E = np.full((n, n), np.nan)
    eps = 1e-6
    for k in range(n):
        p1 = p0.copy(); p1[k] += eps
        s1 = nested_shares(p1, df, coefn)
        E[:, k] = ((s1 - s0) / eps) * p0[k] / s0
    rr = pd.DataFrame({"row_id": np.arange(n), "row_product": df["product"].to_numpy()})
    cc = pd.DataFrame({"col_id": np.arange(n), "column_product": df["product"].to_numpy()})
    nested = rr.merge(cc, how="cross")
    nested["elasticity"] = [E[i, j] for i, j in zip(nested["row_id"], nested["col_id"])]
    export_csv_tex(nested[["row_product", "column_product", "elasticity"]], config.TABCSV / "06_elasticity_matrix_nested_logit.csv", config.TABTEX / "06_elasticity_matrix_nested_logit.tex", "Matriz de elasticidades - nested logit", "tab:elas-nested")

    own_nested = pd.DataFrame({"product": df["product"], "own_elasticity_nested_logit": np.diag(E)}).sort_values("own_elasticity_nested_logit")
    export_csv_tex(own_nested, config.TABCSV / "07_own_elasticities_nested_logit.csv", config.TABTEX / "07_own_elasticities_nested_logit.tex", "Elasticidades próprias - nested logit", "tab:own-elas-nested")

    s = df["share"].to_numpy(float); f = df["idfirm"].to_numpy(); Delta = np.zeros((n, n))
    for j in range(n):
        for k in range(n):
            if f[j] == f[k]:
                Delta[j, k] = alpha*s[j]*(1-s[j]) if j == k else -alpha*s[j]*s[k]
    mu = safe_inv(Delta) @ s
    markups = df.assign(
        markup_monoproduct=1/(alpha*(1-df["share"])),
        mc_monoproduct=lambda d: d["price"] - d["markup_monoproduct"],
        markup_multiproduct=mu,
        mc_multiproduct=lambda d: d["price"] - d["markup_multiproduct"],
        markup_mono_over_price=lambda d: d["markup_monoproduct"]/d["price"],
        markup_multi_over_price=lambda d: d["markup_multiproduct"]/d["price"],
    )[["product", "firm", "segment", "price", "share", "markup_monoproduct", "mc_monoproduct", "markup_multiproduct", "mc_multiproduct", "markup_mono_over_price", "markup_multi_over_price"]]
    export_csv_tex(markups, config.TABCSV / "08_markups.csv", config.TABTEX / "08_markups.tex", "Markups implícitos - logit simples", "tab:markups")

    fs_path = config.OUTDATA / "first_stage_diagnostics_python.pkl"
    if fs_path.exists():
        fs = pd.read_pickle(fs_path)
        export_csv_tex(fs, config.TABCSV / "09_first_stage_diagnostics.csv", config.TABTEX / "09_first_stage_diagnostics.tex", "Diagnóstico de primeiro estágio", "tab:first-stage")
    print("Tabelas CSV/TEX exportadas.")


if __name__ == "__main__":
    main()
