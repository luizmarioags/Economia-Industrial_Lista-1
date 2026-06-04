# COMENTÁRIOS DETALHADOS
# Este script programa manualmente a álgebra de MQO, 2SLS, GMM, erros robustos e primeiro estágio.
# pinv usa decomposição SVD para inversas generalizadas, evitando falhas quando matrizes são quase singulares.
# As funções retornam listas padronizadas com coeficientes, erros-padrão, resíduos e tabelas exportáveis.

# Estimadores manuais: MQO, 2SLS, GMM e diagnósticos
pinv <- function(A, tol = 1e-10) {
  s <- svd(A)
  keep <- s$d > tol * max(s$d)
  if (!any(keep)) return(matrix(0, nrow = ncol(A), ncol = nrow(A)))
  s$v[, keep, drop = FALSE] %*% diag(1 / s$d[keep], nrow = sum(keep)) %*% t(s$u[, keep, drop = FALSE])
}
add_const <- function(X) cbind(const = 1, as.matrix(X))

robust_ols_vcov <- function(X, u) {
  n <- nrow(X); k <- ncol(X)
  bread <- pinv(t(X) %*% X)
  meat <- t(X) %*% (X * as.numeric(u^2))
  (n / max(n-k, 1)) * bread %*% meat %*% bread
}

make_result <- function(name, beta, se, resid, fitted, coef_names, objective = NA_real_) {
  tval <- beta / se
  pval <- 2 * (1 - pnorm(abs(tval)))
  data.frame(model = name, parameter = coef_names, estimate = as.numeric(beta), std_error = as.numeric(se),
             t_stat = as.numeric(tval), p_value = as.numeric(pval), gmm_objective = objective,
             stringsAsFactors = FALSE)
}

ols_manual <- function(y, X, coef_names, name = "OLS") {
  y <- as.numeric(y); X <- as.matrix(X)
  beta <- pinv(t(X) %*% X) %*% t(X) %*% y
  fitted <- as.numeric(X %*% beta); resid <- y - fitted
  V <- robust_ols_vcov(X, resid); se <- sqrt(pmax(diag(V), 0))
  list(name = name, beta = as.numeric(beta), se = se, resid = resid, fitted = fitted, coef_names = coef_names,
       table = make_result(name, beta, se, resid, fitted, coef_names))
}

iv_vcov <- function(y, X, Z, beta) {
  n <- nrow(X); u <- as.numeric(y - X %*% beta)
  Qxz <- t(X) %*% Z / n; Qzx <- t(Qxz); Qzz_i <- pinv(t(Z) %*% Z / n)
  A <- Qxz %*% Qzz_i %*% Qzx
  Zu <- Z * as.numeric(u)
  S <- t(Zu) %*% Zu / n
  V <- pinv(A) %*% (Qxz %*% Qzz_i %*% S %*% Qzz_i %*% Qzx) %*% pinv(A) / n
  list(V = V, u = u)
}

twosls_manual <- function(y, X, Z, coef_names, name = "2SLS") {
  y <- as.numeric(y); X <- as.matrix(X); Z <- as.matrix(Z)
  Pz <- Z %*% pinv(t(Z) %*% Z) %*% t(Z)
  beta <- pinv(t(X) %*% Pz %*% X) %*% t(X) %*% Pz %*% y
  vc <- iv_vcov(y, X, Z, beta)
  se <- sqrt(pmax(diag(vc$V), 0)); fitted <- as.numeric(X %*% beta)
  list(name = name, beta = as.numeric(beta), se = se, resid = vc$u, fitted = fitted, coef_names = coef_names,
       table = make_result(name, beta, se, vc$u, fitted, coef_names))
}

gmm_linear <- function(y, X, Z, W = NULL, coef_names, name = "GMM") {
  y <- as.numeric(y); X <- as.matrix(X); Z <- as.matrix(Z); n <- length(y)
  if (is.null(W)) W <- pinv(t(Z) %*% Z / n)
  beta <- pinv(t(X) %*% Z %*% W %*% t(Z) %*% X) %*% (t(X) %*% Z %*% W %*% t(Z) %*% y)
  fitted <- as.numeric(X %*% beta); resid <- y - fitted
  gbar <- t(Z) %*% resid / n
  objective <- as.numeric(n * t(gbar) %*% W %*% gbar)
  D <- t(Z) %*% X / n
  S <- t(Z * as.numeric(resid)) %*% (Z * as.numeric(resid)) / n
  A <- t(D) %*% W %*% D
  V <- pinv(A) %*% (t(D) %*% W %*% S %*% W %*% D) %*% pinv(A) / n
  se <- sqrt(pmax(diag(V), 0))
  list(name = name, beta = as.numeric(beta), se = se, resid = resid, fitted = fitted, coef_names = coef_names,
       objective = objective, table = make_result(name, beta, se, resid, fitted, coef_names, objective))
}

gmm_2step <- function(y, X, Z, coef_names, name = "GMM_2step") {
  n <- length(y)
  W1 <- pinv(t(Z) %*% Z / n)
  s1 <- gmm_linear(y, X, Z, W1, coef_names, paste0(name, "_step1"))
  S <- t(Z * as.numeric(s1$resid)) %*% (Z * as.numeric(s1$resid)) / n
  W2 <- pinv(S)
  s2 <- gmm_linear(y, X, Z, W2, coef_names, name)
  list(step1 = s1, step2 = s2)
}

latex_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("&", "\\\\&", x)
  x <- gsub("%", "\\\\%", x)
  x <- gsub("\\$", "\\\\$", x)
  x <- gsub("#", "\\\\#", x)
  x <- gsub("_", "\\\\_", x)
  x <- gsub("\\{", "\\\\{", x)
  x <- gsub("\\}", "\\\\}", x)
  x
}

save_table <- function(tab, name, caption = NULL, label = NULL, digits = 4) {
  # Toda tabela substantiva é exportada nos dois formatos solicitados.
  csv_path <- file.path(TAB_CSV, paste0(name, ".csv"))
  tex_path <- file.path(TAB_TEX, paste0(name, ".tex"))
  write.csv(tab, csv_path, row.names = FALSE)
  d <- as.data.frame(tab, stringsAsFactors = FALSE)
  con <- file(tex_path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)
  writeLines("\\begin{table}[!htbp]", con)
  writeLines("\\centering", con)
  if (!is.null(caption)) writeLines(paste0("\\caption{", latex_escape(caption), "}"), con)
  if (!is.null(label)) writeLines(paste0("\\label{", label, "}"), con)
  writeLines("\\scriptsize", con)
  align <- paste(rep("l", ncol(d)), collapse = "")
  writeLines(paste0("\\begin{tabular}{", align, "}"), con)
  writeLines("\\hline", con)
  writeLines(paste(latex_escape(names(d)), collapse = " & "), con)
  writeLines("\\\\", con)
  writeLines("\\hline", con)
  if (nrow(d) > 0) {
    for (i in seq_len(nrow(d))) {
      vals <- vapply(d[i, , drop = FALSE], function(z) {
        z <- z[[1]]
        if (is.numeric(z)) sprintf(paste0("%0.", digits, "f"), z) else latex_escape(z)
      }, character(1))
      writeLines(paste(vals, collapse = " & "), con)
      writeLines("\\\\", con)
    }
  }
  writeLines("\\hline", con)
  writeLines("\\end{tabular}", con)
  writeLines("\\end{table}", con)
}

matrix_to_long <- function(M, value_name = "elasticity") {
  # Formato padronizado nas três linguagens para matrizes de elasticidades.
  out <- as.data.frame(as.table(M), stringsAsFactors = FALSE)
  names(out) <- c("row_product", "column_product", value_name)
  out
}

nested_logit_numeric_elasticities <- function(df, fit, eps = 1e-6) {
  # Recalcula shares previstos do nested logit e aplica perturbação numérica produto a produto.
  b <- setNames(fit$beta, fit$coef_names)
  alpha <- -unname(b["price"])
  sigma <- unname(b["log_share_within_nest"])
  if (!is.finite(alpha) || !is.finite(sigma) || sigma >= 1) return(NULL)
  p0 <- df$price
  groups <- df$segment
  Xb <- unname(b["const"]) + unname(b["cals"])*df$cals + unname(b["fat"])*df$fat + unname(b["sugar"])*df$sugar
  pred <- function(p) {
    delta <- Xb - alpha*p
    ug <- unique(groups)
    within <- numeric(length(p))
    Dg <- numeric(length(ug))
    for (i in seq_along(ug)) {
      idx <- groups == ug[i]
      exp_inner <- exp(delta[idx] / max(1 - sigma, 1e-8))
      den <- sum(exp_inner)
      within[idx] <- exp_inner / den
      Dg[i] <- den^(1 - sigma)
    }
    group_prob <- Dg / (1 + sum(Dg))
    s <- numeric(length(p))
    for (i in seq_along(ug)) s[groups == ug[i]] <- within[groups == ug[i]] * group_prob[i]
    s
  }
  s0 <- pred(p0)
  n <- length(p0)
  E <- matrix(NA_real_, n, n, dimnames = list(df$product, df$product))
  for (k in seq_len(n)) {
    p1 <- p0
    p1[k] <- p1[k] + eps
    deriv <- (pred(p1) - s0) / eps
    E[, k] <- deriv * p0[k] / pmax(s0, 1e-12)
  }
  E
}

first_stage_diag <- function(df, endog_vars, exog_vars, excluded) {
  W <- add_const(df[, exog_vars, drop = FALSE])
  Zex <- as.matrix(df[, excluded, drop = FALSE])
  Full <- cbind(W, Zex)
  q <- ncol(Zex); n <- nrow(df)
  out <- list()
  for (e in endog_vars) {
    y <- df[[e]]
    full <- ols_manual(y, Full, c("const", exog_vars, excluded), paste0("fs_", e))
    rest <- ols_manual(y, W, c("const", exog_vars), paste0("fs_rest_", e))
    rssf <- sum(full$resid^2); rssr <- sum(rest$resid^2)
    fpartial <- ((rssr - rssf) / q) / (rssf / max(n - ncol(Full), 1))
    V <- robust_ols_vcov(Full, full$resid)
    b <- matrix(full$beta[(length(full$beta)-q+1):length(full$beta)], ncol = 1)
    Vb <- V[(ncol(Full)-q+1):ncol(Full), (ncol(Full)-q+1):ncol(Full), drop = FALSE]
    robustF <- as.numeric(t(b) %*% pinv(Vb) %*% b) / q
    out[[e]] <- data.frame(endogenous_variable = e, excluded_instruments = q,
                           partial_F_homoskedastic = fpartial, robust_Wald_F_manual = robustF,
                           first_stage_R2 = 1 - rssf/sum((y - mean(y))^2))
  }
  do.call(rbind, out)
}
