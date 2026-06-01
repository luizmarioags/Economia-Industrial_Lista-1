################################################################################
# Arquivo: R/02_estimate_aids_R.R
# Objetivo: estimar diretamente o sistema AIDS por GMM linear empilhado, em modo Stata-like com matriz unadjusted em dois passos.
################################################################################

source("R/00_config_aids.R")                         # Carrega configuração do projeto.

dados <- readRDS(file.path(PROC, "meatdata_aids_preparado_R.rds")) # Abre base processada.
dados$const <- 1                                     # Cria instrumento constante para identificar interceptos.

matrix_rank <- function(A, tol = 1e-10) {        # Calcula posto numérico por QR.
  qr(A, tol = tol)$rank
}                                                    # Fecha função matrix_rank.

safe_solve <- function(A, tol = 1e-10, ridge = 1e-8) { # Define inversa robusta para matrizes quase singulares.
  A <- as.matrix(A)                                  # Garante formato matricial.
  if (nrow(A) != ncol(A)) {                          # Verifica se a matriz é quadrada.
    stop("safe_solve exige matriz quadrada.")        # Interrompe se a matriz não puder ser invertida.
  }                                                  # Fecha verificação.
  I <- diag(nrow(A))                                 # Cria matriz identidade compatível.
  tentativa_qr <- tryCatch(                          # Tenta inversão por QR primeiro.
    qr.solve(A, I, tol = tol),                       # Resolve A X = I.
    error = function(e) NULL                         # Em caso de singularidade, segue para fallback.
  )                                                  # Fecha tryCatch.
  if (!is.null(tentativa_qr) && all(is.finite(tentativa_qr))) { # Verifica se QR funcionou.
    return(tentativa_qr)                             # Retorna inversa por QR.
  }                                                  # Fecha condição.
  escala <- max(abs(diag(A)), na.rm = TRUE)          # Usa escala diagonal para ridge.
  if (!is.finite(escala) || escala == 0) escala <- max(abs(A), na.rm = TRUE) # Fallback para escala global.
  if (!is.finite(escala) || escala == 0) escala <- 1 # Evita escala nula.
  A_ridge <- A + diag(ridge * escala, nrow(A))       # Regulariza levemente a diagonal.
  tentativa_ridge <- tryCatch(                       # Tenta resolver a matriz regularizada.
    qr.solve(A_ridge, I, tol = tol),                 # Resolve com ridge.
    error = function(e) NULL                         # Em caso de falha, usa SVD.
  )                                                  # Fecha tryCatch.
  if (!is.null(tentativa_ridge) && all(is.finite(tentativa_ridge))) { # Verifica se ridge funcionou.
    return(tentativa_ridge)                          # Retorna inversa regularizada.
  }                                                  # Fecha condição.
  sv <- svd(A)                                       # Calcula decomposição em valores singulares.
  if (length(sv$d) == 0 || max(sv$d) == 0) {         # Verifica caso degenerado.
    return(matrix(0, nrow(A), ncol(A)))              # Retorna pseudo-inversa nula.
  }                                                  # Fecha condição.
  keep <- sv$d > tol * max(sv$d)                     # Mantém apenas valores singulares relevantes.
  if (!any(keep)) {                                  # Verifica se sobrou algum componente.
    return(matrix(0, nrow(A), ncol(A)))              # Retorna pseudo-inversa nula.
  }                                                  # Fecha condição.
  D_inv <- diag(1 / sv$d[keep], nrow = sum(keep), ncol = sum(keep)) # Inverte valores singulares retidos.
  sv$v[, keep, drop = FALSE] %*% D_inv %*% t(sv$u[, keep, drop = FALSE]) # Retorna pseudo-inversa por SVD.
}                                                    # Fecha função de inversão robusta.

make_block_Z <- function(data, inst_names) {          # Define função para montar matriz de instrumentos por equação.
  n <- nrow(data)                                     # Guarda número de períodos.
  e <- length(EST_GOODS)                              # Guarda número de equações estimadas.
  q <- length(inst_names)                             # Guarda número de instrumentos por equação.
  Z <- matrix(0, nrow = n * e, ncol = q * e)          # Cria matriz de instrumentos em blocos.
  colnames(Z) <- unlist(lapply(EST_GOODS, function(eq) paste(eq, inst_names, sep = ":"))) # Nomeia instrumentos por bloco de equação.
  for (i in seq_along(EST_GOODS)) {                   # Percorre equações estimadas.
    rows <- ((i - 1) * n + 1):(i * n)                 # Define linhas da equação i.
    cols <- ((i - 1) * q + 1):(i * q)                 # Define colunas de instrumentos da equação i.
    Z[rows, cols] <- as.matrix(data[, inst_names])    # Insere instrumentos apenas no bloco da equação i.
  }                                                   # Fecha loop das equações.
  Z                                                   # Retorna matriz de instrumentos.
}                                                     # Fecha função make_block_Z.

build_design <- function(data, spec, inst_names) {    # Define função que monta y, X e Z.
  n <- nrow(data)                                     # Guarda número de períodos.
  y <- unlist(lapply(EST_GOODS, function(g) data[[paste0("w_", g)]])) # Empilha participações observadas.
  Z <- make_block_Z(data, inst_names)                 # Constrói instrumentos em bloco.
  if (spec == "unrestricted") {                       # Verifica se a especificação é irrestrita.
    param_names <- unlist(lapply(EST_GOODS, function(eq) c(paste0("a_", eq), paste0("g", eq, "_", GOODS), paste0("b_", eq)))) # Define parâmetros livres.
    X <- matrix(0, nrow = n * length(EST_GOODS), ncol = length(param_names)) # Cria matriz de regressores.
    colnames(X) <- param_names                        # Nomeia colunas de X.
    for (i in seq_along(EST_GOODS)) {                 # Percorre equações estimadas.
      eq <- EST_GOODS[i]                              # Guarda nome da equação.
      rows <- ((i - 1) * n + 1):(i * n)               # Define linhas da equação.
      X[rows, paste0("a_", eq)] <- 1                  # Insere intercepto da equação.
      for (g in GOODS) {                              # Percorre preços dos quatro produtos.
        X[rows, paste0("g", eq, "_", g)] <- data[[paste0("lngp_", g)]] # Insere log-preço normalizado.
      }                                               # Fecha loop dos preços.
      X[rows, paste0("b_", eq)] <- data$ln_real_x     # Insere dispêndio real.
    }                                                 # Fecha loop das equações.
  } else if (spec == "homogeneity") {                 # Verifica se a especificação impõe homogeneidade.
    free_price_goods <- c("bfvl", "pork", "fish")     # Define preços livres ao substituir poult.
    param_names <- unlist(lapply(EST_GOODS, function(eq) c(paste0("a_", eq), paste0("g", eq, "_", free_price_goods), paste0("b_", eq)))) # Define parâmetros livres.
    X <- matrix(0, nrow = n * length(EST_GOODS), ncol = length(param_names)) # Cria matriz X.
    colnames(X) <- param_names                        # Nomeia colunas de X.
    for (i in seq_along(EST_GOODS)) {                 # Percorre equações estimadas.
      eq <- EST_GOODS[i]                              # Guarda equação.
      rows <- ((i - 1) * n + 1):(i * n)               # Define linhas da equação.
      X[rows, paste0("a_", eq)] <- 1                  # Insere intercepto.
      for (g in free_price_goods) {                   # Percorre preços livres.
        X[rows, paste0("g", eq, "_", g)] <- data[[paste0("lngp_", g)]] - data$lngp_poult # Usa diferença contra poult.
      }                                               # Fecha loop dos preços livres.
      X[rows, paste0("b_", eq)] <- data$ln_real_x     # Insere dispêndio real.
    }                                                 # Fecha loop das equações.
  } else if (spec == "hsym") {                        # Verifica se a especificação impõe homogeneidade e simetria.
    param_names <- c("a_bfvl", "a_pork", "a_fish", "g11", "g12", "g14", "g22", "g24", "g44", "b_bfvl", "b_pork", "b_fish") # Define parâmetros livres.
    X <- matrix(0, nrow = n * length(EST_GOODS), ncol = length(param_names)) # Cria matriz X.
    colnames(X) <- param_names                        # Nomeia colunas de X.
    d1 <- data$lngp_bfvl - data$lngp_poult            # Calcula diferença de preço bfvl contra poult.
    d2 <- data$lngp_pork - data$lngp_poult            # Calcula diferença de preço pork contra poult.
    d4 <- data$lngp_fish - data$lngp_poult            # Calcula diferença de preço fish contra poult.
    rows1 <- 1:n                                      # Define linhas da equação bfvl.
    rows2 <- (n + 1):(2 * n)                          # Define linhas da equação pork.
    rows4 <- (2 * n + 1):(3 * n)                      # Define linhas da equação fish.
    X[rows1, "a_bfvl"] <- 1                           # Insere intercepto de bfvl.
    X[rows1, "g11"] <- d1                             # Insere gamma 11 em bfvl.
    X[rows1, "g12"] <- d2                             # Insere gamma 12 em bfvl.
    X[rows1, "g14"] <- d4                             # Insere gamma 14 em bfvl.
    X[rows1, "b_bfvl"] <- data$ln_real_x              # Insere beta de bfvl.
    X[rows2, "a_pork"] <- 1                           # Insere intercepto de pork.
    X[rows2, "g12"] <- d1                             # Insere gamma 12 em pork por simetria.
    X[rows2, "g22"] <- d2                             # Insere gamma 22 em pork.
    X[rows2, "g24"] <- d4                             # Insere gamma 24 em pork.
    X[rows2, "b_pork"] <- data$ln_real_x              # Insere beta de pork.
    X[rows4, "a_fish"] <- 1                           # Insere intercepto de fish.
    X[rows4, "g14"] <- d1                             # Insere gamma 14 em fish por simetria.
    X[rows4, "g24"] <- d2                             # Insere gamma 24 em fish por simetria.
    X[rows4, "g44"] <- d4                             # Insere gamma 44 em fish.
    X[rows4, "b_fish"] <- data$ln_real_x              # Insere beta de fish.
  } else {                                           # Trata especificação inválida.
    stop("Especificacao desconhecida.")              # Interrompe com erro claro.
  }                                                  # Fecha bloco de especificações.
  list(y = as.numeric(y), X = X, Z = Z, spec = spec, inst_names = inst_names, design_data = data) # Retorna desenho completo.
}                                                     # Fecha função build_design.

estimate_linear_gmm <- function(design) {            # Define estimador GMM linear no padrão do Stata.
  y <- design$y                                       # Extrai variável dependente empilhada.
  X <- design$X                                       # Extrai matriz de regressores.
  Z <- design$Z                                       # Extrai matriz de instrumentos empilhada em blocos.
  inst_names <- design$inst_names                     # Guarda nomes dos instrumentos.
  e <- length(EST_GOODS)                              # Número de equações estimadas.
  q <- length(inst_names)                             # Número de instrumentos por equação.
  n_periodos <- length(y) / e                         # Número de períodos da amostra.
  k <- ncol(X)                                        # Número de parâmetros.

  # ---------------------------------------------------------------------------
  # Ponto essencial para bater com o Stata:
  # O comando Stata usado na lista é:
  #   winitial(unadjusted, independent) wmatrix(unadjusted) twostep
  #
  # A matriz inicial "unadjusted, independent" equivale a usar uma matriz
  # de ponderação independente entre equações:
  #   W1 = I_e \otimes (Z0'Z0/n)^(-1)
  #
  # No segundo passo, "wmatrix(unadjusted)" permite a covariância contemporânea
  # entre os resíduos das equações. Com os mesmos instrumentos em cada equação,
  # isso equivale a:
  #   W2 = (Sigma_u \otimes (Z0'Z0/n))^(-1),
  # em que Sigma_u é a matriz de covariância dos resíduos do primeiro passo.
  #
  # A versão anterior usava apenas (Z'Z/n)^(-1). Isso reproduz os modelos sem
  # parâmetros compartilhados entre equações, mas não reproduz corretamente o
  # modelo com homogeneidade + simetria, pois nesse modelo alguns gammas aparecem
  # simultaneamente em mais de uma equação.
  # ---------------------------------------------------------------------------

  Z0 <- as.matrix(design$design_data[, inst_names, drop = FALSE]) # Instrumentos não empilhados.
  Qz <- crossprod(Z0) / n_periodos                                # Matriz Z0'Z0/n.

  W1 <- safe_solve(kronecker(diag(e), Qz))             # Ponderação inicial independente entre equações.

  A1 <- t(X) %*% Z %*% W1 %*% t(Z) %*% X              # Matriz normal do primeiro passo.
  b1 <- t(X) %*% Z %*% W1 %*% t(Z) %*% y              # Vetor normal do primeiro passo.
  theta1 <- as.numeric(safe_solve(A1) %*% b1)         # Estimador inicial.
  resid1 <- as.numeric(y - X %*% theta1)              # Resíduos do primeiro passo.

  U1 <- matrix(resid1, nrow = n_periodos, ncol = e, byrow = FALSE) # Resíduos em matriz T x equações.
  Sigma_u <- crossprod(U1) / n_periodos                            # Covariância contemporânea entre equações.

  S2 <- kronecker(Sigma_u, Qz)                       # Matriz unadjusted dos momentos no segundo passo.
  W2 <- safe_solve(S2)                               # Ponderação final no padrão Stata.

  A2 <- t(X) %*% Z %*% W2 %*% t(Z) %*% X             # Matriz normal do segundo passo.
  b2 <- t(X) %*% Z %*% W2 %*% t(Z) %*% y             # Vetor normal do segundo passo.
  theta2 <- as.numeric(safe_solve(A2) %*% b2)        # Estimador GMM em dois passos.
  resid2 <- as.numeric(y - X %*% theta2)             # Resíduos finais.

  U2 <- matrix(resid2, nrow = n_periodos, ncol = e, byrow = FALSE) # Resíduos finais em matriz T x equações.

  gbar <- unlist(lapply(seq_len(e), function(j) {     # Médias dos momentos, na ordem eq1 instrumentos, eq2 instrumentos...
    as.numeric(crossprod(Z0, U2[, j]) / n_periodos)
  }))

  D <- t(Z) %*% X / n_periodos                       # Jacobiano amostral dos momentos.
  bread <- safe_solve(t(D) %*% W2 %*% D)             # Inversa da matriz de informação.

  # Erro-padrão unadjusted no padrão GMM. A escala aqui é a de períodos, não a
  # de observações empilhadas, porque o Stata reporta Number of obs = T.
  V <- bread / n_periodos
  diag_V <- diag(V)
  se <- sqrt(ifelse(diag_V >= 0, diag_V, NA_real_))

  J <- as.numeric(n_periodos * t(gbar) %*% W2 %*% gbar) # Estatística J no padrão do Stata.
  df_J <- ncol(Z) - ncol(X)                             # Graus de liberdade de sobreidentificação.
  p_J <- ifelse(df_J > 0, stats::pchisq(J, df_J, lower.tail = FALSE), NA_real_)

  names(theta2) <- colnames(X)                       # Nomeia estimativas.
  names(se) <- colnames(X)                           # Nomeia erros-padrão.

  list(
    theta = theta2,
    se = se,
    V = V,
    resid = resid2,
    fitted = as.numeric(X %*% theta2),
    J = J,
    df_J = df_J,
    p_J = p_J,
    design = design,
    n_periodos = n_periodos,
    Sigma_u = Sigma_u
  )
}                                                     # Fecha estimador GMM.

coef_table <- function(model, model_name) {           # Define função para tabela de coeficientes.
  tibble::tibble(                                     # Cria tibble.
    modelo = model_name,                              # Insere nome do modelo.
    parametro = names(model$theta),                   # Insere nome do parâmetro.
    estimativa = as.numeric(model$theta),             # Insere estimativa.
    erro_padrao = as.numeric(model$se),               # Insere erro-padrão.
    estat_t = estimativa / erro_padrao                # Calcula estatística t.
  )                                                   # Fecha tibble.
}                                                     # Fecha função de tabela.

data_L1 <- dados %>%                                  # Cria amostra com instrumentos L1.
  tidyr::drop_na(w_bfvl, w_pork, w_fish, ln_real_x, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish) # Remove missings L1.

data_L2 <- dados %>%                                  # Cria amostra alternativa com L1 e L2.
  tidyr::drop_na(w_bfvl, w_pork, w_fish, ln_real_x, lngp_bfvl, lngp_pork, lngp_poult, lngp_fish, L1_lngp_bfvl, L1_lngp_pork, L1_lngp_poult, L1_lngp_fish, L2_lngp_bfvl, L2_lngp_pork, L2_lngp_poult, L2_lngp_fish) # Remove missings L2.

inst_L1 <- c("const", "ln_real_x", "L1_lngp_bfvl", "L1_lngp_pork", "L1_lngp_poult", "L1_lngp_fish") # Define instrumentos principais, incluindo constante para interceptos.
inst_L2 <- c("const", "ln_real_x", "L1_lngp_bfvl", "L1_lngp_pork", "L1_lngp_poult", "L1_lngp_fish", "L2_lngp_bfvl", "L2_lngp_pork", "L2_lngp_poult", "L2_lngp_fish") # Define instrumentos ampliados, incluindo constante.

check_design <- function(design, model_name) {       # Cria diagnóstico de identificação do desenho GMM.
  ZX <- t(design$Z) %*% design$X                     # Calcula matriz dos momentos cruzados.
  rank_Z <- matrix_rank(design$Z)                    # Calcula posto de Z.
  rank_ZX <- matrix_rank(ZX)                         # Calcula posto de Z'X.
  parametros <- ncol(design$X)                       # Conta parâmetros.
  momentos <- ncol(design$Z)                         # Conta momentos.
  identificado <- rank_ZX >= parametros              # Verifica condição de identificação local.
  if (!identificado) {                               # Se ainda houver subidentificação.
    warning(                                         # Emite alerta sem interromper a execução.
      paste0(
        "Modelo ", model_name, " possivelmente subidentificado: ",
        "rank(Z'X)=", rank_ZX, ", parametros=", parametros, "."
      )
    )                                                # Fecha warning.
  }                                                  # Fecha condição.
  tibble::tibble(                                    # Retorna tabela de diagnóstico.
    modelo = model_name,
    N_empilhado = nrow(design$X),
    parametros = parametros,
    momentos = momentos,
    rank_Z = rank_Z,
    rank_ZX = rank_ZX,
    identificado = identificado
  )                                                  # Fecha tibble.
}                                                    # Fecha função check_design.

design_unrestricted <- build_design(data_L1, "unrestricted", inst_L1) # Monta desenho do modelo irrestrito.
design_homogeneity <- build_design(data_L1, "homogeneity", inst_L1) # Monta desenho do modelo homogêneo.
design_hsym <- build_design(data_L1, "hsym", inst_L1)               # Monta desenho do modelo homogêneo e simétrico.
design_hsym_L2 <- build_design(data_L2, "hsym", inst_L2)            # Monta desenho do modelo final com L1 e L2.

diagnostico_identificacao <- dplyr::bind_rows(       # Junta diagnósticos de identificação antes da estimação.
  check_design(design_unrestricted, "irrestrito"),
  check_design(design_homogeneity, "homogeneidade"),
  check_design(design_hsym, "homog_simetria"),
  check_design(design_hsym_L2, "homog_simetria_L2")
)                                                    # Fecha diagnóstico.

model_unrestricted <- estimate_linear_gmm(design_unrestricted) # Estima modelo irrestrito.
model_homogeneity <- estimate_linear_gmm(design_homogeneity)   # Estima modelo homogêneo.
model_hsym <- estimate_linear_gmm(design_hsym)                 # Estima modelo homogêneo e simétrico.
model_hsym_L2 <- estimate_linear_gmm(design_hsym_L2)           # Estima modelo final com L1 e L2.

coeficientes <- dplyr::bind_rows(                     # Junta tabelas de coeficientes.
  coef_table(model_unrestricted, "irrestrito"),       # Adiciona modelo irrestrito.
  coef_table(model_homogeneity, "homogeneidade"),     # Adiciona modelo homogêneo.
  coef_table(model_hsym, "homog_simetria"),           # Adiciona modelo final.
  coef_table(model_hsym_L2, "homog_simetria_L2")      # Adiciona modelo com L2.
)                                                     # Fecha junção.

model_comparison <- tibble::tibble(                   # Cria tabela de comparação de modelos.
  modelo = c("irrestrito", "homogeneidade", "homog_simetria", "homog_simetria_L2"), # Nomeia modelos.
  N = c(model_unrestricted$n_periodos, model_homogeneity$n_periodos, model_hsym$n_periodos, model_hsym_L2$n_periodos), # Conta períodos, como no Stata.
  N_empilhado = c(length(model_unrestricted$resid), length(model_homogeneity$resid), length(model_hsym$resid), length(model_hsym_L2$resid)), # Conta observações empilhadas.
  parametros = c(length(model_unrestricted$theta), length(model_homogeneity$theta), length(model_hsym$theta), length(model_hsym_L2$theta)), # Conta parâmetros.
  momentos = c(ncol(model_unrestricted$design$Z), ncol(model_homogeneity$design$Z), ncol(model_hsym$design$Z), ncol(model_hsym_L2$design$Z)), # Conta momentos.
  J = c(model_unrestricted$J, model_homogeneity$J, model_hsym$J, model_hsym_L2$J), # Salva estatística J.
  df_J = c(model_unrestricted$df_J, model_homogeneity$df_J, model_hsym$df_J, model_hsym_L2$df_J), # Salva graus de liberdade.
  p_J = c(model_unrestricted$p_J, model_homogeneity$p_J, model_hsym$p_J, model_hsym_L2$p_J) # Salva p-valor.
) %>%                                                 # Fecha tabela de comparação e continua pipeline.
  dplyr::left_join(                                   # Junta diagnóstico de identificação.
    diagnostico_identificacao %>% dplyr::select(modelo, rank_Z, rank_ZX, identificado),
    by = "modelo"
  )                                                   # Fecha tabela de comparação.

wald_test <- function(model, R, r, nome) {            # Define teste de Wald linear.
  theta <- matrix(model$theta, ncol = 1)              # Converte estimativas em vetor coluna.
  diff <- R %*% theta - matrix(r, ncol = 1)           # Calcula restrições avaliadas.
  V_R <- R %*% model$V %*% t(R)                       # Calcula variância das restrições.
  W <- as.numeric(t(diff) %*% safe_solve(V_R) %*% diff) # Calcula estatística Wald.
  df <- nrow(R)                                       # Guarda graus de liberdade.
  p <- stats::pchisq(W, df, lower.tail = FALSE)       # Calcula p-valor.
  tibble::tibble(teste = nome, estatistica = W, gl = df, p_valor = p) # Retorna resultado.
}                                                     # Fecha função de Wald.

pnames <- names(model_unrestricted$theta)             # Guarda nomes dos parâmetros irrestritos.
R_hom <- matrix(0, nrow = 3, ncol = length(pnames), dimnames = list(NULL, pnames)) # Cria matriz R de homogeneidade.
R_hom[1, c("gbfvl_bfvl", "gbfvl_pork", "gbfvl_poult", "gbfvl_fish")] <- 1 # Impõe soma gamma bfvl.
R_hom[2, c("gpork_bfvl", "gpork_pork", "gpork_poult", "gpork_fish")] <- 1 # Impõe soma gamma pork.
R_hom[3, c("gfish_bfvl", "gfish_pork", "gfish_poult", "gfish_fish")] <- 1 # Impõe soma gamma fish.

R_sym <- matrix(0, nrow = 3, ncol = length(pnames), dimnames = list(NULL, pnames)) # Cria matriz R de simetria.
R_sym[1, "gbfvl_pork"] <- 1                         # Coloca gamma bfvl,pork na restrição.
R_sym[1, "gpork_bfvl"] <- -1                         # Subtrai gamma pork,bfvl.
R_sym[2, "gbfvl_fish"] <- 1                          # Coloca gamma bfvl,fish na restrição.
R_sym[2, "gfish_bfvl"] <- -1                         # Subtrai gamma fish,bfvl.
R_sym[3, "gpork_fish"] <- 1                          # Coloca gamma pork,fish na restrição.
R_sym[3, "gfish_pork"] <- -1                         # Subtrai gamma fish,pork.

testes_wald <- dplyr::bind_rows(                     # Junta testes de Wald.
  wald_test(model_unrestricted, R_hom, rep(0, 3), "Homogeneidade"), # Testa homogeneidade.
  wald_test(model_unrestricted, R_sym, rep(0, 3), "Simetria")       # Testa simetria.
)                                                     # Fecha tabela de testes.

first_stage <- function(data, instruments, label) {   # Define função de diagnóstico da primeira etapa.
  instruments_lm <- setdiff(instruments, "const")    # Remove constante porque lm já inclui intercepto.
  purrr::map_dfr(GOODS, function(g) {                 # Percorre cada preço.
    y_name <- paste0("lngp_", g)                      # Define variável dependente da primeira etapa.
    full_formula <- as.formula(paste(y_name, "~", paste(instruments_lm, collapse = " + "))) # Monta fórmula completa.
    red_formula <- as.formula(paste(y_name, "~ ln_real_x")) # Monta fórmula reduzida.
    fit_full <- stats::lm(full_formula, data = data)  # Estima primeira etapa completa.
    fit_red <- stats::lm(red_formula, data = data)    # Estima primeira etapa reduzida.
    an <- stats::anova(fit_red, fit_full)             # Compara modelo reduzido e completo.
    r2_full <- summary(fit_full)$r.squared            # Extrai R2 completo.
    r2_red <- summary(fit_red)$r.squared              # Extrai R2 reduzido.
    tibble::tibble(                                   # Retorna linha de diagnóstico.
      preco = g,                                      # Produto cujo preço foi explicado.
      instrumento = label,                            # Tipo de conjunto de instrumentos.
      F_excluidos = an$F[2],                           # F dos instrumentos excluídos.
      p_valor = an$`Pr(>F)`[2],                        # p-valor do F.
      r2_full = r2_full,                               # R2 completo.
      r2_reduzido = r2_red,                            # R2 reduzido.
      r2_parcial = (r2_full - r2_red) / (1 - r2_red),  # R2 parcial.
      N = stats::nobs(fit_full)                        # Número de observações.
    )                                                  # Fecha tibble.
  })                                                   # Fecha map.
}                                                      # Fecha função first_stage.

fs_L1 <- first_stage(data_L1, inst_L1, "L1")           # Calcula primeira etapa com L1.
fs_L2 <- first_stage(data_L2, inst_L2, "L1_L2")        # Calcula primeira etapa com L1 e L2.
diagnostico_primeira_etapa <- dplyr::bind_rows(fs_L1, fs_L2) # Junta diagnósticos.

readr::write_csv(coeficientes, file.path(TABLES, "coeficientes_R.csv")) # Exporta coeficientes.
readr::write_csv(diagnostico_identificacao, file.path(TABLES, "diagnostico_identificacao_R.csv")) # Exporta diagnóstico de identificação.
readr::write_csv(model_comparison, file.path(TABLES, "comparacao_modelos_R.csv")) # Exporta comparação.
readr::write_csv(testes_wald, file.path(TABLES, "testes_wald_restricoes_R.csv")) # Exporta testes.
readr::write_csv(diagnostico_primeira_etapa, file.path(TABLES, "diagnostico_primeira_etapa_R.csv")) # Exporta primeira etapa.

saveRDS(model_unrestricted, file.path(MODELS, "model_unrestricted_R.rds")) # Salva modelo irrestrito.
saveRDS(model_homogeneity, file.path(MODELS, "model_homogeneity_R.rds"))   # Salva modelo homogêneo.
saveRDS(model_hsym, file.path(MODELS, "model_hsym_R.rds"))                 # Salva modelo final.
saveRDS(model_hsym_L2, file.path(MODELS, "model_hsym_L2_R.rds"))           # Salva modelo alternativo.
