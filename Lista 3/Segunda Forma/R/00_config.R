# 00_config.R ---------------------------------------------------------------
# Configuração comum para a replicação Berry/BLP em R.

get_script_root <- function() {
  candidates <- c(
    tryCatch(dirname(normalizePath(sys.frame(1)$ofile, winslash = "/", mustWork = FALSE)), error = function(e) NA_character_),
    tryCatch(dirname(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE)), error = function(e) NA_character_),
    normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  )
  candidates <- candidates[!is.na(candidates)]
  for (cand in candidates) {
    maybe_root <- normalizePath(file.path(cand, ".."), winslash = "/", mustWork = FALSE)
    if (dir.exists(file.path(maybe_root, "data"))) return(maybe_root)
    if (dir.exists(file.path(cand, "data"))) return(cand)
  }
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

ROOT <- get_script_root()

S0 <- 0.2429
XVARS <- c("cals", "fat", "sugar")
PRICE <- "price"
DELTA <- "delta"
ZOWN <- c("own_cals", "own_fat", "own_sugar")
ZRIVAL <- c("rival_cals", "rival_fat", "rival_sugar")
ZBOTH <- c(ZOWN, ZRIVAL)
ZNEST <- c(
  "n_same_nest_other", "n_rival_nest",
  "nest_own_cals", "nest_own_fat", "nest_own_sugar",
  "nest_rival_cals", "nest_rival_fat", "nest_rival_sugar"
)
ZNESTALL <- c(ZOWN, ZRIVAL, ZNEST)

DATA <- file.path(ROOT, "data", "exemplo.csv")
OUTROOT <- file.path(ROOT, "outputs")
OUT <- file.path(OUTROOT, "R")
LOG_DIR <- file.path(OUT, "logs")
FIGROOT <- file.path(OUT, "figures")
FIGPDF <- file.path(FIGROOT, "pdf")
FIGPNG <- file.path(FIGROOT, "png")
TABROOT <- file.path(OUT, "tables")
TABCSV <- file.path(TABROOT, "csv")
TABTEX <- file.path(TABROOT, "tex")
OUTDATA <- file.path(OUT, "data")

for (d in c(OUTROOT, OUT, LOG_DIR, FIGROOT, FIGPDF, FIGPNG, TABROOT, TABCSV, TABTEX, OUTDATA)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

needed_packages <- c("readr", "dplyr", "tidyr", "ggplot2", "purrr", "MASS", "tibble")
missing_packages <- needed_packages[!vapply(needed_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  message("Pacotes ausentes: ", paste(missing_packages, collapse = ", "))
  message("Instale com: install.packages(c(", paste(sprintf('"%s"', missing_packages), collapse = ", "), "))")
}

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(purrr)
  library(tibble)
})

clean_outputs <- function() {
  unlink(list.files(TABCSV, pattern = "\\.csv$", full.names = TRUE), force = TRUE)
  unlink(list.files(TABTEX, pattern = "\\.tex$", full.names = TRUE), force = TRUE)
  unlink(list.files(FIGPDF, pattern = "\\.pdf$", full.names = TRUE), force = TRUE)
  unlink(list.files(FIGPNG, pattern = "\\.png$", full.names = TRUE), force = TRUE)
}

save_plot_both <- function(p, filename, width = 9, height = 6) {
  ggplot2::ggsave(file.path(FIGPDF, paste0(filename, ".pdf")), p, width = width, height = height)
  ggplot2::ggsave(file.path(FIGPNG, paste0(filename, ".png")), p, width = width, height = height, dpi = 320)
}

theme_blp <- function(base_size = 11) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      panel.grid.major = element_line(linetype = "dashed", linewidth = 0.25),
      panel.grid.minor = element_blank(),
      legend.position = "right",
      plot.title = element_text(face = "bold")
    )
}
