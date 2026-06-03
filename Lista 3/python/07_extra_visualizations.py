# -*- coding: utf-8 -*-
# COMENTÁRIOS DETALHADOS
# Script independente para gerar apenas as visualizações extras em Python.
# Recarrega a base, reestima o GMM principal e passa resíduos/fitted para plot_extra.

"""Gera visualizações extras para aprimorar a análise da Lista Berry/BLP."""
import sys
from pathlib import Path
THIS = Path(__file__).resolve().parent
sys.path.insert(0, str(THIS))

from prepare_data import load_and_prepare
from estimators import build_designs, efficient_gmm, ols, add_const
from visualizations import plot_extra


def main():
    df = load_and_prepare()
    D = build_designs(df)
    _, gmm_both = efficient_gmm(D["y"], D["X_logit"], D["Z_both"], D["names_logit"], "extra_GMM_both")
    fs_design = add_const(df[D["exog"] + D["both_instr"]].to_numpy())
    fs = ols(df["price"].to_numpy(), fs_design, ["const"] + D["exog"] + D["both_instr"], "extra_first_stage_price")
    plot_extra(df, first_stage_fitted=fs.fitted, residuals=gmm_both.resid, instruments=D["nested_instr"])
    print("Visualizações extras concluídas.")


if __name__ == "__main__":
    main()
