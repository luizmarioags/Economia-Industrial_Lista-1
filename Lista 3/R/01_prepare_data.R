# COMENTÁRIOS DETALHADOS
# Este script lê a base original, padroniza nomes, remove o bem externo da amostra interna e constrói delta.
# Também cria instrumentos BLP de própria firma e firmas rivais, além das variáveis do nested logit.
# Cada transformação é feita dentro de prepare_data() para permitir reuso em testes e no run_all.

# Tratamento da base e instrumentos BLP em R

prepare_data <- function(file = DATA_FILE) {
  df <- read.csv(file, check.names = FALSE, stringsAsFactors = FALSE)

  names(df) <- c(
    "id",
    "firm",
    "product",
    "price",
    "shelf_price",
    "ad_price",
    "share_pct",
    "segment",
    "cals",
    "fat",
    "sugar"
  )

  num_vars <- c(
    "id",
    "price",
    "shelf_price",
    "ad_price",
    "share_pct",
    CHAR_VARS
  )

  for (v in num_vars) {
    df[[v]] <- suppressWarnings(as.numeric(df[[v]]))
  }

  df <- subset(
    df,
    tolower(firm) != "basketof" &
      !is.na(segment) &
      !is.na(price) &
      !is.na(share_pct)
  )

  df <- df[complete.cases(df[, c("price", "share_pct", CHAR_VARS)]), ]

  # Remove observações problemáticas para logs e elasticidades
  df <- subset(df, share_pct > 0 & price > 0)

  df$share <- df$share_pct / 100
  df$outside_share <- S0
  df$delta <- log(df$share) - log(S0)

  df$firm_id <- as.integer(factor(df$firm))
  df$segment_id <- as.integer(factor(df$segment))

  n <- nrow(df)

  if (n == 0) {
    stop("Depois dos filtros, a base ficou vazia. Verifique data/exemplo.csv.")
  }

  # ============================================================
  # Instrumentos BLP por firma
  # ============================================================

  for (x in CHAR_VARS) {
    firm_sum <- ave(df[[x]], df$firm, FUN = sum)
    firm_n <- as.numeric(ave(seq_len(n), df$firm, FUN = length))
    total_sum <- sum(df[[x]], na.rm = TRUE)

    df[[paste0("own_", x)]] <- firm_sum - df[[x]]
    df[[paste0("own_", x)]][firm_n <= 1] <- 0

    df[[paste0("rival_", x)]] <- total_sum - firm_sum
  }

  # Correção central:
  # usar seq_len(n), que é numérico, e não df$product, que é texto.
  df$n_products_firm <- as.numeric(ave(seq_len(n), df$firm, FUN = length))
  df$n_rival_products <- n - df$n_products_firm

  # ============================================================
  # Variáveis do nested logit
  # ============================================================

  df$nest_share <- ave(df$share, df$segment, FUN = sum)
  df$share_within_nest <- df$share / df$nest_share
  df$log_share_within_nest <- log(df$share_within_nest)

  # Correção análoga para nests/segmentos
  df$n_products_nest <- as.numeric(ave(seq_len(n), df$segment, FUN = length))
  df$n_same_nest_other <- df$n_products_nest - 1
  df$n_rival_nest <- n - df$n_products_nest

  for (x in CHAR_VARS) {
    nest_sum <- ave(df[[x]], df$segment, FUN = sum)
    total_sum <- sum(df[[x]], na.rm = TRUE)

    df[[paste0("nest_own_", x)]] <- nest_sum - df[[x]]
    df[[paste0("nest_rival_", x)]] <- total_sum - nest_sum
  }

  # Garante que as variáveis de contagem são numéricas
  count_vars <- c(
    "n_products_firm",
    "n_rival_products",
    "n_products_nest",
    "n_same_nest_other",
    "n_rival_nest"
  )

  for (v in count_vars) {
    df[[v]] <- as.numeric(df[[v]])
  }

  write.csv(
    df,
    file.path(OUT_DATA, "prepared_data_R.csv"),
    row.names = FALSE
  )

  df
}

df <- prepare_data()

cat("Base preparada em R:", nrow(df), "produtos internos\n")