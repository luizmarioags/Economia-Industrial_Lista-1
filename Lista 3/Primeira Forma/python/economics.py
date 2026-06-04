# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Calcula objetos econômicos após a estimação: elasticidades logit, elasticidades nested numéricas e markups.
# simple_logit_elasticity_matrix aplica diretamente as fórmulas da lista.
# markups monta Delta de Bertrand e compara hipóteses monoproduto e multiproduto.

import numpy as np
import pandas as pd


def simple_logit_elasticity_matrix(df, alpha):
    prices = df["price"].to_numpy(dtype=float)
    shares = df["share"].to_numpy(dtype=float)
    n = len(df)
    E = np.empty((n, n), dtype=float)
    for j in range(n):
        for k in range(n):
            if j == k:
                E[j, k] = -alpha * prices[j] * (1 - shares[j])
            else:
                E[j, k] = alpha * prices[k] * shares[k]
    return pd.DataFrame(E, index=df["product"], columns=df["product"])


def nested_logit_numerical_elasticities(df, coef, coef_names, eps=1e-6):
    """Elasticidades numéricas para nested logit por choque de preço produto a produto.
    Mantém características e nests fixos e recalcula shares pelo sistema nested logit.
    """
    beta = dict(zip(coef_names, coef))
    alpha = -beta.get("price", np.nan)
    sigma = beta.get("log_share_within_nest", np.nan)
    if not np.isfinite(alpha) or not np.isfinite(sigma) or sigma >= 1:
        return None

    products = df["product"].to_numpy()
    p0 = df["price"].to_numpy(dtype=float)
    Xb = beta.get("const", 0.0)
    for x in ["cals", "fat", "sugar"]:
        Xb = Xb + beta.get(x, 0.0) * df[x].to_numpy(dtype=float)
    groups = df["segment"].to_numpy()

    def predict_shares(p):
        # Inclusive value nested logit com outside good normalizado a zero.
        delta = Xb - alpha * p
        unique_g = pd.unique(groups)
        Dg = []
        within = np.zeros(len(p))
        for g in unique_g:
            idx = (groups == g)
            exp_inner = np.exp(delta[idx] / max(1 - sigma, 1e-8))
            denom_inner = exp_inner.sum()
            within[idx] = exp_inner / denom_inner
            Dg.append(denom_inner ** (1 - sigma))
        Dg = np.asarray(Dg)
        group_probs = Dg / (1.0 + Dg.sum())
        s = np.zeros(len(p))
        for i, g in enumerate(unique_g):
            idx = (groups == g)
            s[idx] = within[idx] * group_probs[i]
        return s

    s0 = predict_shares(p0)
    E = np.empty((len(p0), len(p0)))
    for k in range(len(p0)):
        p1 = p0.copy()
        p1[k] += eps
        s1 = predict_shares(p1)
        deriv = (s1 - s0) / eps
        E[:, k] = deriv * p0[k] / np.maximum(s0, 1e-12)
    return pd.DataFrame(E, index=products, columns=products)


def markups(df, alpha):
    p = df["price"].to_numpy(dtype=float)
    s = df["share"].to_numpy(dtype=float)
    firms = df["firm"].to_numpy()
    n = len(df)
    mono = 1.0 / (alpha * (1 - s))

    Delta = np.zeros((n, n), dtype=float)
    for j in range(n):
        for k in range(n):
            if firms[j] != firms[k]:
                continue
            if j == k:
                Delta[j, k] = alpha * s[j] * (1 - s[j])
            else:
                Delta[j, k] = -alpha * s[j] * s[k]
    multi = np.linalg.pinv(Delta) @ s
    out = pd.DataFrame({
        "product": df["product"].to_numpy(),
        "firm": firms,
        "segment": df["segment"].to_numpy(),
        "price": p,
        "share": s,
        "markup_monoproduct": mono,
        "mc_monoproduct": p - mono,
        "markup_multiproduct": multi,
        "mc_multiproduct": p - multi,
        "markup_mono_over_price": mono / p,
        "markup_multi_over_price": multi / p,
    })
    return out
