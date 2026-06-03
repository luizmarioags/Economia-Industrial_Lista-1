"""
Funções econométricas: MQO, 2SLS, GMM, Hansen J, Wald, AR e MOP.
CORREÇÕES APLICADAS:
  - mop_f_eff(): retorna np.nan com aviso quando denominador ~ 0
  - ar_interval(): alerta quando IC toca limites da grade;
                   retorna beta0_minp, p_min, open_left, open_right
"""
import numpy as np
import pandas as pd
import warnings
from scipy import stats


def pinv(a: np.ndarray) -> np.ndarray:
    return np.linalg.pinv(np.asarray(a, dtype=float))


def add_const(df) -> pd.DataFrame:
    if isinstance(df, np.ndarray):
        df = pd.DataFrame(df)
    out = df.copy()
    out.insert(0, "const", 1.0)
    return out


def ols_hc1(y, x):
    """MQO com variância robusta HC1."""
    y = np.asarray(y, dtype=float).reshape(-1, 1)
    x = np.asarray(x, dtype=float)
    n, k = x.shape
    beta   = pinv(x.T @ x) @ (x.T @ y)
    resid  = (y - x @ beta).reshape(-1)
    fitted = (x @ beta).reshape(-1)
    meat   = (x * resid[:, None]).T @ (x * resid[:, None])
    vcov   = (n / (n - k)) * pinv(x.T @ x) @ meat @ pinv(x.T @ x)
    se     = np.sqrt(np.diag(vcov))
    return {"beta": beta.reshape(-1), "vcov": vcov, "se": se,
            "resid": resid, "fitted": fitted, "n": n, "k": k, "df": n - k}


def wald_test(beta, vcov, r_matrix, r=None, df_denom=None):
    """Teste de Wald robusto para H0: R*beta = r."""
    beta = np.asarray(beta, dtype=float).reshape(-1, 1)
    R    = np.asarray(r_matrix, dtype=float)
    if r is None:
        r = np.zeros((R.shape[0], 1))
    diff = R @ beta - r
    W    = (diff.T @ pinv(R @ vcov @ R.T) @ diff).item()
    q    = R.shape[0]
    F    = W / q
    if df_denom is None:
        pval = stats.chi2.sf(W, q)
    else:
        pval = stats.f.sf(F, q, df_denom)
    return {"W": W, "F": F, "p": pval, "q": q}


def partial_r2(x, controls, instruments):
    """R² parcial dos instrumentos excluídos condicional aos controles."""
    x       = np.asarray(x, dtype=float)
    C       = np.asarray(controls, dtype=float)
    Z       = np.asarray(instruments, dtype=float)
    rx      = ols_hc1(x, C)["resid"]
    rz_cols = []
    for j in range(Z.shape[1]):
        rz_cols.append(ols_hc1(Z[:, j], C)["resid"])
    RZ  = np.column_stack(rz_cols)
    fit = ols_hc1(rx, RZ)
    ssr = np.sum(fit["resid"] ** 2)
    tss = np.sum(rx ** 2)
    return 1.0 - ssr / tss


def mop_f_eff(y_endog, z_excl, x_incl):
    """
    F Efetivo de Montiel Olea-Pflueger — implementação 'na mão'.

    Parâmetros
    ----------
    y_endog : variável endógena (vetor n×1)
    z_excl  : instrumentos excluídos (matriz n×L); SEM constante
    x_incl  : controles incluídos (matriz n×K); DEVE incluir a constante

    Retorna np.nan com aviso se o denominador for numericamente zero.
    """
    y_endog = np.asarray(y_endog, dtype=float).reshape(-1, 1)
    z_excl  = np.asarray(z_excl,  dtype=float)
    x_incl  = np.asarray(x_incl,  dtype=float)

    if z_excl.ndim == 1:
        z_excl = z_excl.reshape(-1, 1)

    n       = x_incl.shape[0]
    k_total = x_incl.shape[1] + z_excl.shape[1]

    # 1. Residualizar endógena e instrumentos excluídos contra os controles.
    y_perp = ols_hc1(y_endog, x_incl)["resid"].reshape(-1, 1)
    z_perp = np.zeros_like(z_excl)
    for j in range(z_excl.shape[1]):
        z_perp[:, j] = ols_hc1(z_excl[:, j], x_incl)["resid"]

    # 2. Primeiro estágio nos resíduos.
    W      = z_perp.T @ z_perp
    pi_hat = pinv(W) @ (z_perp.T @ y_perp)

    # 3. Resíduos do primeiro estágio residualizado.
    v_hat = (y_perp - z_perp @ pi_hat).reshape(-1)

    # 4. Numerador: pi' W pi.
    numerator = (pi_hat.T @ W @ pi_hat).item()

    # 5. Denominador: traço da covariância robusta (HC1).
    dfc         = n / (n - k_total)
    meat        = (z_perp * v_hat[:, None]).T @ (z_perp * v_hat[:, None]) * dfc
    S           = pinv(W) @ meat
    denominator = np.trace(S)

    # 6. Proteção contra denominador zero.
    if abs(denominator) < np.finfo(float).eps * 100:
        warnings.warn("mop_f_eff: denominador numericamente zero — retornando np.nan.")
        return np.nan

    return numerator / denominator


def iv_2sls(y, x, z):
    """2SLS com variância robusta à heterocedasticidade (sandwich HC)."""
    y = np.asarray(y, dtype=float).reshape(-1, 1)
    X = np.asarray(x, dtype=float)
    Z = np.asarray(z, dtype=float)
    n, k = X.shape

    W    = pinv(Z.T @ Z)
    beta = pinv(X.T @ Z @ W @ Z.T @ X) @ (X.T @ Z @ W @ Z.T @ y)
    resid  = (y - X @ beta).reshape(-1)
    fitted = (X @ beta).reshape(-1)

    Qxz  = X.T @ Z / n
    Wn   = pinv(Z.T @ Z / n)
    S    = (Z * resid[:, None]).T @ (Z * resid[:, None]) / n
    A    = Qxz @ Wn @ Qxz.T
    vcov = pinv(A) @ Qxz @ Wn @ S @ Wn @ Qxz.T @ pinv(A) / n
    vcov = (n / (n - k)) * vcov
    se   = np.sqrt(np.diag(vcov))

    return {"beta": beta.reshape(-1), "vcov": vcov, "se": se,
            "resid": resid, "fitted": fitted, "n": n, "k": k, "df": n - k}


def iv_gmm_2step(y, x, z):
    """GMM em dois passos com teste Hansen J."""
    y = np.asarray(y, dtype=float).reshape(-1, 1)
    X = np.asarray(x, dtype=float)
    Z = np.asarray(z, dtype=float)
    n, k = X.shape
    l = Z.shape[1]

    # Passo 1
    W1    = pinv(Z.T @ Z / n)
    beta1 = pinv(X.T @ Z @ W1 @ Z.T @ X) @ (X.T @ Z @ W1 @ Z.T @ y)
    u1    = (y - X @ beta1).reshape(-1)

    # Passo 2
    S     = (Z * u1[:, None]).T @ (Z * u1[:, None]) / n
    W2    = pinv(S)
    beta2 = pinv(X.T @ Z @ W2 @ Z.T @ X) @ (X.T @ Z @ W2 @ Z.T @ y)
    u2    = (y - X @ beta2).reshape(-1)

    Qxz  = X.T @ Z / n
    S2   = (Z * u2[:, None]).T @ (Z * u2[:, None]) / n
    A    = Qxz @ W2 @ Qxz.T
    vcov = pinv(A) @ Qxz @ W2 @ S2 @ W2 @ Qxz.T @ pinv(A) / n
    vcov = (n / (n - k)) * vcov
    se   = np.sqrt(np.diag(vcov))

    # Hansen J
    gbar = np.mean(Z * u2[:, None], axis=0).reshape(-1, 1)
    df_j = l - k
    J    = (n * gbar.T @ W2 @ gbar).item()
    p_j  = stats.chi2.sf(J, df_j) if df_j > 0 else np.nan

    return {"beta": beta2.reshape(-1), "vcov": vcov, "se": se, "resid": u2,
            "n": n, "k": k, "l": l,
            "hansen_J":  J    if df_j > 0 else np.nan,
            "hansen_p":  p_j,
            "hansen_df": df_j}


def mop_cv_tsls_lista1(model: str) -> dict:
    """
    Valores críticos TSLS do weakivtest/Stata para os modelos Z1-Z7.

    Observação:
    Estes valores vêm dos escalares r(c_TSLS_5), r(c_TSLS_10) e r(c_TSLS_20)
    reportados pelo weakivtest no log do Stata desta aplicação. Em Python puro,
    esta função não recalcula a distribuição tabulada de Montiel Olea-Pflueger;
    ela apenas registra os valores críticos usados na comparação do pacote.

    Se a amostra, a lista de instrumentos ou o desenho do exercício mudar,
    atualize esta tabela ou retorne np.nan.
    """
    cv_tab = {
        "Z1": {"cv5": 37.418, "cv10": 23.109, "cv20": 15.062},
        "Z2": {"cv5": 23.816, "cv10": 15.080, "cv20": 10.117},
        "Z3": {"cv5": 28.391, "cv10": 17.476, "cv20": 11.370},
        "Z4": {"cv5": 37.418, "cv10": 23.109, "cv20": 15.062},
        "Z5": {"cv5": 18.452, "cv10": 11.808, "cv20":  8.050},
        "Z6": {"cv5": 10.947, "cv10":  7.572, "cv20":  5.605},
        "Z7": {"cv5": 27.595, "cv10": 16.774, "cv20": 10.773},
    }
    return cv_tab.get(str(model).upper(), {"cv5": np.nan, "cv10": np.nan, "cv20": np.nan})


def ar_interval(data: pd.DataFrame, inst_vars, beta_grid=None, alpha: float = 0.05,
                expand_grid: bool = True, expand_by: float = 2.0,
                max_expand: int = 20, max_abs_beta: float = 100.0,
                min_tail_hits: int = 3, verbose: bool = True) -> dict:
    """
    Intervalo Anderson-Rubin por inversão de grade adaptativa.

    Correções aplicadas:
      - Expande automaticamente a grade quando o IC toca bmin/bmax.
      - Reconhece IC aberto à esquerda/direita após toques persistentes na
        mesma borda, evitando perseguir artificialmente -infinito/+infinito.
      - Quando nenhum beta0 é aceito, expande simetricamente até max_abs_beta;
        a grade final capada é efetivamente avaliada antes de declarar IC vazio.
      - beta0_minp é o beta0 com MAIOR p-valor AR, alinhado ao Stata.
      - Retorna p_min, p_max, limites reportados e limites observados na grade.
    """
    if beta_grid is None:
        beta_grid = np.arange(-5.0, 2.0001, 0.005)

    beta_grid = np.asarray(beta_grid, dtype=float)
    if beta_grid.size < 2:
        raise ValueError("ar_interval: beta_grid precisa ter pelo menos dois pontos.")

    inst_vars = list(inst_vars)
    keep = ["ln_q", "ln_pch", "ln_y", "ln_pb"] + inst_vars
    d = data[keep].dropna().copy()
    if d.empty:
        raise ValueError("ar_interval: nenhuma observação completa para as variáveis informadas.")

    grid_initial_min = float(np.nanmin(beta_grid))
    grid_initial_max = float(np.nanmax(beta_grid))
    step = float(abs(beta_grid[1] - beta_grid[0]))
    if step <= 0 or not np.isfinite(step):
        raise ValueError("ar_interval: passo da grade inválido.")

    def make_grid(bmin: float, bmax: float) -> np.ndarray:
        n_steps = int(np.floor((bmax - bmin) / step + 1e-9))
        bg = bmin + step * np.arange(n_steps + 1)
        if bg.size == 0:
            bg = np.array([bmin], dtype=float)
        if bg[-1] < bmax - step / 10:
            bg = np.append(bg, bmax)
        return bg.astype(float)

    def eval_grid(bg: np.ndarray) -> dict:
        accepted = np.zeros(bg.size, dtype=bool)
        pvals = np.full(bg.size, np.nan, dtype=float)
        X_ar = add_const(d[["ln_y", "ln_pb"] + inst_vars])
        x_cols = list(X_ar.columns)
        q = len(inst_vars)
        R = np.zeros((q, X_ar.shape[1]))
        for j, var in enumerate(inst_vars):
            R[j, x_cols.index(var)] = 1

        x_np = X_ar.to_numpy()
        ln_q = d["ln_q"].to_numpy()
        ln_pch = d["ln_pch"].to_numpy()

        for i, b0 in enumerate(bg):
            y_ar = ln_q - b0 * ln_pch
            fit = ols_hc1(y_ar, x_np)
            wt = wald_test(fit["beta"], fit["vcov"], R, df_denom=fit["df"])
            pvals[i] = wt["p"]
            accepted[i] = wt["p"] >= alpha

        grid_min = float(np.nanmin(bg))
        grid_max = float(np.nanmax(bg))
        p_min = float(np.nanmin(pvals)) if np.isfinite(pvals).any() else np.nan
        p_max = float(np.nanmax(pvals)) if np.isfinite(pvals).any() else np.nan

        if np.isfinite(p_max):
            beta0_minp = float(np.nanmean(bg[np.isclose(pvals, p_max, rtol=1e-12, atol=1e-14)]))
        else:
            beta0_minp = np.nan

        if not accepted.any():
            return {
                "accepted": accepted,
                "pvals": pvals,
                "low": np.nan,
                "high": np.nan,
                "beta0_minp": beta0_minp,
                "p_min": p_min,
                "p_max": p_max,
                "open_left": False,
                "open_right": False,
                "grid_min": grid_min,
                "grid_max": grid_max,
                "npoints_final": int(bg.size),
            }

        low = float(np.nanmin(bg[accepted]))
        high = float(np.nanmax(bg[accepted]))
        return {
            "accepted": accepted,
            "pvals": pvals,
            "low": low,
            "high": high,
            "beta0_minp": beta0_minp,
            "p_min": p_min,
            "p_max": p_max,
            "open_left": bool(low <= grid_min + step),
            "open_right": bool(high >= grid_max - step),
            "grid_min": grid_min,
            "grid_max": grid_max,
            "npoints_final": int(bg.size),
        }

    bmin = max(float(np.nanmin(beta_grid)), -float(max_abs_beta))
    bmax = min(float(np.nanmax(beta_grid)),  float(max_abs_beta))

    n_expand = 0
    left_hits = 0
    right_hits = 0
    declared_left = False
    declared_right = False

    while True:
        beta_grid_now = make_grid(bmin, bmax)
        res = eval_grid(beta_grid_now)

        if not res["accepted"].any():
            left_hits = 0
            right_hits = 0
            declared_left = False
            declared_right = False

            can_expand_left = expand_grid and (bmin > -max_abs_beta)
            can_expand_right = expand_grid and (bmax < max_abs_beta)
            can_expand_more = (can_expand_left or can_expand_right) and n_expand < max_expand

            if can_expand_more:
                old_bmin, old_bmax = bmin, bmax
                if can_expand_left:
                    bmin = max(-max_abs_beta, bmin - expand_by)
                if can_expand_right:
                    bmax = min(max_abs_beta, bmax + expand_by)

                if not (np.isclose(old_bmin, bmin) and np.isclose(old_bmax, bmax)):
                    n_expand += 1
                    if verbose:
                        print(
                            f"ar_interval [{'+'.join(inst_vars)}]: sem região aceita; "
                            f"ampliando grade para [{bmin:.4f}, {bmax:.4f}] "
                            f"(expansão {n_expand}/{max_expand})."
                        )
                    continue
            break

        if res["open_left"]:
            left_hits += 1
        else:
            left_hits = 0
        if res["open_right"]:
            right_hits += 1
        else:
            right_hits = 0

        if res["open_left"] and left_hits >= min_tail_hits:
            declared_left = True
        if res["open_right"] and right_hits >= min_tail_hits:
            declared_right = True

        need_left = res["open_left"] and not declared_left
        need_right = res["open_right"] and not declared_right

        can_expand_left = expand_grid and need_left and (bmin > -max_abs_beta)
        can_expand_right = expand_grid and need_right and (bmax < max_abs_beta)
        can_expand_more = (can_expand_left or can_expand_right) and n_expand < max_expand

        if can_expand_more:
            old_bmin, old_bmax = bmin, bmax
            if can_expand_left:
                bmin = max(-max_abs_beta, bmin - expand_by)
            if can_expand_right:
                bmax = min(max_abs_beta, bmax + expand_by)

            if not (np.isclose(old_bmin, bmin) and np.isclose(old_bmax, bmax)):
                n_expand += 1
                if verbose:
                    sides = []
                    if can_expand_left:
                        sides.append("esquerda")
                    if can_expand_right:
                        sides.append("direita")
                    print(
                        f"ar_interval [{'+'.join(inst_vars)}]: IC tocou borda ({' e '.join(sides)}); "
                        f"ampliando grade para [{bmin:.4f}, {bmax:.4f}] "
                        f"(expansão {n_expand}/{max_expand})."
                    )
                continue

        break

    has_accept = bool(res["accepted"].any())
    final_open_left = bool(
        has_accept and res["open_left"] and
        (declared_left or bmin <= -max_abs_beta or n_expand >= max_expand)
    )
    final_open_right = bool(
        has_accept and res["open_right"] and
        (declared_right or bmax >= max_abs_beta or n_expand >= max_expand)
    )

    ar_low_report = float(res["low"]) if has_accept and not final_open_left else np.nan
    ar_high_report = float(res["high"]) if has_accept and not final_open_right else np.nan

    if not has_accept:
        warnings.warn(
            f"ar_interval [{'+'.join(inst_vars)}]: nenhum beta0 aceito após {n_expand} expansão(ões). "
            f"O IC AR foi tratado como vazio na grade final [{res['grid_min']:.4f}, {res['grid_max']:.4f}]."
        )
    else:
        if final_open_left:
            warnings.warn(
                f"ar_interval [{'+'.join(inst_vars)}]: IC AR tratado como aberto à esquerda; "
                f"menor beta aceito na grade final = {res['low']:.4f}."
            )
        if final_open_right:
            warnings.warn(
                f"ar_interval [{'+'.join(inst_vars)}]: IC AR tratado como aberto à direita; "
                f"maior beta aceito na grade final = {res['high']:.4f}."
            )

    return {
        "ar_low": ar_low_report,
        "ar_high": ar_high_report,
        "ar_low_grid": float(res["low"]) if np.isfinite(res["low"]) else np.nan,
        "ar_high_grid": float(res["high"]) if np.isfinite(res["high"]) else np.nan,
        "beta0_minp": float(res["beta0_minp"]) if np.isfinite(res["beta0_minp"]) else np.nan,
        "p_min": float(res["p_min"]) if np.isfinite(res["p_min"]) else np.nan,
        "p_max": float(res["p_max"]) if np.isfinite(res["p_max"]) else np.nan,
        "grid_initial_min": grid_initial_min,
        "grid_initial_max": grid_initial_max,
        "grid_min": float(res["grid_min"]),
        "grid_max": float(res["grid_max"]),
        "grid_step": step,
        "n_expand": int(n_expand),
        "npoints_final": int(res["npoints_final"]),
        "max_abs_beta": float(max_abs_beta),
        "min_tail_hits": int(min_tail_hits),
        "tail_hits_left": int(left_hits),
        "tail_hits_right": int(right_hits),
        "open_left": bool(final_open_left),
        "open_right": bool(final_open_right),
        "empty_interval": bool(not has_accept),
    }
