Correções aplicadas aos scripts R
=================================

1. Estimação do parâmetro de preço sem imposição de demanda decrescente
----------------------------------------------------------------------
O modelo teórico da lista é:

    delta_j = X_j'beta - alpha*p_j + xi_j

Para estimar alpha diretamente, os scripts agora criam:

    neg_price = -price

e estimam:

    delta_j = X_j'beta + alpha*neg_price + xi_j

Assim, alpha > 0 implica demanda decrescente. Se alpha <= 0, os scripts apenas
emitem warning; não há uso de abs() nem imposição artificial de sinal.

Arquivos afetados:
- 00_config.R
- 01_prepare_data.R
- 02_estimate_logit_iv_gmm.R
- 03_nested_gmm.R
- 04_elasticities_markups.R
- 05_diagnostics_weakiv.R
- 06_visualizations.R
- 07_extra_visualizations.R
- 08_standard_tables.R

2. GMM operacional fechado
--------------------------
A função berry_gmm_fit(), em functions_gmm.R, foi corrigida para usar a solução
fechada do GMM linear, adequada após a inversão de Berry:

    beta = (X'Z W Z'X)^(-1) X'Z W Z'Y

A segunda etapa atualiza W com base na matriz robusta dos momentos.

3. Gráfico do efeito marginal do preço
--------------------------------------
No gráfico 13_focal_product_marginal_effect_vs_price, a grade pontilhada foi
removida apenas nesse gráfico para não atrapalhar a visualização da curva. Não
foi adicionada linha de referência y = 0.

4. Cabeçalho do run_all_R.R
---------------------------
O cabeçalho foi atualizado no estilo solicitado, com objetivo e autores.
