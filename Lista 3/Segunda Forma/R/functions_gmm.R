# functions_gmm.R ----------------------------------------------------------
# Núcleo operacional equivalente ao eberry/b_program em R.

safe_solve <- function(A) {
  out <- tryCatch(solve(A), error = function(e) NULL)
  if (is.null(out) || any(!is.finite(out))) MASS::ginv(A) else out
}

as_matrix <- function(df, vars) {
  m <- as.matrix(df[, vars, drop = FALSE])
  storage.mode(m) <- "double"
  m
}

fit_ols <- function(df, y, xvars, bnames = xvars, hc1 = TRUE) {
  d <- df[, unique(c(y, xvars)), drop = FALSE]
  d <- d[stats::complete.cases(d), , drop = FALSE]
  Y <- as_matrix(d, y)
  X <- as_matrix(d, xvars)
  N <- nrow(X); k <- ncol(X)
  b <- safe_solve(crossprod(X)) %*% crossprod(X, Y)
  u <- as.numeric(Y - X %*% b)
  meat <- t(X) %*% (X * as.numeric(u^2))
  if (hc1 && N > k) meat <- meat * N/(N-k)
  V <- safe_solve(crossprod(X)) %*% meat %*% safe_solve(crossprod(X))
  rownames(b) <- colnames(V) <- rownames(V) <- bnames
  se <- sqrt(pmax(diag(V), 0))
  out <- list(model = "OLS", coefficients = as.numeric(b), vcov = V, se = se, residuals = u,
              N = N, k = k, q = k, Q = NA_real_, J = NA_real_, xvars = xvars,
              zvars = xvars, bnames = bnames)
  names(out$coefficients) <- bnames
  out
}

fit_iv_2sls <- function(df, y, xvars, zvars, bnames = xvars) {
  d <- df[, unique(c(y, xvars, zvars)), drop = FALSE]
  d <- d[stats::complete.cases(d), , drop = FALSE]
  Y <- as_matrix(d, y)
  X <- as_matrix(d, xvars)
  Z <- as_matrix(d, zvars)
  N <- nrow(X); k <- ncol(X); q <- ncol(Z)
  W <- safe_solve(crossprod(Z) / N)
  b <- safe_solve(t(X) %*% Z %*% W %*% t(Z) %*% X) %*% (t(X) %*% Z %*% W %*% t(Z) %*% Y)
  u <- as.numeric(Y - X %*% b)
  Z_u <- Z * as.numeric(u)
  S <- crossprod(Z_u) / N
  D <- -crossprod(Z, X) / N
  A <- t(D) %*% W %*% D
  B <- t(D) %*% W %*% S %*% W %*% D
  V <- safe_solve(A) %*% B %*% safe_solve(A) / N
  gbar <- crossprod(Z, u) / N
  Q <- as.numeric(N * t(gbar) %*% W %*% gbar)
  rownames(b) <- colnames(V) <- rownames(V) <- bnames
  se <- sqrt(pmax(diag(V), 0))
  out <- list(model = "IV_2SLS", coefficients = as.numeric(b), vcov = V, se = se, residuals = u,
              N = N, k = k, q = q, Q = Q, J = q-k, xvars = xvars, zvars = zvars, bnames = bnames)
  names(out$coefficients) <- bnames
  out
}

berry_gmm_fit <- function(df, y, xvars, zvars, bnames, step = 2, maxit = 20000) {
  d <- df[, unique(c(y, xvars, zvars)), drop = FALSE]
  d <- d[stats::complete.cases(d), , drop = FALSE]
  Y <- as_matrix(d, y)
  X <- as_matrix(d, xvars)
  Z <- as_matrix(d, zvars)
  N <- nrow(X); k <- ncol(X); q <- ncol(Z)
  if (length(bnames) != k) stop("Número de bnames difere do número de colunas de X.")
  bstart <- as.numeric(safe_solve(crossprod(X)) %*% crossprod(X, Y))
  bstart[!is.finite(bstart)] <- 0
  obj <- function(beta, W) {
    xi <- as.numeric(Y - X %*% beta)
    gbar <- crossprod(Z, xi) / N
    as.numeric(N * t(gbar) %*% W %*% gbar)
  }
  W <- safe_solve(crossprod(Z) / N)
  opt1 <- optim(bstart, obj, W = W, method = "Nelder-Mead",
                control = list(maxit = maxit, reltol = 1e-12))
  p <- opt1$par
  xi <- as.numeric(Y - X %*% p)
  Zxi <- Z * xi
  Szz <- crossprod(Zxi) / N
  if (step == 2) {
    W <- safe_solve(Szz)
    opt2 <- optim(p, obj, W = W, method = "Nelder-Mead",
                  control = list(maxit = maxit, reltol = 1e-12))
    p <- opt2$par
    xi <- as.numeric(Y - X %*% p)
    Zxi <- Z * xi
    Szz <- crossprod(Zxi) / N
  }
  gbar <- crossprod(Z, xi) / N
  D <- -crossprod(Z, X) / N
  A <- t(D) %*% W %*% D
  B <- t(D) %*% W %*% Szz %*% W %*% D
  V <- safe_solve(A) %*% B %*% safe_solve(A) / N
  Q <- as.numeric(N * t(gbar) %*% W %*% gbar)
  names(p) <- bnames
  rownames(V) <- colnames(V) <- bnames
  se <- sqrt(pmax(diag(V), 0))
  out <- list(model = paste0("GMM_step", step), coefficients = p, vcov = V, se = se,
              residuals = xi, N = N, k = k, q = q, Q = Q, J = q-k, step = step,
              xvars = xvars, zvars = zvars, bnames = bnames)
  out
}

model_tidy <- function(mod, model_name) {
  b <- mod$coefficients
  se <- mod$se
  tibble(
    model = model_name,
    parameter = names(b),
    estimate = as.numeric(b),
    std_error = as.numeric(se),
    statistic = estimate/std_error,
    p_value = 2 * pnorm(-abs(statistic)),
    objective_gmm = mod$Q,
    sigma_nested = if ("sigma" %in% names(b)) as.numeric(b["sigma"]) else NA_real_
  )
}

save_models <- function(models, path = file.path(OUTDATA, "model_results_R.rds")) {
  saveRDS(models, path)
}

load_models <- function(path = file.path(OUTDATA, "model_results_R.rds")) {
  if (!file.exists(path)) return(list())
  readRDS(path)
}

wald_test_excluded <- function(df, y, controls, excluded, robust = TRUE) {
  xvars <- c("cons", controls, excluded)
  mod <- fit_ols(df, y, xvars, bnames = xvars)
  b <- mod$coefficients[excluded]
  V <- mod$vcov[excluded, excluded, drop = FALSE]
  q <- length(excluded)
  W <- as.numeric(t(b) %*% safe_solve(V) %*% b)
  list(F = W/q, chi2 = W, df = q)
}

r2_ols <- function(df, y, xvars) {
  d <- df[, unique(c(y, xvars)), drop = FALSE]
  d <- d[stats::complete.cases(d), , drop = FALSE]
  Y <- d[[y]]
  X <- as_matrix(d, xvars)
  b <- safe_solve(crossprod(X)) %*% crossprod(X, Y)
  u <- as.numeric(Y - X %*% b)
  1 - sum(u^2) / sum((Y - mean(Y))^2)
}
