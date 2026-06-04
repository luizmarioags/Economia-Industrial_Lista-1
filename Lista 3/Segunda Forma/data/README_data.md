# Dados de entrada

Coloque o arquivo principal como:

```text
data/exemplo.csv
```

O pacote foi convertido a partir dos scripts Stata enviados. O script Stata original renomeia as 11 primeiras colunas por posição, então o CSV deve seguir esta ordem:

1. `idProduct`
2. `firm`
3. `product`
4. `price`
5. `shelf_price`
6. `ad_price`
7. `share_pct`
8. `segment`
9. `cals`
10. `fat`
11. `sugar`

A firma externa `basketof` é removida da amostra interna. A participação externa usada na inversão Berry é `s0 = 0.2429`, conforme o arquivo `00_config.do`.
