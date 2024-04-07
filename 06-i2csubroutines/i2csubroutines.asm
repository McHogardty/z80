
; This I2C test is for interacting with an Adafruit 938 display via the PIO.
; At this point, no RAM was available in the system (just 8K of ROM), so I
; had no subroutine calls or frame buffer. 


PIO_DATA_A = $00
PIO_DATA_B = $01
PIO_CTRL_A = $02
PIO_CTRL_B = $03

PIO_MODE_3 = $cf


    section code


reset:
    ld SP, $ffff

    ; Currently we don't have RAM and there isn't a way to
    ; read the control bits out of the port so we use the D
    ; register to manage the state. We will need the C register to
    ; store the address of the port A control register so that we
    ; can output directly from D.
    ld C, PIO_CTRL_A

    ; Initialise port A in mode 3 (control mode).
    ld A, PIO_MODE_3
    out (PIO_CTRL_A), A
    ; Set the two least significant pins in a high
    ; impedence state. These will be the ones driving
    ; the I2C lines. We will use bit 0 for SCL and bit 1 for SDA.
    ld A, $03
    ld D, A
    out (PIO_CTRL_A), A

    ; Make sure that in output mode the chip is driving the I2C bus low.
    ld A, $00
    out (PIO_DATA_A), A

    ; Store the location and length of the init sequence in the index registers.
    ; Ideally we use the B register since it is made for looping, but we also need it
    ; for sending each byte. The load instruction for index registers is always 16-bit and takes
    ; up a fourth byte prefix each time.
    ; I should come back later and see if there are better techniques, e.g. pushing B onto
    ; the stack.
    ld IY, display_init_sequence
    ld L, end_display_init_sequence - display_init_sequence

    call i2c_transaction

loop:
    jp loop

; Transmit the sequence of bytes starting at IX. The byte length should be stored in L.
;
; Modifies: A, B, D, E, L, IY, flags
;
i2c_transaction:
    ld E, PIO_MODE_3
i2c_start:
    res 1, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

loop_through_byte_array:
    ld A, (IY)
    call i2c_send_byte

    dec L
    inc IY
    jp nz, loop_through_byte_array

i2c_stop:
    ; Bring SDA high AFTER SCL is brought high.
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    set 1, D
    out (C), E
    out (C), D

    ret

; Send the byte currently stored in A. 
;
; Modifies: A, B, flags
i2c_send_byte:
    ld B, $8
    res 0, D
i2c_send_bit:
    rlca
    jp c, i2c_set_high
    res 1, D
    jp i2c_pulse_clock
i2c_set_high:
    set 1, D
i2c_pulse_clock:
    ; Set the data bit.
    out (C), E
    out (C), D
    ; Then pulse the clock.
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    djnz i2c_send_bit

    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, i2c_notify_nack
    set 2, A
    jp i2c_clock_low
i2c_notify_nack:
    set 3, A
i2c_clock_low:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D

    ret


    section data

; We are going to send the set of initialisation commands to get the display to run.
; The display has auto-reset circuitry built-in, which means we don't have to hook
; up the reset pin. We still need to generate the software initialisation sequence.
; These are taken from the data sheet.
; 1. Display off (0xAE)
; 2. Set clock divide ratio/oscillator frequency (0xD5, 0x80)
; 3. Set multiplex ratio (0xA8, 0x3F)
; 4. Set display offset (0xD3, 0x00)
; 5. Set display start line (0x40)
; 6. Set segment remap (0xA1)
; 7. Set COM output scan direction (0xC8)
; 8. Set COM pin hardware configuration (0xDA, 0x12)
; 9. Set contrast control (0x81, 0xFF)
; 10. Set pre-charge period (0xD9, 0x22)
; 11. Set VCOMH deselect level (0xDB, 0x30)
; 12. Set entire display off (0xA4)
; 13. Set normal display (0xA6)
; 14. Set the charge pump (0x8D, 0x14)
; 15. Set display on (0xAF)

display_init_sequence:
    ; Start transaction
    ; 0x3d + write bit = $7a
    defb $7a

    ; Transmit a control byte to indicate that we are sending a command.
    ; 00000000, MSB = continuation bit, we can send a string of command data bytes before a stop condition.
    defb $00

    ; 1. Display off (0xAE)
    defb $ae

    ; 2. Set clock divide ratio/oscillator frequency (0xD5, 0x80)
    defb $d5, $80

    ; 3. Set multiplex ratio (0xA8, 0x3F)
    defb $a8, $3f

    ; 4. Set display offset (0xD3, 0x00)
    defb $d3, $00

    ; 5. Set display start line (0x40)
    defb $40
    
    ; 6. Set segment remap (0xA1)
    defb $a1

    ; 7. Set COM output scan direction (0xC8)
    defb $c8

    ; 8. Set COM pin hardware configuration (0xDA, 0x12)
    defb $da, $12

    ; 9. Set contrast control (0x81, 0xFF)
    defb $81, $ff

    ; 10. Set pre-charge period (0xD9, 0x22)
    defb $d9, $22

    ; 11. Set VCOMH deselect level (0xDB, 0x30)
    defb $db, $30

    ; 12. Set entire display off (0xA4)
    defb $a4

    ; 13. Set normal display (0xA6)
    defb $a6

    ; 14. Set the charge pump (0x8D, 0x14)
    defb $8d, $14
    
    ; 16. Set display on (0xAF)
    defb $af

    ; For testing, set the whole display on.
    defb $a5
end_display_init_sequence: