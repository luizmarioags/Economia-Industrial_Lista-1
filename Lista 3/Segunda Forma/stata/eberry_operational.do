/****************************************************************************************
 eberry_operational.do
 ---------------------------------------------------------------------------------------
 Wrapper operacional inspirado no eberry.do original.

 O eberry original fazia duas coisas centrais:
   1) carregava o b_program.do com: quietly run b_program.do;
   2) definia a base/modelo por globals e chamava gmm_code.

 Esta versão mantém essa lógica, mas deixa Y, X, Z e os nomes dos parâmetros como
 argumentos. Assim, os scripts 02 e 03 conseguem rodar várias especificações e salvar
 os mesmos nomes de estimates usados pelas tabelas e gráficos do pacote.
****************************************************************************************/

quietly run "$ROOT/stata/b_program_operational.do"

capture program drop eberry_fit
program define eberry_fit, eclass
    version 17
    syntax, Y(string) X(string) Z(string) BNAMES(string) [STEP(integer 2) USEFILE(string) BOOTRUN(integer 0)]

    if `"`usefile'"' == "" {
        global BERRY_usefile "$OUTDATA/prepared_data_stata.dta"
    }
    else {
        global BERRY_usefile `"`usefile'"'
    }

    global BERRY_y      `"`y'"'
    global BERRY_x      `"`x'"'
    global BERRY_z      `"`z'"'
    global BERRY_bnames `"`bnames'"'
    global BERRY_step   "`step'"
    global BERRY_bootrun "`bootrun'"
    global BERRY_sampleif ""

    berry_gmm_code
end
