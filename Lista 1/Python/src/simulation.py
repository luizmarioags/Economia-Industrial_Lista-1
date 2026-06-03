"""
Questão 14: simulação de instrumentos fracos.
CORREÇÕES APLICADAS:
  - F médio do primeiro estágio calculado por nível de pi e salvo na tabela
  - Estimador MQO de referência rodado em cada replicação (b_ols)
  - Tabela final: pi, b_iv, b_ols, bias_iv, sd_iv, f_fs, cov_iv
  - Gráficos adicionais: convergência IV->OLS e F médio do 1º estágio por pi
"""
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

from config import TABS, FIGS, log_step
from econometrics import add_const, iv_2sls, ols_hc1, wald_test


def simulate_strength(pi_strength: float, reps: int = 250,
                      n: int = 200, beta_true: float = -1.0) -> dict:
    """Roda `reps` replicações para um dado nível de força pi_strength."""
    estimates_iv  = []
    estimates_ols = []
    f_stats       = []
    covered       = []

    for _ in range(reps):
        # DGP
        z  = np.random.normal(size=n)
        e1 = np.random.normal(size=n)
        e2 = np.random.normal(size=n)
        v  = 0.6 * e1 + np.sqrt(1 - 0.6 ** 2) * e2
        x  = pi_strength * z + v
        y  = beta_true * x + e1   # u = e1

        X = add_const(pd.DataFrame({"x": x}))
        Z = add_const(pd.DataFrame({"z": z}))

        # CORREÇÃO: MQO de referência
        fit_ols = ols_hc1(y, X.to_numpy())
        estimates_ols.append(fit_ols["beta"][1])

        # CORREÇÃO: F do primeiro estágio em cada replicação
        fit_fs = ols_hc1(x, Z.to_numpy())
        wt_fs  = wald_test(fit_fs["beta"], fit_fs["vcov"],
                           np.array([[0, 1]]), df_denom=fit_fs["df"])
        f_stats.append(wt_fs["F"])

        # IV
        fit = iv_2sls(y, X.to_numpy(), Z.to_numpy())
        b   = fit["beta"][1]
        se  = fit["se"][1]
        estimates_iv.append(b)
        covered.append((b - 1.96 * se) <= beta_true <= (b + 1.96 * se))

    estimates_iv  = np.asarray(estimates_iv)
    estimates_ols = np.asarray(estimates_ols)
    f_stats       = np.asarray(f_stats)

    return {
        "pi":    pi_strength,
        "b_iv":  estimates_iv.mean(),
        "b_ols": estimates_ols.mean(),        # CORREÇÃO: OLS médio de referência
        "bias_iv": estimates_iv.mean() - beta_true,
        "sd_iv": estimates_iv.std(ddof=1),
        "f_fs":  f_stats.mean(),              # CORREÇÃO: F médio do 1º estágio
        "cov_iv": np.mean(covered),
    }


def run_simulation() -> None:
    log_step("Questão 14 em Python: simulação de instrumentos fracos")
    np.random.seed(26052026)

    # Seis níveis de pi (mesmos do Stata)
    pi_values = [1, 0.5, 0.25, 0.10, 0.05, 0.02]
    rows = []
    for pi in pi_values:
        log_step(f"  Simulando pi={pi}")
        result = simulate_strength(pi)
        log_step(f"    IV={result['b_iv']:.4f} | OLS={result['b_ols']:.4f} | "
                 f"viés={result['bias_iv']:.4f} | sd={result['sd_iv']:.4f} | "
                 f"F_fs={result['f_fs']:.2f} | cobertura={result['cov_iv']:.4f}")
        rows.append(result)

    sim = pd.DataFrame(rows)
    sim.to_csv(TABS / "python_question_14_simulation.csv", index=False)
    log_step("Tabela salva: output/tables/python_question_14_simulation.csv")

    # -------------------------------------------------------------------
    # Gráficos
    # -------------------------------------------------------------------

    # Gráfico 1: dispersão do estimador IV por pi.
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(sim["pi"], sim["sd_iv"], "o-", color="navy")
    ax.set_title("Simulação: dispersão do IV quando o instrumento enfraquece")
    ax.set_xlabel("Força do instrumento (pi)")
    ax.set_ylabel("Desvio-padrão do estimador IV")
    fig.tight_layout()
    fig.savefig(FIGS / "python_fig06_simulation_sd.png", dpi=300)
    plt.close(fig)
    log_step("Gráfico salvo: output/figures/python_fig06_simulation_sd.png")

    # CORREÇÃO: Gráfico 2 — convergência IV -> OLS quando pi -> 0.
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(sim["pi"], sim["b_iv"],  "o-", color="navy",    label="IV médio")
    ax.plot(sim["pi"], sim["b_ols"], "s--", color="firebrick", label="OLS médio")
    ax.axhline(-1, linestyle=":", color="gray", label="Valor verdadeiro (beta = -1)")
    ax.set_title("IV converge para OLS quando instrumento enfraquece")
    ax.set_xlabel("Força do instrumento (pi)")
    ax.set_ylabel("Estimativa média de beta")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "python_fig07_simulation_bias_convergence.png", dpi=300)
    plt.close(fig)
    log_step("Gráfico salvo: output/figures/python_fig07_simulation_bias_convergence.png")

    # CORREÇÃO: Gráfico 3 — F médio do primeiro estágio por pi.
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.plot(sim["pi"], sim["f_fs"], "o-", color="darkgreen")
    ax.axhline(10, linestyle="--", color="red", label="Limiar convencional F = 10")
    ax.set_title("F médio do primeiro estágio por nível de pi")
    ax.set_xlabel("Força do instrumento (pi)")
    ax.set_ylabel("F médio (primeiro estágio)")
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIGS / "python_fig08_simulation_ffs.png", dpi=300)
    plt.close(fig)
    log_step("Gráfico salvo: output/figures/python_fig08_simulation_ffs.png")


if __name__ == "__main__":
    run_simulation()
