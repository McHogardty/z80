


PIO_DATA_A = $00
PIO_DATA_B = $01
PIO_CTRL_A = $02
PIO_CTRL_B = $03


    section code

reset:
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
    ; Tracks the LEDs for port A.
    ld A, $55
    ; Tracks the LEDs for port B.
    ld B, $03
    ; We have to use indirect addressing to output from
    ; register B.
    ld C, PIO_DATA_B

loop:
    out (PIO_DATA_A), A
    ; out (PIO_DATA_B), A
    ; Output the value in the B register to the address specified in
    ; C (which is set to  PIO_DATA_B in the reset routine).
    out (C), B
    ; Complement the accumulator.
    cpl
    ; Circular rotate left of register B.
    rlc B
    jp loop