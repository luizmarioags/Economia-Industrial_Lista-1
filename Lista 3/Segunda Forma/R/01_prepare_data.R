# 01_prepare_data.R --------------------------------------------------------
# Tratamento da base e construção dos instrumentos BLP.

if (!file.exists(DATA)) stop("Arquivo não encontrado: ", DATA, "\nColoque o CSV em data/exemplo.csv")

raw <- readr::read_csv(DATA, col_types = readr::cols(.default = readr::col_character()), show_col_types = FALSE)
if (ncol(raw) < 11) stop("O CSV precisa ter pelo menos 11 colunas na ordem esperada. Veja data/README_data.md")

names(raw)[1:11] <- c("idProduct", "firm", "product", "price", "shelf_price", "ad_price", "share_pct", "segment", "cals", "fat", "sugar")
num_vars <- c("idProduct", "price", "shelf_price", "ad_price", "share_pct", "cals", "fat", "sugar")
for (v in num_vars) raw[[v]] <- suppressWarnings(readr::parse_number(raw[[v]]))

df <- raw %>%
  filter(tolower(firm) != "basketof", !is.na(segment)) %>%
  filter(if_all(all_of(c("price", "share_pct", "cals", "fat", "sugar")), ~ !is.na(.x))) %>%
  mutate(
    share = share_pct/100,
    outside_share = S0,
    delta = log(share) - log(S0),
    cons = 1,
    idfirm = as.integer(factor(firm)),
    idsegment = as.integer(factor(segment))
  )

for (x in XVARS) {
  total_firm <- df %>% group_by(firm) %>% summarise(tmp = sum(.data[[x]], na.rm = TRUE), .groups = "drop")
  names(total_firm)[2] <- paste0("total_firm_", x)
  df <- df %>% left_join(total_firm, by = "firm")
  df[[paste0("total_all_", x)]] <- sum(df[[x]], na.rm = TRUE)
  df <- df %>% group_by(firm) %>% mutate(!!paste0("n_firm_", x) := n()) %>% ungroup()
  df[[paste0("own_", x)]] <- df[[paste0("total_firm_", x)]] - df[[x]]
  df[[paste0("own_", x)]][df[[paste0("n_firm_", x)]] <= 1] <- 0
  df[[paste0("rival_", x)]] <- df[[paste0("total_all_", x)]] - df[[paste0("total_firm_", x)]]
}

df <- df %>%
  group_by(firm) %>% mutate(n_products_firm = n()) %>% ungroup() %>%
  mutate(n_total_products = n(), n_rival_products = n_total_products - n_products_firm) %>%
  group_by(segment) %>%
  mutate(nest_share = sum(share, na.rm = TRUE),
         share_within_nest = share/nest_share,
         log_share_within_nest = log(share_within_nest),
         n_products_nest = n(),
         n_same_nest_other = n_products_nest - 1) %>%
  ungroup() %>%
  mutate(n_rival_nest = n_total_products - n_products_nest)

for (x in XVARS) {
  total_nest <- df %>% group_by(segment) %>% summarise(tmp = sum(.data[[x]], na.rm = TRUE), .groups = "drop")
  names(total_nest)[2] <- paste0("total_nest_", x)
  df <- df %>% left_join(total_nest, by = "segment")
  df[[paste0("nest_own_", x)]] <- df[[paste0("total_nest_", x)]] - df[[x]]
  df[[paste0("nest_rival_", x)]] <- df[[paste0("total_all_", x)]] - df[[paste0("total_nest_", x)]]
}

df <- df %>% relocate(idProduct, firm, product, segment, price, share, delta, cals, fat, sugar)
saveRDS(df, file.path(OUTDATA, "prepared_data_R.rds"))
readr::write_csv(df, file.path(OUTDATA, "prepared_data_R.csv"))
message("Base preparada: ", nrow(df), " produtos.")
