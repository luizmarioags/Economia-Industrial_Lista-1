################################################################################
# Arquivo: R/01_prepare_aids_data.R
# Objetivo: preparar a base para o sistema AIDS.
################################################################################

source("R/00_config_aids.R")                         # Carrega configuração do projeto.

dados_raw <- readr::read_csv(RAW_CSV, show_col_types = FALSE) # Lê a base bruta em CSV.

dados <- dados_raw %>%                               # Inicia pipeline de preparação.
  arrange(year)                                      # Ordena a base por ano.

for (g in GOODS) {                                   # Percorre os quatro produtos.
  x_name <- paste0("x", g)                           # Define nome da variável de dispêndio.
  p_name <- paste0(g, "p")                           # Define nome da variável de preço.
  q_name <- paste0(g, "q")                           # Define nome da variável de quantidade.
  if (!x_name %in% names(dados)) {                   # Verifica se o dispêndio não existe.
    dados[[x_name]] <- dados[[p_name]] * dados[[q_name]] # Cria dispêndio como preço vezes quantidade.
  }                                                  # Fecha condição de criação do dispêndio.
}                                                    # Fecha loop de dispêndios.

dados <- dados %>%                                   # Continua preparação.
  mutate(                                            # Cria novas variáveis.
    xtotal_calc = xbfvl + xpork + xpoult + xfish,    # Calcula dispêndio total condicional com carnes.
    w_bfvl = xbfvl / xtotal_calc,                    # Calcula participação de bfvl.
    w_pork = xpork / xtotal_calc,                    # Calcula participação de pork.
    w_poult = xpoult / xtotal_calc,                  # Calcula participação de poult.
    w_fish = xfish / xtotal_calc,                    # Calcula participação de fish.
    share_sum = w_bfvl + w_pork + w_poult + w_fish,  # Soma participações.
    share_gap = share_sum - 1,                       # Mede desvio em relação a 1.
    share_problem = abs(share_gap) > 1e-8            # Marca problema de soma das participações.
  )                                                  # Fecha criação das variáveis.

if ("xtotal" %in% names(dados)) {                    # Verifica se a base original tem xtotal.
  dados <- dados %>% mutate(diff_xtotal = xtotal_calc - xtotal) # Compara xtotal reconstruído e original.
}                                                    # Fecha condição sobre xtotal.

for (g in GOODS) {                                   # Percorre cada produto.
  p_name <- paste0(g, "p")                           # Define nome do preço.
  ln_name <- paste0("ln_p_", g)                      # Define nome do log-preço.
  lngp_name <- paste0("lngp_", g)                    # Define nome do log-preço normalizado.
  dados[[ln_name]] <- log(dados[[p_name]])           # Calcula log-preço.
  dados[[lngp_name]] <- dados[[ln_name]] - mean(dados[[ln_name]], na.rm = TRUE) # Retira média temporal do log-preço.
}                                                    # Fecha loop dos log-preços.

wbar <- dados %>%                                    # Inicia cálculo de participações médias.
  summarise(                                         # Resume as participações.
    bfvl = mean(w_bfvl, na.rm = TRUE),               # Calcula participação média de bfvl.
    pork = mean(w_pork, na.rm = TRUE),               # Calcula participação média de pork.
    poult = mean(w_poult, na.rm = TRUE),             # Calcula participação média de poult.
    fish = mean(w_fish, na.rm = TRUE)                # Calcula participação média de fish.
  ) %>%                                              # Fecha summarise.
  as.list()                                          # Converte para lista nomeada.

dados <- dados %>%                                   # Continua preparação.
  mutate(                                            # Cria índice e escala real.
    wbar_bfvl = wbar$bfvl,                           # Armazena participação média de bfvl.
    wbar_pork = wbar$pork,                           # Armazena participação média de pork.
    wbar_poult = wbar$poult,                         # Armazena participação média de poult.
    wbar_fish = wbar$fish,                           # Armazena participação média de fish.
    lnP_stone = wbar$bfvl * ln_p_bfvl +              # Inicia índice de Stone com bfvl.
      wbar$pork * ln_p_pork +                        # Adiciona parcela de pork.
      wbar$poult * ln_p_poult +                      # Adiciona parcela de poult.
      wbar$fish * ln_p_fish,                         # Adiciona parcela de fish.
    ln_xtotal = log(xtotal_calc),                    # Calcula log do dispêndio total.
    ln_real_x = ln_xtotal - lnP_stone                # Calcula log(x/P^S).
  )                                                  # Fecha mutate.

if ("pce" %in% names(dados)) {                       # Verifica se existe PCE.
  dados <- dados %>% mutate(meat_pce_share = xtotal_calc / pce) # Calcula peso de carnes no PCE.
}                                                    # Fecha condição de PCE.

for (g in GOODS) {                                   # Percorre produtos para diferenças contra poult.
  d_name <- paste0("d_", g, "_poult")                # Define nome da diferença.
  dados[[d_name]] <- dados[[paste0("lngp_", g)]] - dados[["lngp_poult"]] # Calcula diferença contra frango.
}                                                    # Fecha loop das diferenças.

for (g in GOODS) {                                   # Percorre produtos para defasagens.
  lngp_name <- paste0("lngp_", g)                    # Define nome do log-preço normalizado.
  dados[[paste0("L1_lngp_", g)]] <- dplyr::lag(dados[[lngp_name]], 1) # Cria primeira defasagem.
  dados[[paste0("L2_lngp_", g)]] <- dplyr::lag(dados[[lngp_name]], 2) # Cria segunda defasagem.
}                                                    # Fecha loop das defasagens.

for (g in EST_GOODS) {                               # Percorre equações estimadas.
  dados[[paste0("y_", g)]] <- dados[[paste0("w_", g)]] # Cria variável dependente como alias da participação.
}                                                    # Fecha loop das dependentes.

participacoes_medias <- tibble::tibble(             # Cria tabela de participações médias.
  produto = GOODS,                                   # Insere nomes dos produtos.
  wbar = unlist(wbar[GOODS])                         # Insere participações médias.
)                                                    # Fecha tabela.

readr::write_csv(dados, PROC_CSV)                    # Salva base processada em CSV.
readr::write_csv(participacoes_medias, file.path(TABLES, "participacoes_medias_R.csv")) # Salva participações médias.

diagnostico_soma <- dados %>%                        # Inicia tabela de diagnóstico da soma.
  summarise(                                         # Resume a checagem.
    min_share_sum = min(share_sum, na.rm = TRUE),    # Guarda menor soma das participações.
    max_share_sum = max(share_sum, na.rm = TRUE),    # Guarda maior soma das participações.
    max_abs_gap = max(abs(share_gap), na.rm = TRUE), # Guarda maior desvio absoluto.
    n_problem = sum(share_problem, na.rm = TRUE)     # Conta anos problemáticos.
  )                                                  # Fecha summarise.

readr::write_csv(diagnostico_soma, file.path(TABLES, "diagnostico_soma_participacoes_R.csv")) # Salva diagnóstico da soma.
saveRDS(dados, file.path(PROC, "meatdata_aids_preparado_R.rds")) # Salva base processada em RDS.
