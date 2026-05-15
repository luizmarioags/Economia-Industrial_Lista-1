# -------------------------------------------------------------------
# Preparação da base: importa chicken, corrige escala e cria variáveis
# -------------------------------------------------------------------

source("R/00_setup.R")
log_step("Preparação dos dados: iniciando")
log_step("Objetivo: construir ln_q, ln_y, ln_pch, ln_pb, z, z_sq, z_cu, z_lag e z_lag_sq")

# Lê o .dta como fonte principal, porque preserva os decimais da base correta.
if (file.exists(file.path(RAW, "chicken.dta"))) {
  log_step("Fonte usada: data/raw/chicken.dta")
  raw <- haven::read_dta(file.path(RAW, "chicken.dta"))
} else {
  # Se o .dta não existir, lê o CSV separado por ponto e vírgula.
  log_step("Fonte usada: data/raw/chicken.csv com separador ';'")
  raw <- readr::read_delim(file.path(RAW, "chicken.csv"), delim = ";", show_col_types = FALSE)
}

log_step(paste0("Base importada: ", nrow(raw), " linhas e ", ncol(raw), " colunas"))
log_vars("Colunas originais", names(raw))

# Padroniza nomes em minúsculas.
names(raw) <- tolower(names(raw))
log_vars("Colunas após padronização para minúsculas", names(raw))

# Harmoniza nomes alternativos.
if ("tim" %in% names(raw) && !("time" %in% names(raw))) {
  raw$time <- raw$tim
  log_step("Nome harmonizado: tim -> time")
}
if ("eatex" %in% names(raw) && !("meatex" %in% names(raw))) {
  raw$meatex <- raw$eatex
  log_step("Nome harmonizado: eatex -> meatex")
}

# Converte colunas para numérico quando necessário.
log_step("Convertendo colunas para numérico quando possível")
raw[] <- lapply(raw, function(x) suppressWarnings(as.numeric(x)))

# Corrige a escala do CSV quando os decimais aparecem removidos.
# Essas condições não alteram o .dta correto.
log_step("Aplicando regras de correção de escala apenas quando valores estão anormalmente altos")
raw$year   <- ifelse(raw$year   > 9999,   raw$year/1000, raw$year)
raw$q      <- ifelse(raw$q      > 1000,   raw$q/100000, raw$q)
raw$y      <- ifelse(raw$y      > 100000, raw$y/1000, raw$y)
raw$pchick <- ifelse(raw$pchick > 10000,  raw$pchick/100000, raw$pchick)
raw$pbeef  <- ifelse(raw$pbeef  > 10000,  raw$pbeef/100000, raw$pbeef)
raw$pcor   <- ifelse(raw$pcor   > 10000,  raw$pcor/100000, raw$pcor)
raw$pf     <- ifelse(!is.na(raw$pf) & raw$pf > 10000, raw$pf/100000, raw$pf)
raw$cpi    <- ifelse(raw$cpi    > 10000,  raw$cpi/100000, raw$cpi)
raw$pop    <- ifelse(raw$pop    > 10000,  raw$pop/10000, raw$pop)
raw$time   <- ifelse(raw$time   > 10000,  raw$time/100000, raw$time)

# Ordena por ano para criar defasagens corretamente.
raw <- raw[order(raw$year), ]
log_step(paste0("Série ordenada por ano: ", min(raw$year, na.rm = TRUE), " a ", max(raw$year, na.rm = TRUE)))

# Cria variáveis da lista.
log_step("Calculando variáveis principais da demanda")
log_step("ln_q = log(Q); ln_y = log(Y); ln_pch = log(PCHICK/CPI); ln_pb = log(PBEEF/CPI); z = log(PCOR/CPI)")
raw$ln_q   <- log(raw$q)
raw$ln_y   <- log(raw$y)
raw$ln_pch <- log(raw$pchick / raw$cpi)
raw$ln_pb  <- log(raw$pbeef / raw$cpi)
raw$z      <- log(raw$pcor / raw$cpi)

# Cria termos não lineares e defasados da questão 8.
log_step("Calculando instrumentos alternativos: z_sq, z_cu, z_lag e z_lag_sq")
raw$z_sq     <- raw$z^2
raw$z_cu     <- raw$z^3
raw$z_lag    <- c(NA, raw$z[-nrow(raw)])
raw$z_lag_sq <- raw$z_lag^2
log_vars("Variáveis calculadas", c("ln_q", "ln_y", "ln_pch", "ln_pb", "z", "z_sq", "z_cu", "z_lag", "z_lag_sq"))

# Salva a base tratada.
saveRDS(raw, file.path(PROC, "chicken_prepared_r.rds"))
readr::write_csv(raw, file.path(PROC, "chicken_prepared_r.csv"))
log_step("Base tratada salva em data/processed/chicken_prepared_r.rds e data/processed/chicken_prepared_r.csv")
