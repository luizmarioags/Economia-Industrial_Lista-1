"""04 - Elasticidades e markups implícitos."""
from __future__ import annotations
import numpy as np
import pandas as pd
import config
from gmm_core import load_models, safe_inv


def main():
    df = pd.read_pickle(config.OUTDATA / "python_after_simple_gmm.pkl")
    models = load_models()
    if "GMM_both_2" not in models:
        raise RuntimeError("GMM_both_2 não encontrado. Rode estimate_logit_iv_gmm.py antes.")

    alpha = float(models["GMM_both_2"].coefficients["alpha"])
    if not np.isfinite(alpha):
        raise ValueError("Alpha não finito no modelo GMM_both_2.")
    if alpha <= 0:
        print(f"Atenção: alpha <= 0 ({alpha:.5f}). O modelo foi estimado sem impor demanda decrescente.")

    df = df.copy()
    df["own_elasticity_simple_logit"] = -alpha * df["price"] * (1 - df["share"])
    df["markup_monoproduct"] = 1 / (alpha * (1 - df["share"]))
    df["mc_monoproduct"] = df["price"] - df["markup_monoproduct"]

    s = df["share"].to_numpy(float)
    f = df["idfirm"].to_numpy()
    n = len(s)
    Delta = np.zeros((n, n))
    for j in range(n):
        for k in range(n):
            if f[j] == f[k]:
                Delta[j, k] = alpha * s[j] * (1 - s[j]) if j == k else -alpha * s[j] * s[k]

    mu = safe_inv(Delta) @ s
    df["markup_multiproduct"] = mu
    df["mc_multiproduct"] = df["price"] - df["markup_multiproduct"]
    df["markup_multi_over_price"] = df["markup_multiproduct"] / df["price"]
    df["markup_mono_over_price"] = df["markup_monoproduct"] / df["price"]

    df.to_pickle(config.OUTDATA / "python_elasticities_markups_work.pkl")
    df.to_csv(config.OUTDATA / "python_elasticities_markups_work.csv", index=False)
    print(f"Elasticidades e markups calculados. alpha = {alpha:.5f}")
    return df


if __name__ == "__main__":
    main()
