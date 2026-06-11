Pacote Stata corrigido - Lista Berry/BLP

Correção central:
- O modelo teórico é delta_j = X_j'beta - alpha*p_j + xi_j.
- Os scripts agora estimam alpha diretamente usando neg_price = -price:
      delta_j = X_j'beta + alpha*neg_price_j + xi_j.
- Não há uso de abs(alpha) e não há imposição de demanda decrescente.
- Se alpha <= 0, os scripts avisam que o resultado estimado não é compatível com demanda própria decrescente, mas mantêm o resultado da estimação.

Arquivos ativos:
00_config.do
01_prepare_data.do
02_estimate_logit_iv_gmm.do
03_nested_gmm.do
04_elasticities_markups.do
05_diagnostics_weakiv.do
06_visualizations.do
07_extra_visualizations.do
08_standard_tables.do
b_program_operational.do
eberry_operational.do
run_all_stata.do
stata_graph_theme_snippet.do

Execução:
1. Copie esta pasta como stata/ dentro da raiz do pacote, substituindo os .do antigos.
2. Garanta que data/exemplo.csv exista.
3. Rode a partir da raiz:
      do stata/run_all_stata.do

Observação:
A pasta original_reference/ contém os códigos originais apenas como referência histórica e não é chamada pelo run_all_stata.do.


Atualização adicional:
- 06_visualizations.do: removida a linha horizontal pontilhada yline(0) apenas do gráfico 13_focal_product_marginal_effect_vs_price, pois ela atrapalhava a visualização quando o eixo y ficava todo acima de zero.
- run_all_stata.do: incluído cabeçalho institucional com autoria e matrículas.
