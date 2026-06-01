################################################################################
# Arquivo: R/05_diagnostico_resultados_aids_R.R
# Objetivo: diagnosticar resultados do AIDS em R: testes J, elasticidades,
# regularidade de demanda e curvatura da matriz de Slutsky.
################################################################################

source("R/00_config_aids.R")

model_unrestricted <- readRDS(file.path(MODELS, "model_unrestricted_R.rds"))
model_homogeneity  <- readRDS(file.path(MODELS, "model_homogeneity_R.rds"))
model_hsym         <- readRDS(file.path(MODELS, "model_hsym_R.rds"))
model_hsym_L2      <- readRDS(file.path(MODELS, "model_hsym_L2_R.rds"))
elasticidades      <- readRDS(file.path(MODELS, "elasticidades_hsym_R.rds"))

safe_scalar <- function(x) {
  if (length(x) == 0) return(NA_real_)
  as.numeric(x[1])
}

resumo_modelo <- function(model, nome) {
  theta <- model$theta
  se <- model$se
  tibble::tibble(
    modelo = nome,
    N_empilhado = length(model$resid),
    parametros = length(theta),
    momentos = ncol(model$design$Z),
    J = safe_scalar(model$J),
    df_J = safe_scalar(model$df_J),
    p_J = safe_scalar(model$p_J),
    max_abs_t = max(abs(theta / se), na.rm = TRUE),
    rank_X = qr(model$design$X)$rank,
    rank_Z = qr(model$design$Z)$rank,
    rank_ZX = qr(crossprod(model$design$Z, model$design$X))$rank,
    cond_ZZ = kappa(crossprod(model$design$Z)),
    cond_ZX = kappa(crossprod(model$design$Z, model$design$X))
  )
}

resumo <- dplyr::bind_rows(
  resumo_modelo(model_unrestricted, "irrestrito"),
  resumo_modelo(model_homogeneity,  "homogeneidade"),
  resumo_modelo(model_hsym,         "homog_simetria_L1"),
  resumo_modelo(model_hsym_L2,      "homog_simetria_L2")
)

# Testes por diferença de J em modelos aninhados.
Jdiff_hom <- model_homogeneity$J - model_unrestricted$J
df_hom <- model_homogeneity$df_J - model_unrestricted$df_J
Jdiff_sym_cond <- model_hsym$J - model_homogeneity$J
df_sym_cond <- model_hsym$df_J - model_homogeneity$df_J

testes_J_diff <- tibble::tibble(
  teste = c("Homogeneidade contra irrestrito", "Simetria adicional dado homogeneidade"),
  estatistica = c(Jdiff_hom, Jdiff_sym_cond),
  gl = c(df_hom, df_sym_cond),
  p_valor = stats::pchisq(c(Jdiff_hom, Jdiff_sym_cond), c(df_hom, df_sym_cond), lower.tail = FALSE)
)

# Diagnóstico das elasticidades principais.
eta <- elasticidades$eta
EM <- elasticidades$EM
EH <- elasticidades$EH
wbar <- elasticidades$wbar

diag_elast <- tibble::tibble(
  produto = names(eta),
  elasticidade_dispendio = as.numeric(eta),
  marshalliana_propria = diag(EM),
  compensada_propria = diag(EH),
  problema_dispendio_negativo = elasticidade_dispendio < 0,
  problema_preco_proprio_marshalliano_positivo = marshalliana_propria > 0,
  problema_preco_proprio_compensado_positivo = compensada_propria > 0
)

# Simetria de Slutsky em termos de participações: w_i * EH_ij deve ser simétrica.
S_slutsky <- sweep(EH, 1, wbar, `*`)
max_assimetria_slutsky <- max(abs(S_slutsky - t(S_slutsky)), na.rm = TRUE)
autovalores_slutsky <- eigen((S_slutsky + t(S_slutsky)) / 2, symmetric = TRUE, only.values = TRUE)$values

regularidade <- tibble::tibble(
  criterio = c(
    "max_assimetria_wi_EHij",
    paste0("autovalor_slutsky_", seq_along(autovalores_slutsky)),
    "curvatura_negativa_semidefinida"
  ),
  valor = c(
    max_assimetria_slutsky,
    autovalores_slutsky,
    as.numeric(all(autovalores_slutsky <= 1e-8))
  )
)

readr::write_csv(resumo, file.path(TABLES, "diagnostico_modelos_R.csv"))
readr::write_csv(testes_J_diff, file.path(TABLES, "diagnostico_testes_J_diff_R.csv"))
readr::write_csv(diag_elast, file.path(TABLES, "diagnostico_elasticidades_economicidade_R.csv"))
readr::write_csv(regularidade, file.path(TABLES, "diagnostico_regularidade_R.csv"))

print(resumo)
print(testes_J_diff)
print(diag_elast)
print(regularidade)
