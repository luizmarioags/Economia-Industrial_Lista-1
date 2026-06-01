################################################################################
# Arquivo: R/06_compara_resultados_R_Stata.R
# Objetivo: comparar automaticamente as tabelas geradas em R com as tabelas
#          geradas em Stata para a Lista AIDS.
################################################################################

source("R/00_config_aids.R")

normaliza_nomes <- function(x) {
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("_+", "_", x)
  x <- gsub("^_|_$", "", x)
  x
}

padroniza_tabela <- function(df) {
  names(df) <- normaliza_nomes(names(df))
  df
}


padroniza_modelos_stata <- function(df) {
  if (is.null(df) || !"modelo" %in% names(df)) return(df)
  df |>
    dplyr::mutate(
      modelo = dplyr::recode(
        modelo,
        "aids_unrestricted" = "irrestrito",
        "aids_homogeneity" = "homogeneidade",
        "aids_hsym" = "homog_simetria",
        "aids_hsym_L2" = "homog_simetria_L2",
        .default = modelo
      )
    )
}


le_csv_se_existir <- function(path) {
  if (!file.exists(path)) return(NULL)
  readr::read_csv(path, show_col_types = FALSE) |> padroniza_tabela()
}

acha_arquivo <- function(possiveis) {
  possiveis[file.exists(possiveis)][1]
}

compara_por_chaves <- function(r_df, s_df, chaves, valores, nome_saida) {
  if (is.null(r_df) || is.null(s_df)) {
    message("Pulando ", nome_saida, ": arquivo R ou Stata nao encontrado.")
    return(invisible(NULL))
  }

  chaves <- chaves[chaves %in% names(r_df) & chaves %in% names(s_df)]
  valores <- valores[valores %in% names(r_df) & valores %in% names(s_df)]

  if (length(chaves) == 0 || length(valores) == 0) {
    message("Pulando ", nome_saida, ": chaves ou valores nao encontrados em ambas as tabelas.")
    return(invisible(NULL))
  }

  r2 <- r_df |>
    dplyr::select(dplyr::all_of(c(chaves, valores))) |>
    dplyr::rename_with(~ paste0(.x, "_R"), dplyr::all_of(valores))

  s2 <- s_df |>
    dplyr::select(dplyr::all_of(c(chaves, valores))) |>
    dplyr::rename_with(~ paste0(.x, "_Stata"), dplyr::all_of(valores))

  comp <- dplyr::full_join(r2, s2, by = chaves)

  for (v in valores) {
    rcol <- paste0(v, "_R")
    scol <- paste0(v, "_Stata")
    dcol <- paste0("dif_", v)
    acol <- paste0("abs_dif_", v)
    comp[[dcol]] <- comp[[rcol]] - comp[[scol]]
    comp[[acol]] <- abs(comp[[dcol]])
  }

  readr::write_csv(comp, file.path(TABLES, nome_saida))

  resumo <- tibble::tibble(
    tabela = nome_saida,
    variavel = valores,
    max_abs_dif = purrr::map_dbl(valores, function(v) {
      col <- paste0("abs_dif_", v)
      max(comp[[col]], na.rm = TRUE)
    })
  )

  print(resumo)
  invisible(comp)
}

# -----------------------------------------------------------------------------
# Localiza arquivos do Stata.
# Ajuste os nomes abaixo caso seus CSVs do Stata tenham outro nome.
# -----------------------------------------------------------------------------

coef_R <- le_csv_se_existir(file.path(TABLES, "coeficientes_R.csv"))
coef_Stata <- le_csv_se_existir(acha_arquivo(file.path(TABLES, c(
  "coeficientes_stata.csv",
  "coeficientes_Stata.csv",
  "coeficientes_aids_stata.csv",
  "coeficientes_aids_Stata.csv"
))))

comp_R <- le_csv_se_existir(file.path(TABLES, "comparacao_modelos_R.csv"))
comp_Stata <- le_csv_se_existir(acha_arquivo(file.path(TABLES, c(
  "comparacao_modelos_stata.csv",
  "comparacao_modelos_Stata.csv",
  "comparacao_aids_stata.csv",
  "comparacao_aids_Stata.csv"
))))

em_R <- le_csv_se_existir(file.path(TABLES, "elasticidades_marshallianas_hsym_R.csv"))
em_Stata <- le_csv_se_existir(acha_arquivo(file.path(TABLES, c(
  "elasticidades_marshallianas_hsym_stata.csv",
  "elasticidades_marshallianas_hsym_Stata.csv",
  "elasticidades_marshallianas_stata.csv",
  "elasticidades_marshallianas_Stata.csv"
))))

eh_R <- le_csv_se_existir(file.path(TABLES, "elasticidades_compensadas_hsym_R.csv"))
eh_Stata <- le_csv_se_existir(acha_arquivo(file.path(TABLES, c(
  "elasticidades_compensadas_hsym_stata.csv",
  "elasticidades_compensadas_hsym_Stata.csv",
  "elasticidades_compensadas_stata.csv",
  "elasticidades_compensadas_Stata.csv"
))))

eta_R <- le_csv_se_existir(file.path(TABLES, "elasticidade_dispendio_hsym_R.csv"))
eta_Stata <- le_csv_se_existir(acha_arquivo(file.path(TABLES, c(
  "elasticidade_dispendio_hsym_stata.csv",
  "elasticidade_dispendio_hsym_Stata.csv",
  "elasticidade_dispendio_stata.csv",
  "elasticidade_dispendio_Stata.csv"
))))

coef_Stata <- padroniza_modelos_stata(coef_Stata)
comp_Stata <- padroniza_modelos_stata(comp_Stata)
em_Stata <- padroniza_modelos_stata(em_Stata)
eh_Stata <- padroniza_modelos_stata(eh_Stata)
eta_Stata <- padroniza_modelos_stata(eta_Stata)

# -----------------------------------------------------------------------------
# Comparações.
# -----------------------------------------------------------------------------

compara_por_chaves(
  coef_R, coef_Stata,
  chaves = c("modelo", "parametro"),
  valores = c("estimativa", "erro_padrao", "estat_t", "t", "z"),
  nome_saida = "comparacao_R_vs_Stata_coeficientes.csv"
)

compara_por_chaves(
  comp_R, comp_Stata,
  chaves = c("modelo"),
  valores = c("n", "n_empilhado", "parametros", "momentos", "j", "df_j", "p_j"),
  nome_saida = "comparacao_R_vs_Stata_modelos.csv"
)

# Matrizes largas: produto_linha + colunas de produtos.
compara_por_chaves(
  em_R, em_Stata,
  chaves = c("produto_linha"),
  valores = c("bfvl", "pork", "poult", "fish"),
  nome_saida = "comparacao_R_vs_Stata_elasticidades_marshallianas.csv"
)

compara_por_chaves(
  eh_R, eh_Stata,
  chaves = c("produto_linha"),
  valores = c("bfvl", "pork", "poult", "fish"),
  nome_saida = "comparacao_R_vs_Stata_elasticidades_compensadas.csv"
)

compara_por_chaves(
  eta_R, eta_Stata,
  chaves = c("produto"),
  valores = c("eta", "elasticidade_dispendio"),
  nome_saida = "comparacao_R_vs_Stata_elasticidades_dispendio.csv"
)

message("Comparacao concluida. Veja os arquivos comparacao_R_vs_Stata_*.csv em: ", TABLES)
