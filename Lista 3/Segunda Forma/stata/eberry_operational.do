/****************************************************************************************
 eberry_operational.do
 ---------------------------------------------------------------------------------------
 Wrapper operacional para chamar o GMM linear corrigido em b_program_operational.do.
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

    global BERRY_y       `"`y'"'
    global BERRY_x       `"`x'"'
    global BERRY_z       `"`z'"'
    global BERRY_bnames  `"`bnames'"'
    global BERRY_step    "`step'"
    global BERRY_bootrun "`bootrun'"
    global BERRY_sampleif ""

    berry_gmm_code
end
