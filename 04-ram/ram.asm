

PIO_DATA_A = $00
PIO_DATA_B = $01
PIO_CTRL_A = $02
PIO_CTRL_B = $03


    section code
    ; Reset the PIO.
    ; Mode 3, port A.
    ld A, $cf
    out (PIO_CTRL_A), A
    ; All output.
    ld A, $00
    out (PIO_CTRL_A), A
    ; Mode 3, port B.
    ld A, $cf
    out (PIO_CTRL_B), A
    ; All output.
    ld A, $00
    out (PIO_CTRL_B), A

    ld A, (test_value)
    out (PIO_DATA_A), A

    ld A, $a5
    ld (test_value), A
    ld A, (test_value)
    out (PIO_DATA_B), A

loop:
    jp loop

    section bss
    org $2000

test_value:
    defb 1