# Guia de respostas interpretativas

Este arquivo não substitui a redação final, mas organiza os pontos que devem ser discutidos.

## Questão 2 — Endogeneidade do preço

O preço real do frango pode ser endógeno porque é uma variável de equilíbrio. Choques não observados de demanda, incluídos em `u_t`, podem elevar simultaneamente quantidade e preço. Se há um choque positivo de demanda, a quantidade demandada aumenta e o preço de equilíbrio também pode aumentar. Nesse caso, a correlação positiva entre `ln_pch` e o erro tende a tornar o coeficiente de preço estimado por MQO menos negativo, isto é, viesado em direção a zero.

## Questão 4 — Relevância versus validade

Relevância significa que o instrumento explica a variável endógena no primeiro estágio, condicionalmente aos controles. Isso aparece em um coeficiente de `z` diferente de zero, R2 parcial maior e F usual maior. Contudo, relevância não é suficiente para validade: o instrumento também precisa ser exógeno, isto é, não pode afetar diretamente a demanda por frango nem estar correlacionado com choques não observados de demanda.

## Questão 5 — GMM e Hansen J

No caso exatamente identificado, o número de instrumentos excluídos é igual ao número de variáveis endógenas. Por isso, a escolha da matriz de ponderação do GMM não altera a estimativa pontual: há exatamente condições de momento suficientes para identificar o parâmetro. No caso sobreidentificado, a matriz de ponderação importa e o teste J de Hansen avalia se as restrições de sobreidentificação são compatíveis com os dados.

## Questão 7 — Heterocedasticidade e F usual

O F usual do primeiro estágio é derivado sob homocedasticidade. Em séries agregadas anuais de demanda, a variância dos choques pode mudar ao longo do tempo por crescimento do mercado, mudanças de renda, mudanças nos preços relativos, transformações tecnológicas e mudanças institucionais. Por isso, é prudente usar erros robustos e o F efetivo MOP no Stata.

## Questão 10 — Relevante, exógeno, forte e válido

- Instrumento relevante: correlacionado com a variável endógena condicionalmente aos controles.
- Instrumento exógeno: não correlacionado com o erro estrutural da demanda.
- Instrumento forte: tem correlação suficiente com a variável endógena para evitar grande viés de IV e distorção de inferência.
- Conjunto válido: contém instrumentos relevantes, suficientemente fortes e exógenos. O teste J de Hansen avalia a validade conjunta das restrições sobreidentificadoras, mas não prova que todos os instrumentos são exógenos.

## Questão 12 — Interpretação de Economia Industrial

Se `|beta_p| < 1`, a demanda estimada é inelástica; se `|beta_p| > 1`, é elástica. Para análise antitruste, a elasticidade é central para inferir poder de mercado, margens e perda crítica. Uma elasticidade obtida com instrumento fraco pode ser enganosa, pois o estimador IV pode ficar muito viesado e seus intervalos convencionais podem ter cobertura ruim.

## Questão 13 — Carne bovina como potencialmente endógena

O preço da carne bovina pode ser endógeno se choques de preferência por proteínas, renda não observada, sazonalidade ou choques macroeconômicos afetarem simultaneamente o consumo de frango e o preço da carne bovina. Se `ln_pb` for tratado como endógeno, seria necessário um instrumento que desloque a oferta de carne bovina sem afetar diretamente a demanda por frango. Exportações de carnes (`EATEX`/`MEATEX`) poderiam ser candidatas se deslocarem disponibilidade/oferta doméstica de carnes; a hipótese de exclusão exigiria que elas não afetem diretamente a demanda por frango, exceto pelo preço da carne bovina.
