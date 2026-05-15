# Diagnóstico da versão anterior do pacote

A versão anterior do repositório estava bem estruturada, mas não respondia integralmente à nova Lista 1 de 2026.

Principais problemas encontrados:

1. **Base de dados anterior**: a versão antiga baixava automaticamente uma base `broiler.csv` de um espelho do MIT, com 40 observações em algumas versões. A lista atual veio acompanhada da base `chicken` correta, com 52 observações.

2. **Instrumentos alternativos diferentes**: a versão anterior usava dez especificações, incluindo `exp(z)`, `exp(z^2)` e defasagens exponenciadas. A lista atual pede sete especificações: `Z1` a `Z7`, sem transformações exponenciais.

3. **Ausência de GMM/Hansen J completo**: a nova lista pede GMM para `{z}` e `{z,z^2}`, além do teste J de Hansen para modelos sobreidentificados.

4. **Inferência robusta a instrumentos fracos**: a nova lista pede, para pelo menos três especificações, intervalos robustos a instrumentos fracos, como Anderson-Rubin ou CLR. A versão antiga não fazia isso.

5. **Simulação de instrumentos fracos**: a nova lista inclui uma questão de simulação. A versão antiga não tinha módulo de simulação.

6. **Python IV**: em versões anteriores, havia risco de estimar IV sem constante explícita. Nesta versão, todas as rotinas matriciais usam constante explicitamente.

7. **Documentação**: esta versão mapeia as questões da lista para scripts e tabelas de saída, facilitando a replicação.
