"""Núcleo operacional equivalente ao eberry/b_program em Python."""
from __future__ import annotations
import pickle
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable
import numpy as np
import pandas as pd
from scipy.optimize import minimize
from scipy.stats import norm
import config


def safe_inv(a: np.ndarray) -> np.ndarray:
    try:
        inv = np.linalg.inv(a)
        if np.all(np.isfinite(inv)):
            return inv
    except np.linalg.LinAlgError:
        pass
    return np.linalg.pinv(a)


def matrix(df: pd.DataFrame, cols: Iterable[str]) -> np.ndarray:
    return df.loc[:, list(cols)].astype(float).to_numpy()


@dataclass
class ModelResult:
    model: str
    coefficients: dict
    vcov: np.ndarray
    se: dict
    residuals: np.ndarray
    N: int
    k: int
    q: int
    Q: float | None
    J: int | None
    xvars: list[str]
    zvars: list[str]
    bnames: list[str]
    step: int | None = None


def _complete(df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    return df.loc[:, list(dict.fromkeys(cols))].dropna().copy()


def fit_ols(df: pd.DataFrame, y: str, xvars: list[str], bnames: list[str] | None = None, hc1: bool = True) -> ModelResult:
    bnames = bnames or xvars
    d = _complete(df, [y] + xvars)
    Y = matrix(d, [y])
    X = matrix(d, xvars)
    N, k = X.shape
    b = safe_inv(X.T @ X) @ X.T @ Y
    u = (Y - X @ b).ravel()
    meat = X.T @ (X * (u ** 2)[:, None])
    if hc1 and N > k:
        meat *= N / (N - k)
    V = safe_inv(X.T @ X) @ meat @ safe_inv(X.T @ X)
    b = b.ravel()
    se = np.sqrt(np.maximum(np.diag(V), 0))
    return ModelResult("OLS", dict(zip(bnames, b)), V, dict(zip(bnames, se)), u, N, k, k, None, None, xvars, xvars, bnames)


def fit_iv_2sls(df: pd.DataFrame, y: str, xvars: list[str], zvars: list[str], bnames: list[str] | None = None) -> ModelResult:
    bnames = bnames or xvars
    d = _complete(df, [y] + xvars + zvars)
    Y = matrix(d, [y])
    X = matrix(d, xvars)
    Z = matrix(d, zvars)
    N, k = X.shape
    q = Z.shape[1]
    W = safe_inv((Z.T @ Z) / N)
    b = safe_inv(X.T @ Z @ W @ Z.T @ X) @ (X.T @ Z @ W @ Z.T @ Y)
    u = (Y - X @ b).ravel()
    Zu = Z * u[:, None]
    S = (Zu.T @ Zu) / N
    D = -(Z.T @ X) / N
    A = D.T @ W @ D
    B = D.T @ W @ S @ W @ D
    V = safe_inv(A) @ B @ safe_inv(A) / N
    gbar = (Z.T @ u) / N
    Q = float(N * gbar.T @ W @ gbar)
    b = b.ravel()
    se = np.sqrt(np.maximum(np.diag(V), 0))
    return ModelResult("IV_2SLS", dict(zip(bnames, b)), V, dict(zip(bnames, se)), u, N, k, q, Q, q-k, xvars, zvars, bnames)


def berry_gmm_fit(df: pd.DataFrame, y: str, xvars: list[str], zvars: list[str], bnames: list[str], step: int = 2, maxiter: int = 20000) -> ModelResult:
    d = _complete(df, [y] + xvars + zvars)
    Y = matrix(d, [y])
    X = matrix(d, xvars)
    Z = matrix(d, zvars)
    N, k = X.shape
    q = Z.shape[1]
    if len(bnames) != k:
        raise ValueError("Número de bnames difere do número de colunas de X.")
    bstart = (safe_inv(X.T @ X) @ X.T @ Y).ravel()
    bstart[~np.isfinite(bstart)] = 0.0

    def obj(beta: np.ndarray, W: np.ndarray) -> float:
        xi = (Y.ravel() - X @ beta)
        gbar = (Z.T @ xi) / N
        return float(N * gbar.T @ W @ gbar)

    W = safe_inv((Z.T @ Z) / N)
    opt = minimize(obj, bstart, args=(W,), method="Nelder-Mead", options={"maxiter": maxiter, "xatol": 1e-10, "fatol": 1e-12})
    p = opt.x
    xi = Y.ravel() - X @ p
    Zxi = Z * xi[:, None]
    Szz = (Zxi.T @ Zxi) / N
    if step == 2:
        W = safe_inv(Szz)
        opt = minimize(obj, p, args=(W,), method="Nelder-Mead", options={"maxiter": maxiter, "xatol": 1e-10, "fatol": 1e-12})
        p = opt.x
        xi = Y.ravel() - X @ p
        Zxi = Z * xi[:, None]
        Szz = (Zxi.T @ Zxi) / N
    gbar = (Z.T @ xi) / N
    D = -(Z.T @ X) / N
    A = D.T @ W @ D
    B = D.T @ W @ Szz @ W @ D
    V = safe_inv(A) @ B @ safe_inv(A) / N
    Q = float(N * gbar.T @ W @ gbar)
    se = np.sqrt(np.maximum(np.diag(V), 0))
    return ModelResult(f"GMM_step{step}", dict(zip(bnames, p)), V, dict(zip(bnames, se)), xi, N, k, q, Q, q-k, xvars, zvars, bnames, step)


def tidy_model(model: ModelResult, name: str) -> pd.DataFrame:
    rows = []
    for par, est in model.coefficients.items():
        se = model.se.get(par, np.nan)
        t = est / se if se else np.nan
        rows.append({
            "model": name,
            "parameter": par,
            "estimate": est,
            "std_error": se,
            "statistic": t,
            "p_value": 2 * norm.sf(abs(t)) if np.isfinite(t) else np.nan,
            "objective_gmm": model.Q,
            "sigma_nested": model.coefficients.get("sigma", np.nan),
        })
    return pd.DataFrame(rows)


def save_models(models: dict[str, ModelResult], path: Path | None = None) -> None:
    path = path or config.OUTDATA / "model_results_python.pkl"
    with open(path, "wb") as f:
        pickle.dump(models, f)


def load_models(path: Path | None = None) -> dict[str, ModelResult]:
    path = path or config.OUTDATA / "model_results_python.pkl"
    if not path.exists():
        return {}
    with open(path, "rb") as f:
        return pickle.load(f)


def wald_test_excluded(df: pd.DataFrame, y: str, controls: list[str], excluded: list[str]) -> dict:
    xvars = ["cons"] + controls + excluded
    mod = fit_ols(df, y, xvars, xvars)
    b = np.array([mod.coefficients[v] for v in excluded])
    idx = [mod.bnames.index(v) for v in excluded]
    V = mod.vcov[np.ix_(idx, idx)]
    W = float(b.T @ safe_inv(V) @ b)
    return {"F": W / len(excluded), "chi2": W, "df": len(excluded)}


def r2_ols(df: pd.DataFrame, y: str, xvars: list[str]) -> float:
    d = _complete(df, [y] + xvars)
    Y = d[y].astype(float).to_numpy()
    X = matrix(d, xvars)
    b = safe_inv(X.T @ X) @ X.T @ Y
    u = Y - X @ b
    return float(1 - (u @ u) / np.sum((Y - Y.mean())**2))
