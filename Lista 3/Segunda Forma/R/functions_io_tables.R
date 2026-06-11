# functions_io_tables.R ----------------------------------------------------
# Funções de exportação CSV/TEX simples e robustas.

latex_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("_", "\\\\_", x)
  x <- gsub("%", "\\\\%", x)
  x <- gsub("&", "\\\\&", x)
  x <- gsub("#", "\\\\#", x)
  x
}

format_cell <- function(x, digits = 4) {
  if (is.numeric(x)) {
    ifelse(is.na(x), "", formatC(x, digits = digits, format = "f"))
  } else {
    latex_escape(x)
  }
}

write_latex_table <- function(df, path, caption = "Tabela", label = "tab:tabela", digits = 4) {
  con <- file(path, open = "w", encoding = "UTF-8")
  on.exit(close(con), add = TRUE)

  align <- paste0("l", paste(rep("r", max(0, ncol(df)-1)), collapse = ""))

  writeLines("% Tabela gerada automaticamente pela replicação em R", con)
  writeLines("\\begingroup", con)
  writeLines("\\scriptsize", con)
  writeLines(sprintf("\\begin{longtable}{@{}%s@{}}", align), con)
  writeLines(sprintf("\\caption{%s}\\label{%s}\\\\", latex_escape(caption), label), con)
  writeLines("\\toprule", con)
  writeLines(paste0(paste(latex_escape(names(df)), collapse = " & "), " \\\\"), con)
  writeLines("\\midrule", con)
  writeLines("\\endfirsthead", con)
  writeLines("\\toprule", con)
  writeLines(paste0(paste(latex_escape(names(df)), collapse = " & "), " \\\\"), con)
  writeLines("\\midrule", con)
  writeLines("\\endhead", con)

  for (i in seq_len(nrow(df))) {
    vals <- vapply(seq_along(df), function(j) format_cell(df[[j]][i], digits), character(1))
    writeLines(paste0(paste(vals, collapse = " & "), " \\\\"), con)
  }

  writeLines("\\bottomrule", con)
  writeLines("\\end{longtable}", con)
  writeLines("\\endgroup", con)
}

export_csv_tex <- function(df, csv_path, tex_path, caption, label, digits = 4) {
  readr::write_csv(df, csv_path)
  write_latex_table(df, tex_path, caption = caption, label = label, digits = digits)
}
