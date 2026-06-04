# Diagnóstico e alterações realizadas no pacote

Este documento registra as principais mudanças feitas na documentação e na organização do pacote de replicação.

## 1. Caminhos de saída corrigidos

A configuração do projeto foi ajustada para salvar os resultados em uma raiz fixa:

```text
C:/Users/B03531855158/Documents/Replication/Códigos
```

Com isso, as saídas ficam organizadas em:

```text
output/tables/   # tabelas, CSVs e LaTeX
output/logs/     # logs gerais e logs do weakivtest
output/figures/  # figuras do relatório
```

As bases intermediárias continuam em:

```text
data/processed/
```

## 2. Documentação reescrita

Foram reescritos:

- `README.md`;
- `docs/mapa_questoes.md`;
- `docs/implementacao_computacional.md`;
- `docs/respostas_interpretativas.md`;
- `docs/diagnostico_pacote_original.md`;
- `docs/relatorio_plots_comparativos.md`;
- `docs/relatorio_plots_comparativos_avancado.md`.

O novo README inclui os membros do grupo, o objetivo da lista, o modelo estimado, as variáveis construídas, a estrutura de pastas, a forma de execução, os scripts e as principais saídas.

## 3. Remoção de informações sobre plots comparativos

A documentação anterior mencionava plots comparativos entre Stata, R e Python. Essa informação foi removida/substituída porque o repositório atual não contém esse módulo comparativo.

Os gráficos gerados agora são apenas os gráficos da própria análise econométrica, como:

- séries logarítmicas;
- dispersão entre quantidade e preço;
- resíduos do MQO;
- elasticidades por conjunto de instrumentos;
- GMM/Hansen;
- teste J de Hansen;
- simulação de instrumentos fracos;
- curva IV empírica.

## 4. Mapeamento das questões

O arquivo `docs/mapa_questoes.md` passou a relacionar cada questão da lista com:

- o que foi feito;
- qual script executa a tarefa;
- quais tabelas, logs ou figuras são gerados;
- como a implementação aparece no relatório.

## 5. Descrição da implementação computacional

Foi criado o arquivo `docs/implementacao_computacional.md`, que descreve o fluxo completo dos scripts Stata:

1. configuração de caminhos;
2. preparação da base;
3. estimações MQO e IV;
4. GMM e Hansen J;
5. testes de instrumentos fracos;
6. intervalos Anderson-Rubin;
7. figuras;
8. simulação;
9. curva IV com dados observados.

## 6. Escopo atual

Este pacote documenta a implementação computacional em Stata. Caso existam versões em R ou Python em outro repositório, elas não são pressupostas por esta documentação.
