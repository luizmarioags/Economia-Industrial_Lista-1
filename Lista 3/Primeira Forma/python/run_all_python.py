# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Orquestra toda a replicação Python: dados, estimações, tabelas, elasticidades, markups, diagnósticos e gráficos.
# Antes de executar, limpa tabelas antigas da pasta Python para deixar apenas o conjunto padronizado.

"""
Run all - Python.
Implementa MQO, 2SLS e GMM por álgebra matricial/otimização fechada do critério linear.
Não usa bibliotecas prontas de IV/GMM. Usa apenas numpy/scipy para álgebra/estatística básica.
"""
import sys
import os
from pathlib import Path
import numpy as np
import pandas as pd

THIS = Path(__file__).resolve().parent
sys.path.insert(0, str(THIS))

from config import LOG_DIR, TAB_CSV, TAB_TEX, OUT_DATA, FIG_PDF, FIG_PNG
from prepare_data import load_and_prepare
from estimators import (
    ols, two_sls, efficient_gmm, first_stage_diagnostics,
    build_designs, add_const
)
from economics import simple_logit_elasticity_matrix, nested_logit_numerical_elasticities, markups
from tables import save_table, matrix_to_long
from visualizations import plot_core, plot_extra, plot_logit_model_diagnostics


def cleanup_tables():
    # Limpa tabelas e gráficos antigos da pasta Python para evitar arquivos obsoletos
    # depois de mudanças de nomenclatura ou atualização das visualizações.
    for folder, pattern in [(TAB_CSV, "*.csv"), (TAB_TEX, "*.tex"),
                            (FIG_PNG, "*.png"), (FIG_PDF, "*.pdf")]:
        for f in folder.glob(pattern):
            try:
                f.unlink()
            except FileNotFoundError:
                pass


def print_start_banner():
    print("#########################################################################")
    print("#                            INÍCIO                                     #")
    print("#             Lista 3 - Modelo BLP.                                    #")
    print("#             Grupo: Luiz Mario Andrade (Matrícula: 252029360)          #")
    print("#                    Felipe Santos (Matrícula: 232010719)               #")
    print("#                    Luiza Nodari (Matrícula: 242011335)                #")
    print("#                    Diogo Martins (Matrícula: 232001578)               #")
    print("#                    Sarah Moura (Matrícula: 211060316)                 #")
    print("#                    Pedro Bijos (Matrícula: 241003849)                 #")
    print("#########################################################################")


def print_end_banner():
    print("#########################################################################")
    print("#                            FIM                                        #")
    print("#                                                                       #")
    print("#########################################################################")


def main():
    cleanup_tables()
    print_start_banner()

    print("[python] Preparando dados...", flush=True)
    df = load_and_prepare()
    D = build_designs(df)
    y = D["y"]
    X = D["X_logit"]
    names = D["names_logit"]

    print("[python] Estimando MQO, 2SLS e GMM...", flush=True)
    results = []
    results.append(ols(y, X, names, "Q1_MQO_logit_simples"))
    results.append(two_sls(y, X, D["Z_own"], names, "Q2_2SLS_own_firm"))
    results.append(two_sls(y, X, D["Z_rival"], names, "Q2_2SLS_rival_firms"))
    results.append(two_sls(y, X, D["Z_both"], names, "Q2_2SLS_both"))

    for label, Z in [("own_firm", D["Z_own"]), ("rival_firms", D["Z_rival"]), ("both", D["Z_both"] )]:
        step1, step2 = efficient_gmm(y, X, Z, names, f"Q3_GMM_{label}_2step")
        step1.name = f"Q3_GMM_{label}_step1"
        results.append(step1)
        results.append(step2)

    Xn = D["X_nested"]
    names_n = D["names_nested"]
    nested_iv = two_sls(y, Xn, D["Z_nested"], names_n, "Q4_2SLS_nested_reference")
    step1_n, step2_n = efficient_gmm(y, Xn, D["Z_nested"], names_n, "Q4_nested_GMM_2step")
    step1_n.name = "Q4_nested_GMM_step1"
    results.extend([nested_iv, step1_n, step2_n])

    print("[python] Salvando tabelas padronizadas...", flush=True)
    coef_all = pd.concat([r.to_frame() for r in results], ignore_index=True)
    save_table(coef_all, "01_all_coefficients", "Coeficientes estimados", "tab:all-coef")

    comp_rows = []
    for r in results:
        if "price" in r.coef_names:
            ix = r.coef_names.index("price")
            comp_rows.append({
                "model": r.name,
                "price_coef": r.coef[ix],
                "alpha": -r.coef[ix],
                "std_error_price": r.se[ix],
                "gmm_objective": r.objective,
                "sigma_nested": r.sigma,
            })
    comp = pd.DataFrame(comp_rows)
    save_table(comp, "02_price_parameter_comparison", "Comparação do parâmetro de preço", "tab:price-compare")

    main_gmm = [r for r in results if r.name == "Q3_GMM_both_2step"][0]
    alpha = main_gmm.alpha
    print("[python] Calculando elasticidades e markups...", flush=True)
    E = simple_logit_elasticity_matrix(df, alpha)
    save_table(matrix_to_long(E), "03_elasticity_matrix_simple_logit", "Matriz de elasticidades - logit simples", "tab:elas-simple")

    top_products = df.sort_values("share", ascending=False)["product"].head(12).tolist()
    E_subset = E.loc[top_products, top_products]
    save_table(matrix_to_long(E_subset), "04_elasticity_matrix_simple_logit_subset", "Matriz de elasticidades - logit simples - subconjunto", "tab:elas-simple-subset")

    own = pd.DataFrame({
        "product": df["product"],
        "firm": df["firm"],
        "segment": df["segment"],
        "price": df["price"],
        "share": df["share"],
        "own_elasticity_simple_logit": np.diag(E.values),
    }).sort_values("share", ascending=False)
    save_table(own, "05_own_elasticities_simple_logit", "Elasticidades próprias - logit simples", "tab:own-elas-simple")

    En = nested_logit_numerical_elasticities(df, step2_n.coef, step2_n.coef_names)
    if En is None:
        nested_long = pd.DataFrame(columns=["row_product", "column_product", "elasticity"])
        nested_own = pd.DataFrame(columns=["product", "own_elasticity_nested_logit"])
    else:
        nested_long = matrix_to_long(En)
        nested_own = pd.DataFrame({
            "product": df["product"],
            "own_elasticity_nested_logit": np.diag(En.values),
        }).sort_values("own_elasticity_nested_logit")
    save_table(nested_long, "06_elasticity_matrix_nested_logit", "Matriz de elasticidades - nested logit", "tab:elas-nested")
    save_table(nested_own, "07_own_elasticities_nested_logit", "Elasticidades próprias - nested logit", "tab:own-elas-nested")

    markup_df = markups(df, alpha)
    save_table(markup_df, "08_markups", "Markups implícitos - logit simples", "tab:markups")

    print("[python] Calculando diagnósticos de primeiro estágio...", flush=True)
    diag_simple = first_stage_diagnostics(df, ["price"], D["exog"], D["both_instr"])
    diag_nested = first_stage_diagnostics(df, ["price", "log_share_within_nest"], D["exog"], D["nested_instr"])
    diag = pd.concat([diag_simple.assign(specification="simple_logit_both"),
                      diag_nested.assign(specification="nested_logit")], ignore_index=True)
    save_table(diag, "09_first_stage_diagnostics", "Diagnóstico de primeiro estágio", "tab:first-stage")

    from estimators import ols as ols_fun
    first_stage_design = add_const(df[D["exog"] + D["both_instr"]].to_numpy())
    fs = ols_fun(df["price"].to_numpy(), first_stage_design,
                 ["const"] + D["exog"] + D["both_instr"], "first_stage_price")

    print("[python] Gerando gráficos principais...", flush=True)
    plot_core(df, comp, E, markup_df, diag)
    print("[python] Gerando visualizações extras...", flush=True)
    plot_extra(df, first_stage_fitted=fs.fitted, residuals=main_gmm.resid, instruments=D["nested_instr"])

    print("[python] Gerando gráficos clássicos e diagnósticos do logit...", flush=True)
    plot_logit_model_diagnostics(df, main_gmm, residuals=main_gmm.resid)

    summary = []
    summary.append("Pacote de replicação - Python\n")
    summary.append(f"N produtos internos: {len(df)}")
    summary.append(f"Soma dos shares internos: {df['share'].sum():.4f}; s0 usado: {df['outside_share'].iloc[0]:.4f}")
    summary.append(f"Especificação principal: Q3_GMM_both_2step; alpha = {alpha:.6f}")
    summary.append(f"Nested logit: sigma = {step2_n.sigma:.6f}; intervalo teórico 0 <= sigma < 1")
    summary.append("\nArquivos principais em outputs/python/tables, outputs/python/figures e outputs/python/logs.")
    (OUT_DATA / "summary_python.txt").write_text("\n".join(summary), encoding="utf-8")
    print("\n".join(summary))

    print_end_banner()


class Tee:
    def __init__(self, *streams):
        self.streams = streams
    def write(self, data):
        for s in self.streams:
            s.write(data)
            s.flush()
    def flush(self):
        for s in self.streams:
            s.flush()

if __name__ == "__main__":
    log_file = LOG_DIR / "run_all_python.log"
    with open(log_file, "w", encoding="utf-8") as f:
        original_stdout, original_stderr = sys.stdout, sys.stderr
        sys.stdout = Tee(original_stdout, f)
        sys.stderr = Tee(original_stderr, f)
        try:
            main()
        finally:
            sys.stdout = original_stdout
            sys.stderr = original_stderr
    print(f"Python concluído. Log: {log_file}", flush=True)
    os._exit(0)
