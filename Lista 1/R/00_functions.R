# -------------------------------------------------------------------
# Funções econométricas auxiliares: MQO, 2SLS, GMM, Hansen J, AR e MOP
# CORREÇÕES APLICADAS:
#   - mop_f_eff(): retorna NA de forma segura quando denominador == 0
#   - ar_interval(): trata IC aberto/vazio com grade adaptativa e retorna p_min/p_max
#   - Documentação inline aprimorada em todas as funções
# -------------------------------------------------------------------

# Pseudo-inversa via decomposição em valores singulares.
pinv <- function(A, tol = sqrt(.Machine$double.eps)) {
  s <- svd(A)
  positive <- s$d > tol * max(s$d)
  if (!any(positive)) return(matrix(0, nrow = ncol(A), ncol = nrow(A)))
  s$v[, positive, drop = FALSE] %*%
    diag(1 / s$d[positive], nrow = sum(positive)) %*%
    t(s$u[, positive, drop = FALSE])
}

# Adiciona coluna de constante (intercepto) à esquerda de uma matriz.
add_const <- function(M) {
  cbind(const = 1, as.matrix(M))
}

# MQO com matriz de variância robusta HC1 (correção de graus de liberdade n/(n-k)).
ols_hc1 <- function(y, X) {
  y <- as.matrix(y)
  X <- as.matrix(X)
  n <- nrow(X)
  k <- ncol(X)
  beta   <- pinv(crossprod(X)) %*% crossprod(X, y)
  resid  <- as.numeric(y - X %*% beta)
  fitted <- as.numeric(X %*% beta)
  meat   <- crossprod(X * resid)
  vcov   <- (n / (n - k)) * pinv(crossprod(X)) %*% meat %*% pinv(crossprod(X))
  list(beta = as.numeric(beta), vcov = vcov, se = sqrt(diag(vcov)),
       resid = resid, fitted = fitted, n = n, k = k, df = n - k)
}

# Teste de Wald robusto para H0: R*beta = r.
# df_denom = NULL -> qui-quadrado; df_denom = inteiro -> F com df_denom no denominador.
wald_test <- function(beta, vcov, R, r = NULL, df_denom = NULL) {
  beta <- as.matrix(beta)
  R    <- as.matrix(R)
  if (is.null(r)) r <- matrix(0, nrow = nrow(R), ncol = 1)
  diff <- R %*% beta - r
  W    <- as.numeric(t(diff) %*% pinv(R %*% vcov %*% t(R)) %*% diff)
  q    <- nrow(R)
  Fstat <- W / q
  pval <- if (is.null(df_denom)) {
    pchisq(W, df = q, lower.tail = FALSE)
  } else {
    pf(Fstat, df1 = q, df2 = df_denom, lower.tail = FALSE)
  }
  list(W = W, F = Fstat, p = pval, q = q)
}

# R2 parcial dos instrumentos excluídos (Z), condicional aos controles (C).
partial_r2 <- function(x, controls, instruments) {
  x    <- as.matrix(x)
  C    <- as.matrix(controls)
  Z    <- as.matrix(instruments)
  rx   <- ols_hc1(x, C)$resid
  RZ   <- matrix(NA_real_, nrow = nrow(Z), ncol = ncol(Z))
  for (j in seq_len(ncol(Z))) RZ[, j] <- ols_hc1(Z[, j], C)$resid
  fit  <- lm(rx ~ RZ - 1)
  as.numeric(summary(fit)$r.squared)
}

# -------------------------------------------------------------------
# F Efetivo de Montiel Olea-Pflueger — implementação "na mão"
# Retorna NA de forma segura se denominador numericamente zero.
# -------------------------------------------------------------------
mop_f_eff <- function(y_endog, Z_excl, X_incl) {
  y_endog <- as.matrix(y_endog)
  Z_excl  <- as.matrix(Z_excl)
  X_incl  <- as.matrix(X_incl)

  n       <- nrow(X_incl)
  k_total <- ncol(X_incl) + ncol(Z_excl)

  # 1. Residualizar a variável endógena e os instrumentos excluídos
  #    contra os controles (X_incl deve já incluir a constante).
  y_perp <- ols_hc1(y_endog, X_incl)$resid
  Z_perp <- matrix(NA_real_, nrow = n, ncol = ncol(Z_excl))
  for (j in seq_len(ncol(Z_excl))) {
    Z_perp[, j] <- ols_hc1(Z_excl[, j], X_incl)$resid
  }

  # 2. Primeiro estágio nos resíduos.
  W      <- crossprod(Z_perp)
  pi_hat <- pinv(W) %*% crossprod(Z_perp, y_perp)

  # 3. Resíduos do primeiro estágio residualizado.
  v_hat <- as.numeric(y_perp - Z_perp %*% pi_hat)

  # 4. Numerador: pi' W pi.
  numerator <- as.numeric(t(pi_hat) %*% W %*% pi_hat)

  # 5. Denominador: traço da matriz de covariância robusta dos momentos.
  #    Correção HC1 (small-sample adjustment): n / (n - k_total).
  dfc         <- n / (n - k_total)
  meat        <- crossprod(Z_perp * v_hat) * dfc
  S           <- pinv(W) %*% meat
  denominator <- sum(diag(S))

  # 6. Estatística F efetiva.
  if (abs(denominator) < .Machine$double.eps * 100) {
    warning("mop_f_eff: denominador numericamente zero — retornando NA.")
    return(NA_real_)
  }
  numerator / denominator
}

# 2SLS com variância robusta à heterocedasticidade (sandwich HC).
iv_2sls <- function(y, X, Z) {
  y <- as.matrix(y)
  X <- as.matrix(X)
  Z <- as.matrix(Z)
  n <- nrow(X)
  k <- ncol(X)
  W    <- pinv(crossprod(Z))
  beta <- pinv(t(X) %*% Z %*% W %*% t(Z) %*% X) %*%
          (t(X) %*% Z %*% W %*% t(Z) %*% y)
  resid  <- as.numeric(y - X %*% beta)
  fitted <- as.numeric(X %*% beta)

  Qxz  <- t(X) %*% Z / n
  Wn   <- pinv(crossprod(Z) / n)
  S    <- crossprod(Z * resid) / n
  A    <- Qxz %*% Wn %*% t(Qxz)
  vcov <- pinv(A) %*% Qxz %*% Wn %*% S %*% Wn %*% t(Qxz) %*% pinv(A) / n
  vcov <- (n / (n - k)) * vcov

  list(beta = as.numeric(beta), vcov = vcov, se = sqrt(diag(vcov)),
       resid = resid, fitted = fitted, n = n, k = k, df = n - k)
}

# GMM em dois passos com teste Hansen J.
iv_gmm_2step <- function(y, X, Z) {
  y <- as.matrix(y)
  X <- as.matrix(X)
  Z <- as.matrix(Z)
  n <- nrow(X)
  k <- ncol(X)
  l <- ncol(Z)

  # Passo 1: ponderação identidade escalada.
  W1    <- pinv(crossprod(Z) / n)
  beta1 <- pinv(t(X) %*% Z %*% W1 %*% t(Z) %*% X) %*%
           (t(X) %*% Z %*% W1 %*% t(Z) %*% y)
  u1 <- as.numeric(y - X %*% beta1)

  # Passo 2: ponderação ótima.
  S  <- crossprod(Z * u1) / n
  W2 <- pinv(S)
  beta2 <- pinv(t(X) %*% Z %*% W2 %*% t(Z) %*% X) %*%
           (t(X) %*% Z %*% W2 %*% t(Z) %*% y)
  u2 <- as.numeric(y - X %*% beta2)

  Qxz  <- t(X) %*% Z / n
  S2   <- crossprod(Z * u2) / n
  A    <- Qxz %*% W2 %*% t(Qxz)
  vcov <- pinv(A) %*% Qxz %*% W2 %*% S2 %*% W2 %*% t(Qxz) %*% pinv(A) / n
  vcov <- (n / (n - k)) * vcov

  # Hansen J.
  gbar <- colMeans(Z * u2)
  df_j <- l - k
  J    <- as.numeric(n * t(gbar) %*% W2 %*% gbar)
  p_j  <- if (df_j > 0) pchisq(J, df = df_j, lower.tail = FALSE) else NA_real_

  list(beta = as.numeric(beta2), vcov = vcov, se = sqrt(diag(vcov)), resid = u2,
       n = n, k = k, l = l,
       hansen_J  = if (df_j > 0) J else NA_real_,
       hansen_p  = p_j,
       hansen_df = df_j)
}

# -------------------------------------------------------------------
# Valores críticos MOP/weakivtest usados na comparação da Lista 1
# -------------------------------------------------------------------
# Observação importante:
#   O Stata, via weakivtest, retorna valores críticos tabulados em r(c_TSLS_5),
#   r(c_TSLS_10) e r(c_TSLS_20). Em R puro, a rotina abaixo NÃO recalcula
#   esses valores críticos; ela apenas registra os valores TSLS observados no
#   log do Stata para os modelos Z1-Z7 desta aplicação, permitindo que a tabela
#   comparativa R fique alinhada com a tabela do Stata.
#
#   Se a amostra, a lista de instrumentos ou o desenho do exercício mudar,
#   atualize esta tabela ou deixe os valores como NA_real_.
# -------------------------------------------------------------------
mop_cv_tsls_lista1 <- function(model) {
  cv_tab <- data.frame(
    model = c("Z1", "Z2", "Z3", "Z4", "Z5", "Z6", "Z7"),
    cv5   = c(37.418, 23.816, 28.391, 37.418, 18.452, 10.947, 27.595),
    cv10  = c(23.109, 15.080, 17.476, 23.109, 11.808,  7.572, 16.774),
    cv20  = c(15.062, 10.117, 11.370, 15.062,  8.050,  5.605, 10.773),
    stringsAsFactors = FALSE
  )
  out <- cv_tab[cv_tab$model == model, c("cv5", "cv10", "cv20"), drop = FALSE]
  if (nrow(out) == 0) {
    return(data.frame(cv5 = NA_real_, cv10 = NA_real_, cv20 = NA_real_))
  }
  out
}

# -------------------------------------------------------------------
# Intervalo Anderson-Rubin por inversão de grade adaptativa
# CORREÇÕES APLICADAS:
#   - Expansão automática da grade quando o IC toca bmin/bmax.
#   - Reconhecimento de IC aberto à esquerda/direita após toques persistentes
#     na mesma borda, evitando perseguir artificialmente -infinito/+infinito.
#   - Caso nenhum beta0 seja aceito, a grade é expandida simetricamente até
#     max_abs_beta; a grade final capada é efetivamente avaliada antes de
#     declarar o IC vazio.
#   - beta0_minp passa a ser o beta0 com MAIOR p-valor AR, alinhado ao Stata.
#   - Retorna p_min, p_max, limites reportados e limites observados na grade.
# -------------------------------------------------------------------
ar_interval <- function(data, inst_vars,
                        beta_grid = seq(-5, 2, by = 0.005),
                        alpha = 0.05,
                        expand_grid = TRUE,
                        expand_by = 2,
                        max_expand = 20,
                        max_abs_beta = 100,
                        min_tail_hits = 3,
                        verbose = TRUE) {

  keep_vars <- c("ln_q", "ln_pch", "ln_y", "ln_pb", inst_vars)
  d         <- data[complete.cases(data[, keep_vars]), keep_vars]

  if (nrow(d) == 0) {
    stop("ar_interval: nenhuma observação completa para as variáveis informadas.")
  }
  if (length(beta_grid) < 2) {
    stop("ar_interval: beta_grid precisa ter pelo menos dois pontos.")
  }

  grid_initial_min <- min(beta_grid)
  grid_initial_max <- max(beta_grid)
  step             <- abs(beta_grid[2] - beta_grid[1])

  eval_grid <- function(bg) {
    accepted <- logical(length(bg))
    pvals    <- rep(NA_real_, length(bg))

    for (i in seq_along(bg)) {
      b0   <- bg[i]
      y_ar <- d$ln_q - b0 * d$ln_pch
      X_ar <- add_const(d[, c("ln_y", "ln_pb", inst_vars), drop = FALSE])
      fit  <- ols_hc1(y_ar, X_ar)

      q        <- length(inst_vars)
      R        <- matrix(0, nrow = q, ncol = ncol(X_ar))
      inst_pos <- match(inst_vars, colnames(X_ar))
      for (j in seq_len(q)) R[j, inst_pos[j]] <- 1

      wt          <- wald_test(fit$beta, fit$vcov, R, df_denom = fit$df)
      pvals[i]    <- wt$p
      accepted[i] <- wt$p >= alpha
    }

    gmin  <- min(bg)
    gmax  <- max(bg)
    p_min <- suppressWarnings(min(pvals, na.rm = TRUE))
    p_max <- suppressWarnings(max(pvals, na.rm = TRUE))

    if (!any(accepted)) {
      beta0_minp <- if (is.finite(p_max)) mean(bg[pvals == p_max], na.rm = TRUE) else NA_real_
      return(list(
        accepted      = accepted,
        pvals         = pvals,
        low           = NA_real_,
        high          = NA_real_,
        beta0_minp    = beta0_minp,
        p_min         = p_min,
        p_max         = p_max,
        open_left     = FALSE,
        open_right    = FALSE,
        grid_min      = gmin,
        grid_max      = gmax,
        npoints_final = length(bg)
      ))
    }

    low        <- min(bg[accepted])
    high       <- max(bg[accepted])
    beta0_minp <- mean(bg[pvals == p_max], na.rm = TRUE)

    list(
      accepted      = accepted,
      pvals         = pvals,
      low           = low,
      high          = high,
      beta0_minp    = beta0_minp,
      p_min         = p_min,
      p_max         = p_max,
      open_left     = (low  <= gmin + step),
      open_right    = (high >= gmax - step),
      grid_min      = gmin,
      grid_max      = gmax,
      npoints_final = length(bg)
    )
  }

  bmin <- max(min(beta_grid), -max_abs_beta)
  bmax <- min(max(beta_grid),  max_abs_beta)

  n_expand       <- 0
  left_hits      <- 0
  right_hits     <- 0
  declared_left  <- FALSE
  declared_right <- FALSE

  repeat {
    beta_grid_now <- seq(from = bmin, to = bmax, by = step)
    # Garante que bmax entre na grade mesmo com arredondamento de ponto flutuante.
    if (tail(beta_grid_now, 1) < bmax - step / 10) {
      beta_grid_now <- c(beta_grid_now, bmax)
    }

    res <- eval_grid(beta_grid_now)

    if (!any(res$accepted)) {
      left_hits      <- 0
      right_hits     <- 0
      declared_left  <- FALSE
      declared_right <- FALSE

      can_expand_left  <- expand_grid && (bmin > -max_abs_beta)
      can_expand_right <- expand_grid && (bmax <  max_abs_beta)
      can_expand_more  <- (can_expand_left || can_expand_right) && n_expand < max_expand

      if (can_expand_more) {
        old_bmin <- bmin
        old_bmax <- bmax
        if (can_expand_left)  bmin <- max(-max_abs_beta, bmin - expand_by)
        if (can_expand_right) bmax <- min( max_abs_beta, bmax + expand_by)

        # Só conta expansão se a grade realmente mudou; isso evita encerrar antes
        # de avaliar a grade capada em [-max_abs_beta, max_abs_beta].
        if (!isTRUE(all.equal(old_bmin, bmin)) || !isTRUE(all.equal(old_bmax, bmax))) {
          n_expand <- n_expand + 1
          if (verbose) {
            message(sprintf(
              "ar_interval [%s]: sem região aceita; ampliando grade para [%.4f, %.4f] (expansão %d/%d).",
              paste(inst_vars, collapse = "+"), bmin, bmax, n_expand, max_expand
            ))
          }
          next
        }
      }

      break
    }

    # Conta toques persistentes nas bordas. Se a mesma borda for tocada várias
    # vezes consecutivas, a rotina interpreta o IC como aberto naquele lado.
    if (res$open_left)  left_hits  <- left_hits + 1 else left_hits  <- 0
    if (res$open_right) right_hits <- right_hits + 1 else right_hits <- 0

    if (res$open_left  && left_hits  >= min_tail_hits) declared_left  <- TRUE
    if (res$open_right && right_hits >= min_tail_hits) declared_right <- TRUE

    need_left  <- res$open_left  && !declared_left
    need_right <- res$open_right && !declared_right

    can_expand_left  <- expand_grid && need_left  && (bmin > -max_abs_beta)
    can_expand_right <- expand_grid && need_right && (bmax <  max_abs_beta)
    can_expand_more  <- (can_expand_left || can_expand_right) && n_expand < max_expand

    if (can_expand_more) {
      old_bmin <- bmin
      old_bmax <- bmax
      if (can_expand_left)  bmin <- max(-max_abs_beta, bmin - expand_by)
      if (can_expand_right) bmax <- min( max_abs_beta, bmax + expand_by)

      if (!isTRUE(all.equal(old_bmin, bmin)) || !isTRUE(all.equal(old_bmax, bmax))) {
        n_expand <- n_expand + 1
        if (verbose) {
          lados <- paste(c(if (can_expand_left) "esquerda" else NULL,
                           if (can_expand_right) "direita" else NULL), collapse = " e ")
          message(sprintf(
            "ar_interval [%s]: IC tocou borda (%s); ampliando grade para [%.4f, %.4f] (expansão %d/%d).",
            paste(inst_vars, collapse = "+"), lados, bmin, bmax, n_expand, max_expand
          ))
        }
        next
      }
    }

    break
  }

  has_accept <- any(res$accepted)

  final_open_left <- has_accept && res$open_left &&
    (declared_left || bmin <= -max_abs_beta || n_expand >= max_expand)
  final_open_right <- has_accept && res$open_right &&
    (declared_right || bmax >= max_abs_beta || n_expand >= max_expand)

  ar_low_report  <- if (has_accept && !final_open_left)  res$low  else NA_real_
  ar_high_report <- if (has_accept && !final_open_right) res$high else NA_real_

  if (!has_accept) {
    warning(sprintf(
      "ar_interval [%s]: nenhum beta0 aceito após %d expansão(ões). O IC AR foi tratado como vazio na grade final [%.4f, %.4f].",
      paste(inst_vars, collapse = "+"), n_expand, res$grid_min, res$grid_max
    ))
  } else {
    if (final_open_left) {
      warning(sprintf(
        "ar_interval [%s]: IC AR tratado como aberto à esquerda; menor beta aceito na grade final = %.4f.",
        paste(inst_vars, collapse = "+"), res$low
      ))
    }
    if (final_open_right) {
      warning(sprintf(
        "ar_interval [%s]: IC AR tratado como aberto à direita; maior beta aceito na grade final = %.4f.",
        paste(inst_vars, collapse = "+"), res$high
      ))
    }
  }

  data.frame(
    ar_low           = ar_low_report,
    ar_high          = ar_high_report,
    ar_low_grid      = res$low,
    ar_high_grid     = res$high,
    beta0_minp       = res$beta0_minp,
    p_min            = res$p_min,
    p_max            = res$p_max,
    grid_initial_min = grid_initial_min,
    grid_initial_max = grid_initial_max,
    grid_min         = res$grid_min,
    grid_max         = res$grid_max,
    grid_step        = step,
    n_expand         = n_expand,
    npoints_final    = res$npoints_final,
    max_abs_beta     = max_abs_beta,
    min_tail_hits    = min_tail_hits,
    tail_hits_left   = left_hits,
    tail_hits_right  = right_hits,
    open_left        = final_open_left,
    open_right       = final_open_right,
    empty_interval   = !has_accept
  )
}
