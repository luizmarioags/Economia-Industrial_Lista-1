# COMENTÁRIOS DETALHADOS
# Este script lê a base original, padroniza nomes, remove o bem externo da amostra interna e constrói delta.
# Também cria instrumentos BLP de própria firma e firmas rivais, além das variáveis do nested logit.
# Cada transformação é feita dentro de prepare_data() para permitir reuso em testes e no run_all.

# Tratamento da base e instrumentos BLP em R
prepare_data <- function(file = DATA_FILE) {
  df <- read.csv(file, check.names = FALSE, stringsAsFactors = FALSE)
  names(df) <- c("id", "firm", "product", "price", "shelf_price", "ad_price", "share_pct", "segment", "cals", "fat", "sugar")
  num_vars <- c("id", "price", "shelf_price", "ad_price", "share_pct", CHAR_VARS)
  for (v in num_vars) df[[v]] <- suppressWarnings(as.numeric(df[[v]]))
  df <- subset(df, tolower(firm) != "basketof" & !is.na(segment) & !is.na(price) & !is.na(share_pct))
  df <- df[complete.cases(df[, c("price", "share_pct", CHAR_VARS)]), ]
  df$share <- df$share_pct / 100
  df$outside_share <- S0
  df$delta <- log(df$share) - log(S0)
  df$firm_id <- as.integer(factor(df$firm))
  df$segment_id <- as.integer(factor(df$segment))

  n <- nrow(df)
  for (x in CHAR_VARS) {
    firm_sum <- ave(df[[x]], df$firm, FUN = sum)
    firm_n <- ave(df[[x]], df$firm, FUN = length)
    total_sum <- sum(df[[x]])
    df[[paste0("own_", x)]] <- firm_sum - df[[x]]
    df[[paste0("own_", x)]][firm_n <= 1] <- 0
    df[[paste0("rival_", x)]] <- total_sum - firm_sum
  }
  df$n_products_firm <- ave(df$product, df$firm, FUN = length)
  df$n_rival_products <- n - df$n_products_firm

  df$nest_share <- ave(df$share, df$segment, FUN = sum)
  df$share_within_nest <- df$share / df$nest_share
  df$log_share_within_nest <- log(df$share_within_nest)
  df$n_products_nest <- ave(df$product, df$segment, FUN = length)
  df$n_same_nest_other <- df$n_products_nest - 1
  df$n_rival_nest <- n - df$n_products_nest
  for (x in CHAR_VARS) {
    nest_sum <- ave(df[[x]], df$segment, FUN = sum)
    total_sum <- sum(df[[x]])
    df[[paste0("nest_own_", x)]] <- nest_sum - df[[x]]
    df[[paste0("nest_rival_", x)]] <- total_sum - nest_sum
  }
  write.csv(df, file.path(OUT_DATA, "prepared_data_R.csv"), row.names = FALSE)
  df
}

df <- prepare_data()
cat("Base preparada em R:", nrow(df), "produtos internos\n")
