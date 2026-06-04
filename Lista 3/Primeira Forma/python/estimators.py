# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Implementa manualmente MQO, 2SLS, GMM linear, GMM eficiente e diagnósticos de primeiro estágio.
# Não usa bibliotecas prontas de IV/GMM; numpy é usado apenas para álgebra matricial e scipy para p-valores.
# EstimationResult padroniza o armazenamento de coeficientes, erros, resíduos, objetivo GMM, alpha e sigma.

import numpy as np
import pandas as pd
from dataclasses import dataclass
from scipy import stats


def add_const(mat):
    mat = np.asarray(mat, dtype=float)
    return np.column_stack([np.ones(mat.shape[0]), mat])


def pinv(a):
    return np.linalg.pinv(np.asarray(a, dtype=float), rcond=1e-12)


@dataclass
class EstimationResult:
    name: str
    coef: np.ndarray
    se: np.ndarray
    t: np.ndarray
    pval: np.ndarray
    resid: np.ndarray
    fitted: np.ndarray
    objective: float | None
    nobs: int
    k: int
    coef_names: list
    alpha: float | None = None
    sigma: float | None = None

    def to_frame(self):
        out = pd.DataFrame({
            "model": self.name,
            "parameter": self.coef_names,
            "estimate": self.coef,
            "std_error": self.se,
            "t_stat": self.t,
            "p_value": self.pval,
        })
        if self.objective is not None:
            out["gmm_objective"] = self.objective
        return out


def robust_ols_vcov(X, resid):
    n, k = X.shape
    meat = X.T @ (X * (resid ** 2)[:, None])
    bread = pinv(X.T @ X)
    return (n / max(n - k, 1)) * bread @ meat @ bread


def ols(y, X, names, model_name="OLS"):
    y = np.asarray(y, dtype=float).reshape(-1)
    X = np.asarray(X, dtype=float)
    beta = pinv(X.T @ X) @ X.T @ y
    fitted = X @ beta
    resid = y - fitted
    vcov = robust_ols_vcov(X, resid)
    se = np.sqrt(np.maximum(np.diag(vcov), 0))
    t = beta / se
    pval = 2 * (1 - stats.t.cdf(np.abs(t), df=max(len(y)-X.shape[1], 1)))
    return EstimationResult(model_name, beta, se, t, pval, resid, fitted, None, len(y), X.shape[1], names,
                            alpha=-beta[names.index("price")] if "price" in names else None,
                            sigma=beta[names.index("log_share_within_nest")] if "log_share_within_nest" in names else None)


def iv_vcov(y, X, Z, beta):
    n = X.shape[0]
    resid = y - X @ beta
    Qxz = X.T @ Z / n
    Qzx = Qxz.T
    Qzz_inv = pinv(Z.T @ Z / n)
    A = Qxz @ Qzz_inv @ Qzx
    Zu = Z * resid[:, None]
    S = Zu.T @ Zu / n
    middle = Qxz @ Qzz_inv @ S @ Qzz_inv @ Qzx
    vcov = pinv(A) @ middle @ pinv(A) / n
    return vcov, resid


def two_sls(y, X, Z, names, model_name="2SLS"):
    y = np.asarray(y, dtype=float).reshape(-1)
    X = np.asarray(X, dtype=float)
    Z = np.asarray(Z, dtype=float)
    Pz = Z @ pinv(Z.T @ Z) @ Z.T
    beta = pinv(X.T @ Pz @ X) @ X.T @ Pz @ y
    fitted = X @ beta
    vcov, resid = iv_vcov(y, X, Z, beta)
    se = np.sqrt(np.maximum(np.diag(vcov), 0))
    t = beta / se
    pval = 2 * (1 - stats.norm.cdf(np.abs(t)))
    return EstimationResult(model_name, beta, se, t, pval, resid, fitted, None, len(y), X.shape[1], names,
                            alpha=-beta[names.index("price")] if "price" in names else None,
                            sigma=beta[names.index("log_share_within_nest")] if "log_share_within_nest" in names else None)


def linear_gmm(y, X, Z, W=None, names=None, model_name="GMM"):
    y = np.asarray(y, dtype=float).reshape(-1)
    X = np.asarray(X, dtype=float)
    Z = np.asarray(Z, dtype=float)
    n = len(y)
    if W is None:
        W = pinv(Z.T @ Z / n)
    beta = pinv(X.T @ Z @ W @ Z.T @ X) @ (X.T @ Z @ W @ Z.T @ y)
    fitted = X @ beta
    resid = y - fitted
    gbar = Z.T @ resid / n
    objective = float(n * (gbar.T @ W @ gbar))

    # VCV GMM robusta: (D'WD)^-1 D'W S W D (D'WD)^-1 / n, D = E[Z X'].
    D = Z.T @ X / n
    S = (Z * resid[:, None]).T @ (Z * resid[:, None]) / n
    A = D.T @ W @ D
    vcov = pinv(A) @ (D.T @ W @ S @ W @ D) @ pinv(A) / n
    se = np.sqrt(np.maximum(np.diag(vcov), 0))
    t = beta / se
    pval = 2 * (1 - stats.norm.cdf(np.abs(t)))
    names = names or [f"b{i}" for i in range(X.shape[1])]
    return EstimationResult(model_name, beta, se, t, pval, resid, fitted, objective, n, X.shape[1], names,
                            alpha=-beta[names.index("price")] if "price" in names else None,
                            sigma=beta[names.index("log_share_within_nest")] if "log_share_within_nest" in names else None)


def efficient_gmm(y, X, Z, names, model_name="GMM_2step"):
    n = len(y)
    W1 = pinv(Z.T @ Z / n)
    step1 = linear_gmm(y, X, Z, W1, names, model_name + "_step1")
    S = (Z * step1.resid[:, None]).T @ (Z * step1.resid[:, None]) / n
    W2 = pinv(S)
    step2 = linear_gmm(y, X, Z, W2, names, model_name)
    return step1, step2


def first_stage_diagnostics(df, endog_vars, exog_vars, excluded_instr):
    rows = []
    n = len(df)
    W = add_const(df[exog_vars].to_numpy())
    Z_excl = df[excluded_instr].to_numpy()
    Full = np.column_stack([W, Z_excl])
    q = Z_excl.shape[1]
    for endog in endog_vars:
        y = df[endog].to_numpy()
        res_full = ols(y, Full, ["const"] + exog_vars + excluded_instr, f"first_stage_{endog}")
        res_rest = ols(y, W, ["const"] + exog_vars, f"first_stage_restricted_{endog}")
        rss_full = float(res_full.resid @ res_full.resid)
        rss_rest = float(res_rest.resid @ res_rest.resid)
        df_num = q
        df_den = max(n - Full.shape[1], 1)
        f_partial = ((rss_rest - rss_full) / df_num) / (rss_full / df_den)

        # Wald robusto manual para H0: coeficientes dos instrumentos excluídos = 0.
        coef_excl = res_full.coef[-q:]
        vcov_full = robust_ols_vcov(Full, res_full.resid)
        V_excl = vcov_full[-q:, -q:]
        wald = float(coef_excl.T @ pinv(V_excl) @ coef_excl)
        robust_f = wald / q
        rows.append({
            "endogenous_variable": endog,
            "nobs": n,
            "excluded_instruments": q,
            "partial_F_homoskedastic": f_partial,
            "robust_Wald_F_manual": robust_f,
            "first_stage_R2": 1 - rss_full / float(((y - y.mean()) @ (y - y.mean()))),
        })
    return pd.DataFrame(rows)


def build_designs(df):
    exog = ["cals", "fat", "sugar"]
    names_logit = ["const"] + exog + ["price"]
    y = df["delta"].to_numpy()
    X_logit = add_const(df[exog + ["price"]].to_numpy())

    own = [f"own_{x}" for x in exog]
    rival = [f"rival_{x}" for x in exog]
    Z_own = add_const(df[exog + own].to_numpy())
    Z_rival = add_const(df[exog + rival].to_numpy())
    Z_both = add_const(df[exog + own + rival].to_numpy())

    names_nested = ["const"] + exog + ["price", "log_share_within_nest"]
    X_nested = add_const(df[exog + ["price", "log_share_within_nest"]].to_numpy())
    nest_instr = ["n_same_nest_other", "n_rival_nest"] + [f"nest_own_{x}" for x in exog] + [f"nest_rival_{x}" for x in exog]
    Z_nested = add_const(df[exog + own + rival + nest_instr].to_numpy())

    return {
        "y": y,
        "exog": exog,
        "names_logit": names_logit,
        "X_logit": X_logit,
        "Z_own": Z_own,
        "Z_rival": Z_rival,
        "Z_both": Z_both,
        "own_instr": own,
        "rival_instr": rival,
        "both_instr": own + rival,
        "names_nested": names_nested,
        "X_nested": X_nested,
        "Z_nested": Z_nested,
        "nested_instr": own + rival + nest_instr,
    }
