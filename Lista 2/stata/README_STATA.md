# Ordem sugerida no Stata

Rode a partir da raiz do pacote:

```stata
do stata/run_all_aids_stata.do
```

A ordem interna é:

1. `00_config_aids.do`
2. `01_prepare_aids_data.do`
3. `02_estimate_aids_stata.do`
4. `03_elasticities_aids_stata.do`
5. `04_tests_diagnostics_aids_stata.do`
6. `05_visualizations_aids_stata.do`

O pacote usa `gmm` diretamente e impõe as restrições por substituição de coeficientes, como a lista pede.
