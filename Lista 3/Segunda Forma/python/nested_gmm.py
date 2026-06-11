"""03 - Nested logit por IV/2SLS e GMM operacional."""
from __future__ import annotations
import pandas as pd
import config
from gmm_core import fit_iv_2sls, berry_gmm_fit, load_models, save_models


def main():
    df = pd.read_pickle(config.OUTDATA / "prepared_data_python.pkl")
    models = load_models()

    x_nested = ["cons"] + config.XVARS + ["neg_price", "log_share_within_nest"]
    z_nested = ["cons"] + config.XVARS + config.ZNESTALL
    bnames = ["b0", "bcals", "bfat", "bsugar", "alpha", "sigma"]

    models["IV_nested"] = fit_iv_2sls(df, "delta", x_nested, z_nested, bnames)
    models["GMM_nested_1"] = berry_gmm_fit(df, "delta", x_nested, z_nested, bnames, step=1)
    models["GMM_nested_2"] = berry_gmm_fit(df, "delta", x_nested, z_nested, bnames, step=2)

    m = models["GMM_nested_2"].coefficients
    df_after = df.copy()
    df_after["xi_nested"] = (
        df_after["delta"]
        - m["b0"]
        - m["bcals"] * df_after["cals"]
        - m["bfat"] * df_after["fat"]
        - m["bsugar"] * df_after["sugar"]
        - m["alpha"] * df_after["neg_price"]
        - m["sigma"] * df_after["log_share_within_nest"]
    )
    df_after.to_pickle(config.OUTDATA / "python_after_nested_gmm.pkl")
    df_after.to_csv(config.OUTDATA / "python_after_nested_gmm.csv", index=False)
    save_models(models)
    print(f"Nested GMM estimado. alpha = {m['alpha']:.4f}; sigma = {m['sigma']:.4f}")
    return models


if __name__ == "__main__":
    main()
