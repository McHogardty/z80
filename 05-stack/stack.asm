

PIO_DATA_A = $00
PIO_DATA_B = $01
PIO_CTRL_A = $02
PIO_CTRL_B = $03


    section code

reset:
    ld SP, $ffff

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

start:
    ld DE, $4102
    ld A, E
    out (PIO_DATA_A), A
    push DE
    ld DE, $9876
    ld A, D
    out (PIO_DATA_B), A
    pop DE
    ld A, D
    out (PIO_DATA_B), A
    ld DE, $fedc
    call output_port_a
loop:
    jp loop
output_port_a:
    call output_port_b
    ld A, E
    out (PIO_DATA_A), A
    ret
loop_1:
    jp loop_1
output_port_b:
    push DE
    ld DE, $ba98
    ld A, D
    out (PIO_DATA_B), A
    pop DE
    ret
loop_2:
    jp loop_2