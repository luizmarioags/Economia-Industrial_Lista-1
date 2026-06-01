################################################################################
# Arquivo: R/07_resumo_comparacao_R_Stata.R
# Objetivo: resumir diferenças máximas entre resultados R e Stata já comparados.
################################################################################

source("R/00_config_aids.R")

ler_se_existe <- function(nome) {
  arq <- file.path(TABLES, nome)
  if (!file.exists(arq)) {
    message("Arquivo não encontrado: ", arq)
    return(NULL)
  }
  readr::read_csv(arq, show_col_types = FALSE)
}

coef <- ler_se_existe("comparacao_R_vs_Stata_coeficientes.csv")
eta  <- ler_se_existe("comparacao_R_vs_Stata_elasticidades_dispendio.csv")
em   <- ler_se_existe("comparacao_R_vs_Stata_elasticidades_marshallianas.csv")
eh   <- ler_se_existe("comparacao_R_vs_Stata_elasticidades_compensadas.csv")

resumos <- list()

if (!is.null(coef)) {
  resumos[["coeficientes"]] <- coef %>%
    dplyr::group_by(modelo) %>%
    dplyr::summarise(
      max_abs_dif_estimativa = max(abs_dif_estimativa, na.rm = TRUE),
      max_abs_dif_erro_padrao = max(abs_dif_erro_padrao, na.rm = TRUE),
      max_abs_dif_estat_t = max(abs_dif_estat_t, na.rm = TRUE),
      .groups = "drop"
    )
}

if (!is.null(eta)) {
  resumos[["elasticidade_dispendio"]] <- tibble::tibble(
    objeto = "elasticidade_dispendio",
    max_abs_dif = max(eta$abs_dif_eta, na.rm = TRUE)
  )
}

max_dif_matriz <- function(df, nome) {
  cols <- grep("^abs_dif_", names(df), value = TRUE)
  tibble::tibble(
    objeto = nome,
    max_abs_dif = max(as.matrix(df[, cols]), na.rm = TRUE)
  )
}

if (!is.null(em)) resumos[["marshallianas"]] <- max_dif_matriz(em, "marshallianas")
if (!is.null(eh)) resumos[["compensadas"]] <- max_dif_matriz(eh, "compensadas")

saida <- dplyr::bind_rows(resumos, .id = "grupo")
readr::write_csv(saida, file.path(TABLES, "resumo_comparacao_R_vs_Stata.csv"))
print(saida)
