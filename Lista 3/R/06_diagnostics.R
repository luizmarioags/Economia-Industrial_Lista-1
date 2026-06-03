# COMENTÁRIOS DETALHADOS
# Este script calcula diagnósticos manuais de primeiro estágio para price e, no nested logit, ln(s_j|g).
# first_stage_diag compara modelo restrito e completo e reporta F parcial e Wald-F robusto manual.

# Diagnóstico de instrumentos
fs_simple <- first_stage_diag(df, c("price"), CHAR_VARS, ZBOTH)
fs_simple$specification <- "simple_logit_both"
fs_nested <- first_stage_diag(df, c("price", "log_share_within_nest"), CHAR_VARS, ZNESTALL)
fs_nested$specification <- "nested_logit"
fs_tab <- rbind(fs_simple, fs_nested)
save_table(fs_tab, "09_first_stage_diagnostics", "Diagnóstico de primeiro estágio", "tab:first-stage")
