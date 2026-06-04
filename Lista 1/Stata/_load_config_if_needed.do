/********************************************************************
 Bloco de segurança: carrega Stata/config.do se os caminhos ainda
 não estiverem definidos. Assim os scripts podem ser rodados tanto
 pelo 00_master.do quanto individualmente.
********************************************************************/

local rootdir "$ROOT"
local rawdir  "$RAW"
local procdir "$PROC"
local tabsdir "$TABS"
local figsdir "$FIGS"
local logsdir "$LOGS"

if `"`procdir'"' == "" {
    di as text "[Stata] Globais ainda não carregados. Tentando rodar Stata/config.do..."

    capture noisily do "Stata/config.do"

    if _rc {
        di as error "[Stata] Não consegui rodar Stata/config.do."
        di as error "[Stata] Rode o projeto a partir da pasta raiz ou ajuste o caminho do config.do."
        exit 601
    }
}

local rootdir "$ROOT"
local rawdir  "$RAW"
local procdir "$PROC"
local tabsdir "$TABS"
local figsdir "$FIGS"
local logsdir "$LOGS"

if `"`rootdir'"' == "" {
    di as error "[Stata] O global ROOT está vazio depois do config.do."
    exit 601
}

if `"`rawdir'"' == "" {
    di as error "[Stata] O global RAW está vazio depois do config.do."
    exit 601
}

if `"`procdir'"' == "" {
    di as error "[Stata] O global PROC está vazio depois do config.do."
    exit 601
}

if `"`tabsdir'"' == "" {
    di as error "[Stata] O global TABS está vazio depois do config.do."
    exit 601
}

if `"`figsdir'"' == "" {
    di as error "[Stata] O global FIGS está vazio depois do config.do."
    exit 601
}

if `"`logsdir'"' == "" {
    di as error "[Stata] O global LOGS está vazio depois do config.do."
    exit 601
}

capture mkdir "$ROOT/data"
capture mkdir "$RAW"
capture mkdir "$PROC"
capture mkdir "$ROOT/output"
capture mkdir "$TABS"
capture mkdir "$FIGS"
capture mkdir "$LOGS"

di as text "[Stata] Caminhos carregados:"
di as text "  ROOT = $ROOT"
di as text "  RAW  = $RAW"
di as text "  PROC = $PROC"
di as text "  TABS = $TABS"
di as text "  FIGS = $FIGS"
di as text "  LOGS = $LOGS"