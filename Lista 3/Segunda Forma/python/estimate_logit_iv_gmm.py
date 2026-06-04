"""02 - MQO, 2SLS e GMM estrutural do logit simples."""
from __future__ import annotations
import pandas as pd
import config
from gmm_core import fit_ols, fit_iv_2sls, berry_gmm_fit, load_models, save_models


def main():
    df = pd.read_pickle(config.OUTDATA / "prepared_data_python.pkl")
    models = load_models()
    models["OLS"] = fit_ols(df, "delta", ["cons", "price"] + config.XVARS, ["b0", "price"] + config.XVARS)
    models["IV_own"] = fit_iv_2sls(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZOWN, ["b0"] + config.XVARS + ["price"])
    models["IV_rival"] = fit_iv_2sls(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZRIVAL, ["b0"] + config.XVARS + ["price"])
    models["IV_both"] = fit_iv_2sls(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZBOTH, ["b0"] + config.XVARS + ["price"])
    bnames = ["b0", "bcals", "bfat", "bsugar", "bp"]
    models["GMM_own_1"] = berry_gmm_fit(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZOWN, bnames, step=1)
    models["GMM_own_2"] = berry_gmm_fit(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZOWN, bnames, step=2)
    models["GMM_rival_1"] = berry_gmm_fit(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZRIVAL, bnames, step=1)
    models["GMM_rival_2"] = berry_gmm_fit(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZRIVAL, bnames, step=2)
    models["GMM_both_1"] = berry_gmm_fit(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZBOTH, bnames, step=1)
    models["GMM_both_2"] = berry_gmm_fit(df, "delta", ["cons"] + config.XVARS + ["price"], ["cons"] + config.XVARS + config.ZBOTH, bnames, step=2)
    m = models["GMM_both_2"].coefficients
    df_after = df.copy()
    df_after["xi_gmm_both"] = df_after["delta"] - m["b0"] - m["bcals"]*df_after["cals"] - m["bfat"]*df_after["fat"] - m["bsugar"]*df_after["sugar"] - m["bp"]*df_after["price"]
    df_after.to_pickle(config.OUTDATA / "python_after_simple_gmm.pkl")
    df_after.to_csv(config.OUTDATA / "python_after_simple_gmm.csv", index=False)
    save_models(models)
    print("Modelos de logit simples estimados e salvos.")
    return models


if __name__ == "__main__":
    main()
