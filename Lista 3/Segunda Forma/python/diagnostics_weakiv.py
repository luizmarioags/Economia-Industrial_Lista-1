"""05 - Diagnóstico dos instrumentos/primeiro estágio."""
from __future__ import annotations
import pandas as pd
import config
from gmm_core import wald_test_excluded, r2_ols


def _diag(df, y, excluded, spec):
    rob = wald_test_excluded(df, y, config.XVARS, excluded)
    r2 = r2_ols(df, y, ["cons"] + config.XVARS + excluded)
    return {
        "endogenous_variable": y,
        "excluded_instruments": len(excluded),
        "partial_F_homoskedastic": rob["F"],
        "robust_Wald_F_manual": rob["F"],
        "first_stage_R2": r2,
        "specification": spec,
    }


def main():
    df = pd.read_pickle(config.OUTDATA / "prepared_data_python.pkl")
    out = pd.DataFrame([
        _diag(df, "price", config.ZBOTH, "simple_logit_both"),
        _diag(df, "price", config.ZNESTALL, "nested_logit"),
        _diag(df, "log_share_within_nest", config.ZNESTALL, "nested_logit"),
    ])
    out.to_pickle(config.OUTDATA / "first_stage_diagnostics_python.pkl")
    out.to_csv(config.OUTDATA / "first_stage_diagnostics_python.csv", index=False)
    print("Diagnósticos de primeiro estágio calculados.")
    return out


if __name__ == "__main__":
    main()
