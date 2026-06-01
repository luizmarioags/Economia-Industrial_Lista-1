# Notas técnicas — AIDS linear aproximado

## Produtos

O sistema usa quatro bens:

- `bfvl`: carne bovina e vitela;
- `pork`: carne suína;
- `poult`: frango;
- `fish`: pescados.

A equação de `poult` é omitida da estimação, mas o produto permanece no sistema.

## Participações

Para cada produto \(g\), a participação no dispêndio é

\[
w_{gt} = \frac{p_{gt}q_{gt}}{x_t},
\qquad
x_t = \sum_{k \in G} p_{kt}q_{kt}.
\]

Na base, os dispêndios por produto já aparecem como `xbfvl`, `xpork`, `xpoult` e `xfish`. Os scripts usam essas variáveis quando elas existem, pois elas correspondem ao dispêndio já compatibilizado com as séries de quantidade e preço da base. Caso elas não existam, os scripts tentam construir o dispêndio como preço vezes quantidade.

## Índice de Stone

A lista pede o índice de Stone com participações médias:

\[
\ln P^S_t = \sum_{k \in G} \bar w_k \ln p_{kt}.
\]

O uso de \(\bar w_k\), em vez de \(w_{kt}\), reduz a correlação mecânica entre o índice e a participação contemporânea no dispêndio.

## Dispêndio real

A variável de escala no AIDS é

\[
\ln \left(\frac{x_t}{P^S_t}\right)
=
\ln x_t - \ln P^S_t.
\]

Ela mede o dispêndio total em carnes descontado pelo índice de preços das carnes.

## Normalização dos preços

Para cada preço,

\[
lngp_{kt} = \ln p_{kt} - \frac{1}{T}\sum_{s=1}^T \ln p_{ks}.
\]

Essa normalização apenas desloca a origem das variáveis de preço e não muda derivadas nem elasticidades.

## Homogeneidade

A homogeneidade exige

\[
\sum_{k \in G} \gamma_{gk}=0.
\]

Na implementação, substitui-se o coeficiente de `poult` em cada equação:

\[
\gamma_{g,poult}
=
-\gamma_{g,bfvl}
-\gamma_{g,pork}
-\gamma_{g,fish}.
\]

Por isso a equação estimada pode ser escrita com diferenças de log-preço contra `poult`:

\[
\gamma_{g,bfvl}(lngp_{bfvl}-lngp_{poult})
+
\gamma_{g,pork}(lngp_{pork}-lngp_{poult})
+
\gamma_{g,fish}(lngp_{fish}-lngp_{poult}).
\]

## Simetria

A simetria exige

\[
\gamma_{gk}=\gamma_{kg}.
\]

Como a equação de `poult` é omitida, basta impor simetria entre as equações estimadas (`bfvl`, `pork`, `fish`) junto com homogeneidade e adding-up. As simetrias envolvendo `poult` são recuperadas pelas restrições.

## Adding-up

A equação omitida é recuperada por

\[
\alpha_{poult}=1-\alpha_{bfvl}-\alpha_{pork}-\alpha_{fish},
\]

\[
\beta_{poult}=-(\beta_{bfvl}+\beta_{pork}+\beta_{fish}),
\]

\[
\gamma_{poult,k}=-(\gamma_{bfvl,k}+\gamma_{pork,k}+\gamma_{fish,k}).
\]

## Elasticidades

A lista pede avaliação nas participações médias. A elasticidade-dispêndio é

\[
\eta_g = 1 + \frac{\beta_g}{\bar w_g}.
\]

As elasticidades-preço Marshallianas são

\[
\varepsilon^M_{gk}
=
-\mathbf 1\{g=k\}
+
\frac{\gamma_{gk}}{\bar w_g}
-
\frac{\beta_g \bar w_k}{\bar w_g}.
\]

As elasticidades compensadas são calculadas por Slutsky:

\[
\varepsilon^H_{gk}
=
\varepsilon^M_{gk}
+
\eta_g \bar w_k.
\]
