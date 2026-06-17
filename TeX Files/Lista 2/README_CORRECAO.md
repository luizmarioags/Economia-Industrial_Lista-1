# Tabelas LaTeX corrigidas — Lista AIDS 2026

Correções aplicadas:

1. Incluído suporte a `longtable` para a tabela de coeficientes.
2. Corrigidas quebras de linha LaTeX (`\`) nas tabelas longas.
3. Escapados underscores em nomes de variáveis (`a\_bfvl`, `homog\_simetria`, etc.).
4. Substituído `R²` por `$R^2$`.
5. Tabelas largas foram envolvidas em `\resizebox{\textwidth}{!}{...}`.
6. Arquivos duplicados de `.dta`/Excel foram mantidos, mas com labels distintos para evitar conflito.

No preâmbulo principal, adicione:

```latex
\usepackage{longtable}
```

Seu documento já usa `booktabs`, `graphicx` e `float`, que também são necessários.

## Recomendação de uso
Não insira duas versões da mesma tabela. Use as versões sem sufixo `_dta` ou `_excel` no texto final, a menos que você queira mostrar especificamente uma checagem de robustez da leitura do arquivo.
