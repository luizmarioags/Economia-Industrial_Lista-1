################################################################################
# Arquivo: R/04_visualizations_aids_R.R
# Objetivo: gerar gráficos e tabelas visuais para dados, resultados e diagnósticos.
################################################################################

source("R/00_config_aids.R")

# Garante subdiretorios de exportacao, mesmo se o config antigo ainda estiver em uso.
if (!exists("FIGURES_PDF")) FIGURES_PDF <- file.path(FIGURES, "PDF")
if (!exists("FIGURES_PNG")) FIGURES_PNG <- file.path(FIGURES, "PNG")
dir.create(FIGURES_PDF, recursive = TRUE, showWarnings = FALSE)
dir.create(FIGURES_PNG, recursive = TRUE, showWarnings = FALSE)                         # Carrega configuração do projeto.

dados <- readRDS(file.path(PROC, "meatdata_aids_preparado_R.rds")) # Abre base processada.
model_hsym <- readRDS(file.path(MODELS, "model_hsym_R.rds"))       # Abre modelo final.
elasticidades <- readRDS(file.path(MODELS, "elasticidades_hsym_R.rds")) # Abre matrizes de elasticidade.

save_plot <- function(plot, filename, width = 9, height = 6) { # Define função para salvar gráfico em PDF e PNG.
  ggplot2::ggsave(file.path(FIGURES_PDF, paste0(filename, ".pdf")), plot, width = width, height = height, bg = "white") # Salva PDF na subpasta PDF com fundo branco.
  ggplot2::ggsave(file.path(FIGURES_PNG, paste0(filename, ".png")), plot, width = width, height = height, dpi = 300, bg = "white") # Salva PNG na subpasta PNG com fundo branco.
}                                                     # Fecha função save_plot.

aids_colors <- c(                                    # Define paleta inspirada no template Stata enviado.
  "Carne bovina e vitela" = "navy",                 # Cor da carne bovina e vitela.
  "Carne suína" = "#B03060",                       # Cor da carne suína, próxima de cranberry.
  "Frango" = "forestgreen",                        # Cor do frango.
  "Pescados" = "orange",                           # Cor dos pescados.
  "Índice de Stone" = "navy",                      # Cor do índice de Stone.
  "Dispêndio real com carnes" = "#B03060",         # Cor do dispêndio real.
  "Primeira defasagem" = "navy",                   # Cor dos instrumentos de primeira defasagem.
  "Primeira e segunda defasagens" = "#B03060"       # Cor dos instrumentos ampliados.
)                                                     # Fecha vetor de cores.

theme_aids <- function() {                            # Define tema gráfico no padrão visual do template.
  ggplot2::theme_minimal(base_size = 12) +            # Usa base limpa e clara.
    ggplot2::theme(                                   # Ajusta elementos visuais.
      legend.position = "right",                     # Coloca legenda à direita, como no template.
      legend.title = ggplot2::element_blank(),        # Remove título redundante da legenda.
      legend.background = ggplot2::element_rect(fill = "white", color = NA), # Mantém legenda limpa.
      plot.background = ggplot2::element_rect(fill = "white", color = NA),   # Usa fundo branco.
      panel.background = ggplot2::element_rect(fill = "white", color = NA),  # Usa painel branco.
      panel.grid.major = ggplot2::element_line(color = "grey88", linewidth = 0.25), # Grade principal clara.
      panel.grid.minor = ggplot2::element_line(color = "grey94", linewidth = 0.15), # Grade secundária mais suave.
      plot.title = ggplot2::element_text(face = "bold", size = 12, color = "black"), # Título em negrito.
      plot.subtitle = ggplot2::element_text(size = 10, color = "black"),     # Subtítulo menor.
      axis.title = ggplot2::element_text(size = 10, color = "black"),        # Títulos dos eixos menores.
      axis.text = ggplot2::element_text(size = 9, color = "black"),          # Rótulos dos eixos legíveis.
      strip.text = ggplot2::element_text(face = "bold", color = "black")    # Títulos dos painéis em negrito.
    )                                                   # Fecha theme.
}                                                       # Fecha tema.

scale_color_aids <- function() {                       # Define escala discreta de cores.
  ggplot2::scale_color_manual(values = aids_colors)     # Aplica paleta aos gráficos com cor discreta.
}                                                       # Fecha função de cor.

scale_fill_aids <- function() {                        # Define escala discreta de preenchimento.
  ggplot2::scale_fill_manual(values = aids_colors)      # Aplica paleta aos gráficos com preenchimento discreto.
}                                                       # Fecha função de preenchimento.

scale_color_produtos <- function() {                    # Define escala de cor para identificar cada variável nas matrizes.
  ggplot2::scale_color_manual(
    values = c(bfvl = "navy", pork = "#B03060", poult = "forestgreen", fish = "orange"),
    breaks = c("bfvl", "pork", "poult", "fish"),
    labels = c("Carne bovina e vitela", "Carne suína", "Frango", "Pescados")
  )
}                                                       # Fecha função de cor por variável.

scale_fill_produtos <- function() {                     # Define escala de preenchimento por produto com nomes completos na legenda.
  ggplot2::scale_fill_manual(
    values = c("Carne bovina e vitela" = "navy", "Carne suína" = "#B03060", "Frango" = "forestgreen", "Pescados" = "orange"),
    breaks = c("Carne bovina e vitela", "Carne suína", "Frango", "Pescados")
  )
}                                                       # Fecha função de preenchimento por produto.


produto_labels <- c(                                  # Define rótulos explicativos para produtos.
  bfvl = "Carne bovina e vitela",                    # Nome completo de bfvl.
  pork = "Carne suína",                              # Nome completo de pork.
  poult = "Frango",                                  # Nome completo de poult.
  fish = "Pescados"                                  # Nome completo de fish.
)                                                       # Fecha vetor de rótulos.

modelo_labels <- c(                                   # Define rótulos explicativos para modelos.
  irrestrito = "Sem restrições teóricas",             # Modelo sem homogeneidade e simetria.
  homogeneidade = "Com homogeneidade",                # Modelo com homogeneidade.
  homog_simetria = "Com homogeneidade e simetria",    # Modelo final.
  homog_simetria_L2 = "Modelo final com duas defasagens" # Modelo alternativo.
)                                                       # Fecha vetor de modelos.

instrumento_labels <- c(                              # Define rótulos explicativos para instrumentos.
  L1 = "Primeira defasagem",                          # Instrumentos com uma defasagem.
  L1_L2 = "Primeira e segunda defasagens"              # Instrumentos com duas defasagens.
)                                                       # Fecha vetor de instrumentos.

parametro_labels <- c(                                # Define rótulos explicativos para parâmetros livres do modelo final.
  a_bfvl = "Intercepto: carne bovina e vitela",        # Intercepto da equação de bovina/vitela.
  g11 = "Preço próprio: carne bovina e vitela",        # Efeito de preço próprio.
  g12 = "Substituição entre bovina/vitela e suína",    # Efeito cruzado simétrico.
  g14 = "Substituição entre bovina/vitela e pescados", # Efeito cruzado simétrico.
  b_bfvl = "Dispêndio real: carne bovina e vitela",    # Coeficiente do dispêndio real.
  a_pork = "Intercepto: carne suína",                  # Intercepto da equação de suína.
  g22 = "Preço próprio: carne suína",                  # Efeito de preço próprio.
  g24 = "Substituição entre suína e pescados",         # Efeito cruzado simétrico.
  b_pork = "Dispêndio real: carne suína",              # Coeficiente do dispêndio real.
  a_fish = "Intercepto: pescados",                     # Intercepto da equação de pescados.
  g44 = "Preço próprio: pescados",                     # Efeito de preço próprio.
  b_fish = "Dispêndio real: pescados"                  # Coeficiente do dispêndio real.
)                                                       # Fecha vetor de parâmetros.

nome_produto <- function(x) {                          # Converte código de produto para nome explicativo.
  out <- produto_labels[x]                              # Procura rótulo no vetor.
  out[is.na(out)] <- x[is.na(out)]                      # Mantém valor original se não houver correspondência.
  unname(out)                                           # Remove nomes do vetor.
}                                                       # Fecha função.

nome_modelo <- function(x) {                            # Converte código de modelo para nome explicativo.
  out <- modelo_labels[x]                               # Procura rótulo do modelo.
  out[is.na(out)] <- x[is.na(out)]                      # Mantém original se não houver correspondência.
  unname(out)                                           # Remove nomes do vetor.
}                                                       # Fecha função.

nome_instrumento <- function(x) {                       # Converte código de instrumento para nome explicativo.
  out <- instrumento_labels[x]                          # Procura rótulo do instrumento.
  out[is.na(out)] <- x[is.na(out)]                      # Mantém original se não houver correspondência.
  unname(out)                                           # Remove nomes do vetor.
}                                                       # Fecha função.

nome_parametro <- function(x) {                         # Converte código de parâmetro para nome explicativo.
  out <- parametro_labels[x]                            # Procura rótulo do parâmetro.
  out[is.na(out)] <- x[is.na(out)]                      # Mantém original se não houver correspondência.
  unname(out)                                           # Remove nomes do vetor.
}                                                       # Fecha função.

rotulo_variavel_produto <- function(x) {                # Extrai produto de nomes técnicos usados em matrizes de correlação.
  key <- x                                               # Copia o vetor de nomes.
  key <- stringr::str_remove(key, "^L1_lngp_")          # Remove prefixo de instrumento defasado.
  key <- stringr::str_remove(key, "^lngp_")             # Remove prefixo de log-preço normalizado.
  key <- stringr::str_remove(key, "^w_")                # Remove prefixo de participação.
  key <- stringr::str_remove(key, "p$")                 # Remove sufixo de preço.
  nome_produto(key)                                      # Retorna nome explicativo do produto.
}                                                       # Fecha função.


series_long <- function(data, vars, value_name) {      # Define função para transformar séries em formato longo.
  data %>%                                             # Inicia pipeline.
    select(year, all_of(vars)) %>%                     # Seleciona ano e variáveis.
    pivot_longer(-year, names_to = "serie", values_to = value_name) # Converte para formato longo.
}                                                     # Fecha função series_long.

shares_long <- series_long(dados, paste0("w_", GOODS), "participacao") %>% # Cria dados longos de participações.
  mutate(produto = nome_produto(str_remove(serie, "^w_")))           # Remove prefixo para obter nome do produto.

p_shares <- ggplot(shares_long, aes(year, participacao, color = produto)) + # Inicia gráfico de participações.
  geom_line(linewidth = 1) +                            # Adiciona linhas.
  geom_point(size = 1.5) +                              # Adiciona pontos.
  labs(title = "Participações no dispêndio com carnes", x = "Ano", y = "Participação do produto no gasto total com carnes") + # Define rótulos.
  scale_color_aids() +                                  # Aplica paleta do template.
  theme_aids()                                         # Aplica tema.
save_plot(p_shares, "R_01_participacoes_dispendio")    # Salva gráfico de participações.

prices_long <- series_long(dados, paste0(GOODS, "p"), "preco") %>% # Cria dados longos de preços.
  mutate(produto = nome_produto(str_remove(serie, "p$")))            # Remove sufixo p.

p_prices <- ggplot(prices_long, aes(year, preco, color = produto)) + # Inicia gráfico de preços.
  geom_line(linewidth = 1) +                            # Adiciona linhas.
  geom_point(size = 1.5) +                              # Adiciona pontos.
  labs(title = "Índices de preços das carnes", x = "Ano", y = "Índice de preço do produto") + # Define rótulos.
  scale_color_aids() +                                  # Aplica paleta do template.
  theme_aids()                                         # Aplica tema.
save_plot(p_prices, "R_02_precos")                     # Salva gráfico de preços.

lngp_long <- series_long(dados, paste0("lngp_", GOODS), "lngp") %>% # Cria dados longos de log-preços.
  mutate(produto = nome_produto(str_remove(serie, "^lngp_")))         # Remove prefixo lngp.

p_lngp <- ggplot(lngp_long, aes(year, lngp, color = produto)) + # Inicia gráfico de log-preços normalizados.
  geom_hline(yintercept = 0, linetype = "dashed") +     # Adiciona linha zero.
  geom_line(linewidth = 1) +                            # Adiciona linhas.
  geom_point(size = 1.5) +                              # Adiciona pontos.
  labs(title = "Preços em log normalizados pela média temporal", x = "Ano", y = "Desvio logarítmico do preço em relação à média") + # Define rótulos.
  scale_color_aids() +                                  # Aplica paleta do template.
  theme_aids()                                         # Aplica tema.
save_plot(p_lngp, "R_03_log_precos_normalizados")      # Salva log-preços.

exp_long <- series_long(dados, paste0("x", GOODS), "dispendio") %>% # Cria dados longos de dispêndios.
  mutate(produto = nome_produto(str_remove(serie, "^x")))             # Remove prefixo x.

p_exp <- ggplot(exp_long, aes(year, dispendio, color = produto)) + # Inicia gráfico de dispêndios.
  geom_line(linewidth = 1) +                            # Adiciona linhas.
  geom_point(size = 1.5) +                              # Adiciona pontos.
  labs(title = "Dispêndio anual por tipo de carne", x = "Ano", y = "Dispêndio do produto") + # Define rótulos.
  scale_color_aids() +                                  # Aplica paleta do template.
  theme_aids()                                         # Aplica tema.
save_plot(p_exp, "R_04_dispendios_produto")            # Salva dispêndios.

p_xtotal <- ggplot(dados, aes(year, xtotal_calc)) +     # Inicia gráfico do dispêndio total.
  geom_line(linewidth = 1, color = "navy") +            # Adiciona linha no padrão do template.
  geom_point(size = 1.5, color = "navy") +              # Adiciona pontos no padrão do template.                              # Adiciona pontos.
  labs(title = "Dispêndio total com os quatro produtos de carne", x = "Ano", y = "Dispêndio total com carnes") + # Define rótulos.
  theme_aids()                                         # Aplica tema.
save_plot(p_xtotal, "R_05_dispendio_total_carnes")      # Salva dispêndio total.

stone_long <- dados %>%                                # Cria dados longos para Stone e dispêndio real.
  select(year, lnP_stone, ln_real_x) %>%               # Seleciona variáveis.
  pivot_longer(-year, names_to = "serie", values_to = "valor") %>% # Converte para longo.
  mutate(serie = dplyr::recode(serie, lnP_stone = "Índice de Stone", ln_real_x = "Dispêndio real com carnes")) # Troca códigos por rótulos.

p_stone <- ggplot(stone_long, aes(year, valor, color = serie)) + # Inicia gráfico Stone/real.
  geom_line(linewidth = 1) +                            # Adiciona linhas.
  geom_point(size = 1.5) +                              # Adiciona pontos.
  labs(title = "Índice de Stone e dispêndio real com carnes", x = "Ano", y = "Valor em logaritmo") + # Define rótulos.
  scale_color_aids() +                                  # Aplica paleta do template.
  theme_aids()                                         # Aplica tema.
save_plot(p_stone, "R_06_stone_dispendio_real")        # Salva gráfico Stone/real.

if ("meat_pce_share" %in% names(dados)) {              # Verifica se existe peso das carnes no PCE.
  p_pce <- ggplot(dados, aes(year, meat_pce_share)) +  # Inicia gráfico do peso no PCE.
    geom_line(linewidth = 1, color = "navy") +          # Adiciona linha no padrão do template.
    geom_point(size = 1.5, color = "navy") +                            # Adiciona pontos.
    labs(title = "Peso do dispêndio com carnes no consumo agregado", x = "Ano", y = "Participação do gasto com carnes no consumo agregado") + # Define rótulos.
    theme_aids()                                       # Aplica tema.
  save_plot(p_pce, "R_07_peso_carnes_pce")             # Salva gráfico.
}                                                       # Fecha condição.

p_add <- ggplot(dados, aes(year, share_sum)) +          # Inicia gráfico de adding-up nos dados.
  geom_hline(yintercept = 1, linetype = "dashed", color = "black") + # Adiciona linha de referência em 1.
  geom_line(linewidth = 1, color = "navy") +            # Adiciona linha no padrão do template.
  geom_point(size = 1.5, color = "navy") +              # Adiciona pontos no padrão do template.                              # Adiciona pontos.
  labs(title = "Checagem da soma das participações no dispêndio", x = "Ano", y = "Soma das participações") + # Define rótulos.
  theme_aids()                                         # Aplica tema.
save_plot(p_add, "R_08_checagem_soma_participacoes")   # Salva gráfico.

scatter_share_price <- dados %>%                       # Inicia dados para dispersão preço-participação.
  select(year, all_of(paste0(GOODS, "p")), all_of(paste0("w_", GOODS))) %>% # Seleciona preços e participações.
  pivot_longer(cols = -year, names_to = "variavel", values_to = "valor") %>% # Converte tudo para longo.
  mutate(produto = nome_produto(str_remove(str_remove(variavel, "^w_"), "p$")), tipo = ifelse(str_detect(variavel, "^w_"), "participacao", "preco")) %>% # Separa produto e tipo.
  select(year, produto, tipo, valor) %>%                # Mantém colunas necessárias.
  pivot_wider(names_from = tipo, values_from = valor)   # Retorna a preço e participação lado a lado.

p_scatter <- ggplot(scatter_share_price, aes(preco, participacao)) + # Inicia dispersão preço-participação.
  geom_point(color = "navy") +                           # Adiciona pontos no padrão do template.
  geom_smooth(method = "lm", se = FALSE, color = "#B03060") +               # Adiciona tendência linear.
  facet_wrap(~ produto, scales = "free") +               # Cria painel por produto.
  labs(title = "Relação entre preço e participação no dispêndio", x = "Índice de preço do produto", y = "Participação no gasto total com carnes") + # Define rótulos.
  theme_aids()                                           # Aplica tema.
save_plot(p_scatter, "R_09_dispersao_preco_participacao") # Salva dispersão.

corr_heatmap <- function(data, vars, title, filename) {  # Define função para mapa de correlação.
  C <- cor(data[, vars], use = "complete.obs")           # Calcula matriz de correlação.
  C_long <- as.data.frame(C) %>%                         # Converte matriz em data.frame.
    tibble::rownames_to_column("linha") %>%              # Move nomes das linhas.
    pivot_longer(-linha, names_to = "coluna", values_to = "correlacao") %>% # Converte para longo.
    mutate(linha = rotulo_variavel_produto(linha), coluna = rotulo_variavel_produto(coluna)) # Troca códigos por nomes explicativos.
  readr::write_csv(C_long, file.path(TABLES, paste0(filename, ".csv"))) # Salva correlações.
  p <- ggplot(C_long, aes(coluna, linha, fill = correlacao)) + # Inicia heatmap.
    geom_tile() +                                           # Adiciona células.
    geom_text(aes(label = sprintf("%.2f", correlacao)), size = 3) + # Adiciona rótulos.
    labs(title = title, x = NULL, y = NULL, fill = "Correlação") + # Define rótulos.
    ggplot2::scale_fill_gradient2(low = "navy", mid = "white", high = "#B03060", midpoint = 0) + # Aplica mapa de cores do template.
    theme_aids() +                                           # Aplica tema.
    theme(axis.text.x = element_text(angle = 45, hjust = 1))  # Inclina eixo x.
  save_plot(p, filename)                                    # Salva heatmap.
}                                                           # Fecha função de correlação.

corr_heatmap(dados, paste0("w_", GOODS), "Correlação entre participações", "R_10_correlacao_participacoes") # Gera correlação das participações.
corr_heatmap(dados, paste0("lngp_", GOODS), "Correlação entre log-preços normalizados", "R_11_correlacao_log_precos") # Gera correlação dos preços.
corr_heatmap(dados, paste0("L1_lngp_", GOODS), "Correlação entre instrumentos defasados", "R_12_correlacao_instrumentos") # Gera correlação dos instrumentos.

coeficientes <- readr::read_csv(file.path(TABLES, "coeficientes_R.csv"), show_col_types = FALSE) # Lê coeficientes.
coef_hsym <- coeficientes %>%                                           # Filtra modelo final.
  filter(modelo == "homog_simetria") %>%                                # Mantém homogeneidade e simetria.
  mutate(                                                               # Cria limites e legenda por produto.
    lb = estimativa - 1.96 * erro_padrao,
    ub = estimativa + 1.96 * erro_padrao,
    produto_legenda = dplyr::case_when(
      parametro %in% c("a_bfvl", "g11", "g12", "g14", "b_bfvl") ~ "Carne bovina e vitela",
      parametro %in% c("a_pork", "g22", "g24", "b_pork") ~ "Carne suína",
      parametro %in% c("a_fish", "g44", "b_fish") ~ "Pescados",
      TRUE ~ "Outros"
    )
  )                                                                     # Fecha mutate.

p_coef <- ggplot(coef_hsym, aes(reorder(parametro, estimativa), estimativa, color = produto_legenda)) + # Inicia gráfico de coeficientes.
  geom_hline(yintercept = 0, linetype = "dashed") +             # Adiciona linha zero.
  geom_linerange(aes(ymin = lb, ymax = ub), color = "grey45") + # Adiciona intervalo de confiança em cinza.
  geom_point(size = 2.2) +                                      # Adiciona ponto colorido por produto.
  coord_flip() +                                                # Vira eixos.
  labs(title = "Coeficientes estimados no modelo com homogeneidade e simetria", x = "Nome do parâmetro", y = "Estimativa do coeficiente", color = "Produto") + # Define rótulos.
  scale_color_manual(values = c("Carne bovina e vitela" = "navy", "Carne suína" = "#B03060", "Pescados" = "orange")) + # Cores por produto.
  theme_aids()                                                  # Aplica tema.
save_plot(p_coef, "R_13_coeficientes_hsym")                     # Salva coeficientes.

comparacao <- readr::read_csv(file.path(TABLES, "comparacao_modelos_R.csv"), show_col_types = FALSE) %>% # Lê comparação de modelos.
  mutate(modelo_rotulo = nome_modelo(modelo)) # Troca códigos de modelos por nomes explicativos.

p_J <- ggplot(comparacao, aes(modelo_rotulo, J)) +                      # Inicia gráfico da estatística J.
  geom_col(fill = "navy", alpha = 0.75) +                          # Adiciona barras no padrão do template.
  labs(title = "Estatística objetivo do GMM", x = "Especificação estimada", y = "Estatística objetivo") + # Define rótulos.
  theme_aids() +                                                  # Aplica tema.
  theme(axis.text.x = element_text(angle = 30, hjust = 1))        # Inclina eixo.
save_plot(p_J, "R_14_estatistica_J_modelos")                      # Salva J.

p_pJ <- ggplot(comparacao, aes(modelo_rotulo, p_J)) +                    # Inicia gráfico do p-valor J.
  geom_col(fill = "navy", alpha = 0.75) +                          # Adiciona barras no padrão do template.
  geom_hline(yintercept = 0.05, linetype = "dashed") +            # Adiciona referência 5%.
  labs(title = "p-valor do teste de sobreidentificação", x = "Especificação estimada", y = "p-valor") + # Define rótulos.
  theme_aids() +                                                  # Aplica tema.
  theme(axis.text.x = element_text(angle = 30, hjust = 1))        # Inclina eixo.
save_plot(p_pJ, "R_15_pvalor_J_modelos")                          # Salva p-valor J.

n <- length(model_hsym$design$y) / length(EST_GOODS)              # Calcula número de anos da amostra empilhada.
data_L1 <- dados %>% tidyr::drop_na(w_bfvl, w_pork, w_fish, ln_real_x, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish) # Recria amostra L1.

fit_tbl <- tibble::tibble(                                        # Cria tabela de ajuste.
  year = rep(data_L1$year, times = length(EST_GOODS)),             # Repete anos para cada equação.
  produto = nome_produto(rep(EST_GOODS, each = n)),                              # Identifica produto.
  observado = model_hsym$design$y,                                 # Insere participação observada.
  previsto = model_hsym$fitted,                                    # Insere participação prevista.
  residuo = model_hsym$resid                                      # Insere resíduo.
)                                                                  # Fecha tabela de ajuste.

readr::write_csv(fit_tbl, file.path(TABLES, "ajuste_residuos_hsym_R.csv")) # Exporta ajuste e resíduos.

p_fit <- ggplot(fit_tbl, aes(previsto, observado)) +               # Inicia observado versus previsto.
  geom_point(color = "navy") +                                      # Adiciona pontos no padrão do template.
  geom_smooth(method = "lm", se = FALSE, color = "#B03060") +                          # Adiciona linha de ajuste.
  facet_wrap(~ produto, scales = "free") +                          # Cria painel por produto.
  labs(title = "Observado versus previsto", x = "Previsto", y = "Observado") + # Define rótulos.
  theme_aids()                                                      # Aplica tema.
save_plot(p_fit, "R_16_observado_previsto")                         # Salva observado-previsto.

p_res_time <- ggplot(fit_tbl, aes(year, residuo, color = produto)) + # Inicia resíduos no tempo.
  geom_hline(yintercept = 0, linetype = "dashed") +                  # Adiciona linha zero.
  geom_line(linewidth = 1) +                                         # Adiciona linhas.
  geom_point(size = 1.5) +                                           # Adiciona pontos.
  labs(title = "Resíduos por equação estimada", x = "Ano", y = "Diferença entre participação observada e prevista") +  # Define rótulos.
  scale_color_aids() +                                  # Aplica paleta do template.
  theme_aids()                                                       # Aplica tema.
save_plot(p_res_time, "R_17_residuos_series")                       # Salva resíduos no tempo.

p_res_hist <- ggplot(fit_tbl, aes(residuo)) +                        # Inicia histograma de resíduos.
  geom_histogram(aes(y = after_stat(density)), bins = 12, fill = "navy", color = "white", alpha = 0.75) + # Adiciona histograma em escala de densidade.
  geom_density(color = "red", linewidth = 1) +                      # Adiciona curva de densidade vermelha para contraste.
  facet_wrap(~ produto, scales = "free") +                           # Cria painel por produto.
  labs(title = "Distribuição dos resíduos", x = "Resíduo", y = "Densidade") + # Define rótulos.
  theme_aids()                                                       # Aplica tema.
save_plot(p_res_hist, "R_18_hist_residuos")                          # Salva histograma.

p_res_fit <- ggplot(fit_tbl, aes(previsto, residuo)) +                # Inicia resíduo versus previsto.
  geom_hline(yintercept = 0, linetype = "dashed") +                   # Adiciona linha zero.
  geom_point(color = "navy") +                                      # Adiciona pontos no padrão do template.
  facet_wrap(~ produto, scales = "free") +                            # Cria painel por produto.
  labs(title = "Resíduos versus valores previstos", x = "Previsto", y = "Resíduo") + # Define rótulos.
  theme_aids()                                                        # Aplica tema.
save_plot(p_res_fit, "R_19_residuos_vs_previsto")                     # Salva resíduos versus previsto.

eta_tbl <- readr::read_csv(file.path(TABLES, "elasticidade_dispendio_hsym_R.csv"), show_col_types = FALSE) # Lê elasticidades-dispêndio mantendo o nome original da variavel.

p_eta <- ggplot(eta_tbl, aes(produto, eta)) +                          # Inicia gráfico de eta.
  geom_col(fill = "navy", alpha = 0.75) +                         # Adiciona barras no padrão do template.
  geom_hline(yintercept = 1, linetype = "dashed") +                    # Adiciona referência unitária.
  labs(title = "Elasticidade em relação ao dispêndio real", x = "Produto", y = "Elasticidade-dispêndio") + # Define rótulos.
  theme_aids()                                                         # Aplica tema.
save_plot(p_eta, "R_20_elasticidades_dispendio")                       # Salva eta.

heat_matrix <- function(long_data, value_col, title, filename) {        # Define função de heatmap de matriz.
  long_data <- long_data %>%                                             # Mantém nomes originais das variáveis.
    mutate(                                                              # Define a ordem dos produtos na matriz.
      produto_coluna = factor(produto_coluna, levels = c("bfvl", "pork", "poult", "fish")),
      produto_linha = factor(produto_linha, levels = c("fish", "poult", "pork", "bfvl"))
    )
  p <- ggplot(long_data, aes(produto_coluna, produto_linha, fill = .data[[value_col]])) + # Inicia heatmap.
    geom_tile(color = "grey70") +                                       # Adiciona células com borda leve.
    geom_point(aes(color = produto_coluna), shape = 15, size = 10, alpha = 0.55) + # Usa cor para identificar a variável da coluna.
    geom_text(aes(label = sprintf("%.2f", .data[[value_col]])), size = 3) + # Adiciona valores.
    labs(title = title, x = "Preço: nome da variável", y = "Demanda: nome da variável", fill = "Valor", color = "Produto") + # Define rótulos.
    ggplot2::scale_fill_gradient2(low = "navy", mid = "white", high = "#B03060", midpoint = 0) + # Aplica mapa de cores.
    scale_color_produtos() +                                             # Aplica cores por variável com legenda.
    theme_aids() +                                                       # Aplica tema.
    theme(axis.text.x = element_text(angle = 0, hjust = 0.5), legend.position = "right") # Mantém nomes curtos e legenda à direita.
  save_plot(p, filename)                                                # Salva heatmap.
}                                                                       # Fecha função heat_matrix.

gamma_long <- readr::read_csv(file.path(TABLES, "gamma_hsym_long_R.csv"), show_col_types = FALSE) # Lê gamma longo.
em_long <- readr::read_csv(file.path(TABLES, "elasticidades_marshallianas_hsym_long_R.csv"), show_col_types = FALSE) # Lê EM longa.
eh_long <- readr::read_csv(file.path(TABLES, "elasticidades_compensadas_hsym_long_R.csv"), show_col_types = FALSE) # Lê EH longa.

heat_matrix(gamma_long, "gamma", "Matriz dos efeitos de preços", "R_21_matriz_gamma") # Salva heatmap gamma.
heat_matrix(em_long, "elasticidade_marshalliana", "Elasticidades não compensadas", "R_22_elasticidades_marshallianas") # Salva heatmap EM.
heat_matrix(eh_long, "elasticidade_compensada", "Elasticidades compensadas", "R_23_elasticidades_compensadas") # Salva heatmap EH.

diag_fs <- readr::read_csv(file.path(TABLES, "diagnostico_primeira_etapa_R.csv"), show_col_types = FALSE) %>% # Lê primeira etapa.
  mutate(                                                              # Escreve o procedimento no eixo x e os nomes completos apenas na legenda.
    instrumento = dplyr::recode(
      instrumento,
      "L1" = "Preços defasados em t-1",
      "L1_L2" = "Preços defasados em t-1 e t-2"
    ),
    preco_legenda = nome_produto(preco)
  )

p_F <- ggplot(diag_fs, aes(instrumento, F_excluidos, fill = preco_legenda)) + # Inicia gráfico do F com procedimento no eixo x.
  geom_col(position = "dodge") +                         # Adiciona barras lado a lado.
  geom_hline(yintercept = 10, linetype = "dashed") +      # Adiciona referência usual F=10.
  labs(title = "Força dos instrumentos na primeira etapa", x = "Conjunto de instrumentos usado", y = "Estatística F dos instrumentos defasados", fill = "Produto") + # Define rótulos.
  scale_fill_produtos() +                                # Aplica paleta com nomes completos.
  theme_aids() +                                        # Aplica tema.
  theme(axis.text.x = element_text(angle = 10, hjust = 1)) # Ajusta eixo.
save_plot(p_F, "R_24_primeira_etapa_F")                   # Salva F.

p_R2 <- ggplot(diag_fs, aes(instrumento, r2_parcial, fill = preco_legenda)) + # Inicia gráfico do R2 parcial com procedimento no eixo x.
  geom_col(position = "dodge") +                         # Adiciona barras.
  labs(title = "Poder explicativo adicional dos instrumentos", x = "Conjunto de instrumentos usado", y = "R² parcial dos instrumentos defasados", fill = "Produto") + # Define rótulos.
  scale_fill_produtos() +                                # Aplica paleta com nomes completos.
  theme_aids() +                                        # Aplica tema.
  theme(axis.text.x = element_text(angle = 10, hjust = 1)) # Ajusta eixo.
save_plot(p_R2, "R_25_primeira_etapa_R2_parcial")         # Salva R2 parcial.

testes <- readr::read_csv(file.path(TABLES, "testes_wald_restricoes_R.csv"), show_col_types = FALSE) # Lê testes Wald.

p_tests <- ggplot(testes, aes(teste, p_valor)) +           # Inicia gráfico de p-valores dos testes.
  geom_col(fill = "navy", alpha = 0.75) +                   # Adiciona barras no padrão do template.
  geom_hline(yintercept = 0.05, linetype = "dashed") +     # Adiciona referência 5%.
  labs(title = "p-valores dos testes de restrições", x = "Restrição", y = "p-valor") + # Define rótulos.
  theme_aids()                                             # Aplica tema.
save_plot(p_tests, "R_26_pvalores_testes_restricoes")      # Salva p-valores.
