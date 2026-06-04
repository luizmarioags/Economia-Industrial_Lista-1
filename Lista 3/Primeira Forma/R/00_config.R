# COMENTÁRIOS DETALHADOS
# Este script define caminhos, cria diretórios e guarda constantes globais usadas por todos os demais scripts em R.
# Cada objeto de caminho evita repetir strings longas e reduz risco de salvar saídas no local errado.
# dir.create(..., recursive=TRUE) garante que logs, figuras, tabelas e dados tratados existam antes das exportações.
# S0 fixa o share do bem externo; CHAR_VARS define as características usadas como controles e instrumentos BLP.

# Configuração comum - R
DATA_FILE <- file.path(ROOT, "data", "exemplo.csv")
OUT_ROOT <- file.path(ROOT, "outputs")
OUT <- file.path(OUT_ROOT, "r")
LOG_DIR <- file.path(OUT, "logs")
FIG_PDF <- file.path(OUT, "figures", "pdf")
FIG_PNG <- file.path(OUT, "figures", "png")
TAB_CSV <- file.path(OUT, "tables", "csv")
TAB_TEX <- file.path(OUT, "tables", "tex")
OUT_DATA <- file.path(OUT, "data")
for (d in c(LOG_DIR, FIG_PDF, FIG_PNG, TAB_CSV, TAB_TEX, OUT_DATA)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

S0 <- 0.2429
CHAR_VARS <- c("cals", "fat", "sugar")
PRICE_VAR <- "price"
