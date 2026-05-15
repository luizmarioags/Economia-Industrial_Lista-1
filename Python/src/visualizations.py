"""Gera gráficos auxiliares da Lista 1."""
import pandas as pd
import matplotlib.pyplot as plt
from config import PROC, TABS, FIGS, log_step

def run_visualizations() -> None:
    log_step("Visualizações em Python: iniciando")
    df = pd.read_csv(PROC / "chicken_with_ols_residuals_python.csv")

    plt.figure(figsize=(10, 6))
    for col in ["ln_q", "ln_pch", "ln_y", "ln_pb", "z"]:
        plt.plot(df["year"], df[col], label=col)
    plt.title("Séries logarítmicas principais")
    plt.legend()
    plt.savefig(FIGS / "python_fig01_series.png", dpi=300)
    plt.close()

    plt.figure(figsize=(8, 6))
    plt.scatter(df["ln_pch"], df["ln_q"])
    plt.title("Demanda observada: ln_q versus ln_pch")
    plt.savefig(FIGS / "python_fig02_scatter_demand.png", dpi=300)
    plt.close()

    plt.figure(figsize=(8, 6))
    plt.scatter(df["ols_fitted"], df["ols_resid"])
    plt.axhline(0)
    plt.title("Resíduos MQO versus valores ajustados")
    plt.savefig(FIGS / "python_fig03_residuals_fitted.png", dpi=300)
    plt.close()

    comp = pd.read_csv(TABS / "python_question_09_comparative.csv")
    yerr_low = comp["beta_p"] - comp["ci_low"]
    yerr_high = comp["ci_high"] - comp["beta_p"]
    plt.figure(figsize=(9, 6))
    plt.errorbar(comp["model"], comp["beta_p"], yerr=[yerr_low, yerr_high], fmt="o", capsize=4)
    plt.axhline(0)
    plt.title("Elasticidade-preço por especificação IV")
    plt.savefig(FIGS / "python_fig04_beta_p_by_instrument.png", dpi=300)
    plt.close()

if __name__ == "__main__":
    run_visualizations()
