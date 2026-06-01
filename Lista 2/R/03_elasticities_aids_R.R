################################################################################
# Arquivo: R/03_elasticities_aids_R.R
# Objetivo: recuperar parâmetros completos e calcular matrizes de elasticidade.
# Versão Stata-like: usa as mesmas participações médias globais da base processada
#                    para avaliar as elasticidades, como no fluxo do Stata.
################################################################################

source("R/00_config_aids.R")

dados <- readRDS(file.path(PROC, "meatdata_aids_preparado_R.rds"))
model_hsym <- readRDS(file.path(MODELS, "model_hsym_R.rds"))

# -----------------------------------------------------------------------------
# Participações médias para elasticidades
# -----------------------------------------------------------------------------
# Para bater com o Stata da lista, a avaliação das elasticidades deve usar as
# participações médias globais da base processada, não apenas a amostra após
# perder a primeira observação pela defasagem L1. A diferença é pequena, mas
# suficiente para deslocar elasticidades em ~0.001 a ~0.018.
#
# Se algum dia você quiser avaliar nas médias da amostra de estimação, troque
# WBAR_SAMPLE para "estimacao".
# -----------------------------------------------------------------------------
WBAR_SAMPLE <- "full"

if (WBAR_SAMPLE == "estimacao") {
  dados_wbar <- dados %>%
    tidyr::drop_na(
      w_bfvl, w_pork, w_fish,
      ln_real_x,
      lngp_bfvl, lngp_pork, lngp_poult, lngp_fish,
      L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish
    )
} else if (WBAR_SAMPLE == "full") {
  dados_wbar <- dados %>%
    tidyr::drop_na(w_bfvl, w_pork, w_poult, w_fish)
} else {
  stop("WBAR_SAMPLE deve ser 'full' ou 'estimacao'.")
}

wbar <- dados_wbar %>%
  summarise(
    bfvl = mean(w_bfvl, na.rm = TRUE),
    pork = mean(w_pork, na.rm = TRUE),
    poult = mean(w_poult, na.rm = TRUE),
    fish = mean(w_fish, na.rm = TRUE)
  ) %>%
  unlist()

if (any(!is.finite(wbar)) || any(wbar <= 0)) {
  stop("As participações médias usadas nas elasticidades têm NA, Inf ou valor não positivo. Verifique a base processada.")
}

if (abs(sum(wbar) - 1) > 1e-8) {
  warning(sprintf("A soma das participações médias usadas nas elasticidades é %.12f, não exatamente 1.", sum(wbar)))
}

theta <- model_hsym$theta

if (is.null(names(theta))) {
  stop("model_hsym$theta está sem nomes. Não é possível recuperar alpha, beta e gamma com segurança.")
}

pega_theta <- function(nome) {
  if (!nome %in% names(theta)) {
    stop(paste0("Parâmetro ausente em model_hsym$theta: ", nome))
  }
  valor <- as.numeric(theta[[nome]])
  if (!is.finite(valor)) {
    stop(paste0("Parâmetro não finito em model_hsym$theta: ", nome))
  }
  valor
}

# Recupera parâmetros completos por adding-up.
alpha <- c(
  bfvl = pega_theta("a_bfvl"),
  pork = pega_theta("a_pork"),
  poult = 1 - pega_theta("a_bfvl") - pega_theta("a_pork") - pega_theta("a_fish"),
  fish = pega_theta("a_fish")
)

beta <- c(
  bfvl = pega_theta("b_bfvl"),
  pork = pega_theta("b_pork"),
  poult = -pega_theta("b_bfvl") - pega_theta("b_pork") - pega_theta("b_fish"),
  fish = pega_theta("b_fish")
)

G <- matrix(NA_real_, nrow = 4, ncol = 4, dimnames = list(GOODS, GOODS))

G["bfvl", "bfvl"] <- pega_theta("g11")
G["bfvl", "pork"] <- pega_theta("g12")
G["bfvl", "fish"] <- pega_theta("g14")
G["bfvl", "poult"] <- -sum(G["bfvl", c("bfvl", "pork", "fish")])

G["pork", "bfvl"] <- pega_theta("g12")
G["pork", "pork"] <- pega_theta("g22")
G["pork", "fish"] <- pega_theta("g24")
G["pork", "poult"] <- -sum(G["pork", c("bfvl", "pork", "fish")])

G["fish", "bfvl"] <- pega_theta("g14")
G["fish", "pork"] <- pega_theta("g24")
G["fish", "fish"] <- pega_theta("g44")
G["fish", "poult"] <- -sum(G["fish", c("bfvl", "pork", "fish")])

G["poult", ] <- -colSums(G[c("bfvl", "pork", "fish"), ])
G["poult", "poult"] <- -sum(G["poult", c("bfvl", "pork", "fish")])

if (anyNA(alpha) || anyNA(beta) || anyNA(G)) {
  stop("Alpha, beta ou gamma ainda têm NA. Verifique diagnostico_elasticidades_R.csv.")
}

eta <- 1 + beta[GOODS] / wbar[GOODS]

EM <- matrix(NA_real_, nrow = 4, ncol = 4, dimnames = list(GOODS, GOODS))
EH <- matrix(NA_real_, nrow = 4, ncol = 4, dimnames = list(GOODS, GOODS))

for (i in GOODS) {
  for (j in GOODS) {
    indicador <- as.numeric(i == j)
    EM[i, j] <- -indicador + G[i, j] / wbar[i] - beta[i] * wbar[j] / wbar[i]
    EH[i, j] <- EM[i, j] + eta[i] * wbar[j]
  }
}

if (anyNA(eta) || anyNA(EM) || anyNA(EH)) {
  stop("As elasticidades ainda têm NA. Verifique theta, wbar, beta e gamma no diagnóstico exportado.")
}

matrix_to_long <- function(M, name) {
  as.data.frame(M) %>%
    tibble::rownames_to_column("produto_linha") %>%
    tidyr::pivot_longer(-produto_linha, names_to = "produto_coluna", values_to = name)
}

alpha_tbl <- tibble::tibble(produto = names(alpha), alpha = as.numeric(alpha))
beta_tbl <- tibble::tibble(produto = names(beta), beta = as.numeric(beta))
wbar_tbl <- tibble::tibble(produto = names(wbar), wbar = as.numeric(wbar), amostra = WBAR_SAMPLE)
eta_tbl <- tibble::tibble(produto = names(eta), eta = as.numeric(eta))
gamma_tbl <- matrix_to_long(G, "gamma")
em_tbl <- matrix_to_long(EM, "elasticidade_marshalliana")
eh_tbl <- matrix_to_long(EH, "elasticidade_compensada")

diagnostico_elasticidades <- tibble::tibble(
  objeto = c("alpha", "beta", "wbar", "eta", "gamma", "marshalliana", "compensada"),
  n_na = c(
    sum(is.na(alpha)),
    sum(is.na(beta)),
    sum(is.na(wbar)),
    sum(is.na(eta)),
    sum(is.na(G)),
    sum(is.na(EM)),
    sum(is.na(EH))
  ),
  n_nao_finito = c(
    sum(!is.finite(alpha)),
    sum(!is.finite(beta)),
    sum(!is.finite(wbar)),
    sum(!is.finite(eta)),
    sum(!is.finite(G)),
    sum(!is.finite(EM)),
    sum(!is.finite(EH))
  )
)

readr::write_csv(diagnostico_elasticidades, file.path(TABLES, "diagnostico_elasticidades_R.csv"))
readr::write_csv(alpha_tbl, file.path(TABLES, "alpha_hsym_R.csv"))
readr::write_csv(beta_tbl, file.path(TABLES, "beta_hsym_R.csv"))
readr::write_csv(wbar_tbl, file.path(TABLES, "participacoes_medias_elast_R.csv"))
readr::write_csv(eta_tbl, file.path(TABLES, "elasticidade_dispendio_hsym_R.csv"))
readr::write_csv(as.data.frame(G) %>% tibble::rownames_to_column("produto_linha"), file.path(TABLES, "gamma_hsym_R.csv"))
readr::write_csv(as.data.frame(EM) %>% tibble::rownames_to_column("produto_linha"), file.path(TABLES, "elasticidades_marshallianas_hsym_R.csv"))
readr::write_csv(as.data.frame(EH) %>% tibble::rownames_to_column("produto_linha"), file.path(TABLES, "elasticidades_compensadas_hsym_R.csv"))
readr::write_csv(gamma_tbl, file.path(TABLES, "gamma_hsym_long_R.csv"))
readr::write_csv(em_tbl, file.path(TABLES, "elasticidades_marshallianas_hsym_long_R.csv"))
readr::write_csv(eh_tbl, file.path(TABLES, "elasticidades_compensadas_hsym_long_R.csv"))

saveRDS(
  list(alpha = alpha, beta = beta, gamma = G, wbar = wbar, eta = eta, EM = EM, EH = EH, wbar_sample = WBAR_SAMPLE),
  file.path(MODELS, "elasticidades_hsym_R.rds")
)

message("Elasticidades AIDS calculadas sem NA e salvas com sucesso. Amostra wbar: ", WBAR_SAMPLE)
