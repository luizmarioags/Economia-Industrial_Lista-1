"""
Estimações da Lista 1 em Python.
CORREÇÕES APLICADAS:
  - Q1 : p-valor de beta_p, beta_y e beta_b adicionados; todas as elasticidades salvas
  - Q3 : p-valor de beta_p adicionado
  - Q4 : p-valor individual de pi_z adicionado;
          verificação numérica |2SLS - GMM| impressa no log
  - Q5 : p-valor de beta_p adicionado para GMM_Z1 e GMM_Z2
  - Q9 : pval_p e p_F agora presentes na tabela comparativa
  - Q9 : F_eff calculado na mão via mop_f_eff() — sem dependência do Stata
  - Q9 : cv5/cv10/cv20 preenchidos com valores críticos TSLS do weakivtest/Stata
  - Q11: grade AR adaptativa com IC aberto/vazio, p_max e limites observados na grade
"""
import warnings
import numpy as np
import pandas as pd
from scipy import stats

from config import PROC, TABS, log_step
from econometrics import (
    add_const, ols_hc1, iv_2sls, iv_gmm_2step,
    wald_test, partial_r2, ar_interval, mop_f_eff, mop_cv_tsls_lista1,
)

INSTRUMENTS = {
    "Z1": ["z"],
    "Z2": ["z", "z_sq"],
    "Z3": ["z", "z_sq", "z_cu"],
    "Z4": ["z_lag"],
    "Z5": ["z_lag", "z_lag_sq"],
    "Z6": ["z", "z_lag"],
    "Z7": ["z", "z_sq", "z_lag", "z_lag_sq"],
}


def run_estimations() -> None:
    log_step("Estimações em Python: iniciando")
    df = pd.read_csv(PROC / "chicken_prepared_python.csv")

    # ==================================================================
    # Questão 1: MQO com erro-padrão robusto HC1
    # CORREÇÃO: p-valor de beta_p, beta_y e beta_b; todas as elasticidades salvas
    # ==================================================================
    log_step("Questão 1: estimando MQO robusto (HC1)")
    log_step("Modelo: ln_q = beta0 + beta_p*ln_pch + beta_y*ln_y + beta_b*ln_pb + u")

    d_ols = df[["ln_q", "ln_pch", "ln_y", "ln_pb"]].dropna()
    y_ols = d_ols["ln_q"].to_numpy()
    X_ols = add_const(d_ols[["ln_pch", "ln_y", "ln_pb"]])
    ols   = ols_hc1(y_ols, X_ols.to_numpy())
    cv_t  = stats.t.ppf(0.975, ols["df"])   # valor crítico t

    # CORREÇÃO: extrai todas as elasticidades com p-valores
    ols_rows = []
    for v in ["ln_pch", "ln_y", "ln_pb"]:
        idx  = list(X_ols.columns).index(v)
        b_v  = ols["beta"][idx]
        se_v = ols["se"][idx]
        pval = 2 * stats.t.sf(abs(b_v / se_v), ols["df"])
        log_step(f"  {v}: b={b_v:.6f} | SE={se_v:.6f} | p={pval:.6f} | "
                 f"IC=[{b_v - cv_t*se_v:.6f}, {b_v + cv_t*se_v:.6f}]")
        ols_rows.append({
            "var": v, "N": ols["n"],
            "b": b_v, "se": se_v, "pval": pval,
            "ci_low": b_v - cv_t * se_v,
            "ci_high": b_v + cv_t * se_v,
        })
    pd.DataFrame(ols_rows).to_csv(TABS / "python_question_01_ols.csv", index=False)
    log_step("Tabela salva: output/tables/python_question_01_ols.csv")

    # Salva resíduos e ajustados
    df["ols_resid"]  = np.nan
    df["ols_fitted"] = np.nan
    df.loc[d_ols.index, "ols_resid"]  = ols["resid"]
    df.loc[d_ols.index, "ols_fitted"] = ols["fitted"]
    df.to_csv(PROC / "chicken_with_ols_residuals_python.csv", index=False)

    # ==================================================================
    # Questão 3: 2SLS com Z1 = {z}
    # CORREÇÃO: p-valor de beta_p adicionado
    # ==================================================================
    log_step("Questão 3: estimando 2SLS com Z1 = {z}")
    log_step("Equação estrutural: ln_q ~ ln_pch + ln_y + ln_pb | Endógena: ln_pch | Excluído: z")

    d_iv  = df[["ln_q", "ln_pch", "ln_y", "ln_pb", "z"]].dropna()
    y_iv  = d_iv["ln_q"].to_numpy()
    X_iv  = add_const(d_iv[["ln_pch", "ln_y", "ln_pb"]])
    Z_iv  = add_const(d_iv[["ln_y", "ln_pb", "z"]])
    iv_z1 = iv_2sls(y_iv, X_iv.to_numpy(), Z_iv.to_numpy())

    idx_p  = list(X_iv.columns).index("ln_pch")
    b_p    = iv_z1["beta"][idx_p]
    se_p   = iv_z1["se"][idx_p]
    # CORREÇÃO: p-valor via normal assintótica (aproximação padrão do 2SLS)
    pval_p = 2 * stats.norm.sf(abs(b_p / se_p))
    cv_n   = stats.norm.ppf(0.975)

    log_step(f"  2SLS Z1: beta_p={b_p:.6f} | SE={se_p:.6f} | p={pval_p:.6f} | "
             f"IC=[{b_p - cv_n*se_p:.6f}, {b_p + cv_n*se_p:.6f}]")

    pd.DataFrame([{
        "method": "2SLS_Z1", "N": iv_z1["n"],
        "beta_p": b_p, "se_p": se_p, "pval_p": pval_p,
        "ci_low": b_p - cv_n * se_p, "ci_high": b_p + cv_n * se_p,
    }]).to_csv(TABS / "python_question_03_iv_z1.csv", index=False)
    log_step("Tabela salva: output/tables/python_question_03_iv_z1.csv")

    # ==================================================================
    # Questão 4: Primeiro estágio para Z1
    # CORREÇÃO: p-valor individual de pi_z;
    #           verificação numérica |2SLS - GMM| impressa no log
    # ==================================================================
    log_step("Questão 4: estimando primeiro estágio de Z1")
    log_step("Modelo: ln_pch = pi0 + pi_z*z + pi_y*ln_y + pi_b*ln_pb + v")

    X_fs   = add_const(d_iv[["z", "ln_y", "ln_pb"]])
    fs_fit = ols_hc1(d_iv["ln_pch"].to_numpy(), X_fs.to_numpy())
    idx_z  = list(X_fs.columns).index("z")
    pi_z   = fs_fit["beta"][idx_z]
    se_z   = fs_fit["se"][idx_z]
    # CORREÇÃO: p-valor individual de pi_z
    p_z    = 2 * stats.t.sf(abs(pi_z / se_z), fs_fit["df"])

    R_z = np.zeros((1, X_fs.shape[1])); R_z[0, idx_z] = 1
    wt  = wald_test(fs_fit["beta"], fs_fit["vcov"], R_z, df_denom=fs_fit["df"])
    pr2 = partial_r2(
        d_iv["ln_pch"].to_numpy(),
        add_const(d_iv[["ln_y", "ln_pb"]]).to_numpy(),
        d_iv[["z"]].to_numpy(),
    )

    log_step(f"  pi_z={pi_z:.6f} | SE={se_z:.6f} | p(t)={p_z:.6f} | "
             f"F_usual={wt['F']:.4f} | p(F)={wt['p']:.6f} | R2 parcial={pr2:.6f}")

    # CORREÇÃO: verificação numérica equivalência 2SLS == GMM
    gmm_check = iv_gmm_2step(y_iv, X_iv.to_numpy(), Z_iv.to_numpy())
    diff_check = abs(iv_z1["beta"][idx_p] - gmm_check["beta"][idx_p])
    log_step(f"  Verificação Q4 — |2SLS - GMM| = {diff_check:.2e} (deve ser ~0 no caso exato)")

    pd.DataFrame([{
        "model": "Z1_first_stage", "N": fs_fit["n"],
        "pi_z": pi_z, "se_z": se_z, "pval_z": p_z,
        "partial_R2": pr2, "F_usual": wt["F"], "p_F": wt["p"],
    }]).to_csv(TABS / "python_question_04_first_stage.csv", index=False)
    log_step("Tabela salva: output/tables/python_question_04_first_stage.csv")

    # ==================================================================
    # Questão 5: GMM em dois passos para Z1 e Z2
    # CORREÇÃO: p-valor de beta_p adicionado
    # ==================================================================
    log_step("Questão 5: estimando GMM em dois passos para Z1 e Z2")

    gmm_rows = []
    for model in ["Z1", "Z2"]:
        inst = INSTRUMENTS[model]
        d    = df[["ln_q", "ln_pch", "ln_y", "ln_pb"] + inst].dropna()
        y    = d["ln_q"].to_numpy()
        X    = add_const(d[["ln_pch", "ln_y", "ln_pb"]])
        Z    = add_const(d[["ln_y", "ln_pb"] + inst])
        fit  = iv_gmm_2step(y, X.to_numpy(), Z.to_numpy())

        idx  = list(X.columns).index("ln_pch")
        b_v  = fit["beta"][idx]
        se_v = fit["se"][idx]
        # CORREÇÃO: p-valor assintótico normal
        pval = 2 * stats.norm.sf(abs(b_v / se_v))

        J_val = fit["hansen_J"]
        Jp    = fit["hansen_p"]
        log_step(f"  GMM_{model}: beta_p={b_v:.6f} | SE={se_v:.6f} | p={pval:.6f} | "
                 f"J={J_val} | p(J)={Jp} | gl={fit['hansen_df']}")

        gmm_rows.append({
            "model": f"GMM_{model}", "N": fit["n"],
            "beta_p": b_v, "se_p": se_v, "pval_p": pval,
            "ci_low":  b_v - 1.96 * se_v,
            "ci_high": b_v + 1.96 * se_v,
            "hansen_J":  J_val, "hansen_p": Jp, "hansen_df": fit["hansen_df"],
        })
    pd.DataFrame(gmm_rows).to_csv(TABS / "python_question_05_gmm.csv", index=False)
    log_step("Tabela salva: output/tables/python_question_05_gmm.csv")

    # ==================================================================
    # Questões 8, 9 e 10: Z1-Z7, 2SLS, MOP na mão e Hansen J
    # CORREÇÕES:
    #   - pval_p adicionado
    #   - p_F transferido diretamente à tabela comparativa
    #   - F_eff calculado via mop_f_eff() — sem Stata
    # ==================================================================
    log_step("Questões 8, 9 e 10: tabela comparativa Z1-Z7 com MOP na mão")

    fs_rows   = []
    comp_rows = []

    for model, inst in INSTRUMENTS.items():
        vars_needed = ["ln_q", "ln_pch", "ln_y", "ln_pb"] + inst
        d = df[vars_needed].dropna()

        log_step(f"  Processando {model} (instrumentos: {', '.join(inst)})")

        # --- Primeiro estágio ---
        Xfs  = add_const(d[inst + ["ln_y", "ln_pb"]])
        fsfit = ols_hc1(d["ln_pch"].to_numpy(), Xfs.to_numpy())
        R    = np.zeros((len(inst), Xfs.shape[1]))
        for j, var in enumerate(inst):
            R[j, list(Xfs.columns).index(var)] = 1
        wtf  = wald_test(fsfit["beta"], fsfit["vcov"], R, df_denom=fsfit["df"])
        pr2  = partial_r2(
            d["ln_pch"].to_numpy(),
            add_const(d[["ln_y", "ln_pb"]]).to_numpy(),
            d[inst].to_numpy(),
        )
        fs_rows.append({
            "model": model, "N": fsfit["n"], "k_inst": len(inst),
            "partial_R2": pr2, "F_usual": wtf["F"], "p_F": wtf["p"],
        })

        # --- 2SLS estrutural ---
        y     = d["ln_q"].to_numpy()
        X     = add_const(d[["ln_pch", "ln_y", "ln_pb"]])
        Z     = add_const(d[["ln_y", "ln_pb"] + inst])
        ivfit = iv_2sls(y, X.to_numpy(), Z.to_numpy())
        gmmfit = iv_gmm_2step(y, X.to_numpy(), Z.to_numpy())

        idx  = list(X.columns).index("ln_pch")
        b_v  = ivfit["beta"][idx]
        se_v = ivfit["se"][idx]
        # CORREÇÃO: p-valor de beta_p
        pval_p = 2 * stats.norm.sf(abs(b_v / se_v))

        # --- F efetivo MOP na mão ---
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            f_eff = mop_f_eff(
                d["ln_pch"].to_numpy(),
                d[inst].to_numpy(),
                add_const(d[["ln_y", "ln_pb"]]).to_numpy(),
            )
        for w in caught:
            log_step(f"  [AVISO mop_f_eff {model}]: {w.message}")

        cv_mop = mop_cv_tsls_lista1(model)

        log_step(f"    beta_p={b_v:.6f} | SE={se_v:.6f} | p={pval_p:.6f} | "
                 f"F_usual={wtf['F']:.4f} | p_F={wtf['p']:.6f} | "
                 f"F_eff(MOP)={f_eff} | cv5={cv_mop['cv5']} | "
                 f"cv10={cv_mop['cv10']} | cv20={cv_mop['cv20']} | "
                 f"J={gmmfit['hansen_J']} | p(J)={gmmfit['hansen_p']}")

        comp_rows.append({
            "model":    model,
            "N":        ivfit["n"],
            "k_inst":   len(inst),
            "beta_p":   b_v,
            "se_p":     se_v,
            "pval_p":   pval_p,
            "ci_low":   b_v - 1.96 * se_v,
            "ci_high":  b_v + 1.96 * se_v,
            "F_usual":  wtf["F"],
            "p_F":      wtf["p"],
            "F_eff":    f_eff,
            "cv5":      cv_mop["cv5"],
            "cv10":     cv_mop["cv10"],
            "cv20":     cv_mop["cv20"],
            "hansen_J": gmmfit["hansen_J"],
            "hansen_p": gmmfit["hansen_p"],
        })

    pd.DataFrame(fs_rows).to_csv(TABS / "python_question_08_first_stage_all.csv", index=False)
    pd.DataFrame(comp_rows).to_csv(TABS / "python_question_09_comparative.csv", index=False)
    log_step("Tabelas salvas: python_question_08_first_stage_all.csv e python_question_09_comparative.csv")

    # ==================================================================
    # Questão 11: intervalos Anderson-Rubin por grade adaptativa
    # CORREÇÃO: IC aberto/vazio, beta0_minp como maior p-valor, p_max,
    #           limites reportados e limites observados na grade
    # ==================================================================
    log_step("Questão 11: calculando intervalos Anderson-Rubin para Z1, Z2 e Z7 com grade adaptativa")

    ar_rows = []
    for model in ["Z1", "Z2", "Z7"]:
        inst = INSTRUMENTS[model]
        log_step(f"  AR {model} (instrumentos: {', '.join(inst)})")

        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            ar = ar_interval(
                df,
                inst_vars=inst,
                beta_grid=np.arange(-5.0, 2.0001, 0.005),
                expand_grid=True,
                expand_by=2.0,
                max_expand=20,
                max_abs_beta=100.0,
                min_tail_hits=3,
            )
        for w in caught:
            log_step(f"  [AVISO ar_interval {model}]: {w.message}")

        log_step(f"    IC AR reportado = [{ar['ar_low']:.4f}, {ar['ar_high']:.4f}] | "
                 f"IC na grade = [{ar['ar_low_grid']:.4f}, {ar['ar_high_grid']:.4f}] | "
                 f"beta0 menos rejeitado={ar['beta0_minp']:.4f} | "
                 f"p_max={ar['p_max']:.6f} | p_min={ar['p_min']:.6f} | "
                 f"grade_final=[{ar['grid_min']:.4f}, {ar['grid_max']:.4f}] | "
                 f"expansoes={ar['n_expand']} | vazio={ar['empty_interval']} | "
                 f"aberto_esq={ar['open_left']} | aberto_dir={ar['open_right']}")

        ar_rows.append({"model": model, "k_inst": len(inst), **ar})

    pd.DataFrame(ar_rows).to_csv(TABS / "python_question_11_ar_intervals.csv", index=False)
    log_step("Tabela salva: output/tables/python_question_11_ar_intervals.csv")

    log_step("Estimações em Python: concluídas")


if __name__ == "__main__":
    run_estimations()
