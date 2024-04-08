

PIO_DATA_A = $00
PIO_DATA_B = $01
PIO_CTRL_A = $02
PIO_CTRL_B = $03

PIO_MODE_3 = $cf


    section code

reset:
    ld SP, $ffff

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
    ; for sending each byte. The load instruction for awindex registers is always 16-bit and takes
    ; up a fourth byte prefix each time.
    ; I should come back later and see if there are better techniques, e.g. pushing B onto
    ; the stack.
    ld IY, display_init_sequence
    ld L, end_display_init_sequence - display_init_sequence

    call i2c_transaction

    ; Write out the data.
    ld IY, bitmap_data
    call i2c_data_transaction

loop:
    jp loop

; Transmit the sequence of bytes starting at IX. The byte length should be stored in L.
;
; Modifies: A, B, D, E, L, IY, flags
;
i2c_transaction:
    ld C, PIO_CTRL_A
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


i2c_data_transaction:
    ld C, PIO_CTRL_A
    ld E, PIO_MODE_3
i2c_start_data:
    res 1, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

    ld A, $7a
    call i2c_send_byte
    ld A, $40
    call i2c_send_byte

    ; start at IY, send 256 bytes total, four times.
    ld L, $00
loop_through_data_array_1:
    ld A, (IY)
    cpl
    call i2c_send_byte

    dec L
    inc IY
    jp nz, loop_through_data_array_1
    ld L, $00
loop_through_data_array_2:
    ld A, (IY)
    cpl
    call i2c_send_byte

    dec L
    inc IY
    jp nz, loop_through_data_array_2

    ld L, $00
loop_through_data_array_3:
    ld A, (IY)
    cpl
    call i2c_send_byte

    dec L
    inc IY
    jp nz, loop_through_data_array_3

    ld L, $00
loop_through_data_array_4:
    ld A, (IY)
    cpl
    call i2c_send_byte

    dec L
    inc IY
    jp nz, loop_through_data_array_4


i2c_stop_data:
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
; 9. Set memory addressing mode to horizontal (0x20, 0x00).
; 10. Set contrast control (0x81, 0xFF)
; 11. Set pre-charge period (0xD9, 0x22)
; 12. Set VCOMH deselect level (0xDB, 0x30)
; 13. Set entire display off (0xA4)
; 14. Set normal display (0xA6)
; 15. Set the charge pump (0x8D, 0x14)
; 16. Set display on (0xAF)

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

    ; 9. Set memory addressing mode to horizontal (0x20, 0x00).
    defb $20, $00

    ; 10. Set contrast control (0x81, 0xFF)
    defb $81, $ff

    ; 11. Set pre-charge period (0xD9, 0x22)
    defb $d9, $22

    ; 12. Set VCOMH deselect level (0xDB, 0x30)
    defb $db, $30

    ; 13. Set entire display off (0xA4)
    defb $a4

    ; 14. Set normal display (0xA6)
    defb $a6

    ; 15. Set the charge pump (0x8D, 0x14)
    defb $8d, $14
    
    ; 16. Set display on (0xAF)
    defb $af
end_display_init_sequence:
bitmap_data:
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $7f, $7f
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00
    defb $00, $00, $03, $0f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $7f, $1f, $0f, $07, $03, $00, $00, $00, $00, $00
    defb $00, $e0, $f8, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $7f, $7f, $7f
    defb $7f, $7f, $7f, $1f, $07, $01, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    defb $00, $03, $03, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07, $07
    defb $07, $07, $07, $1f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00
    defb $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    defb $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    defb $00, $00, $04, $0f, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $00, $00, $00, $00
    defb $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    defb $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00
    defb $00, $00, $0c, $fc, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $f8, $f8, $f8
    defb $f8, $f8, $f8, $f8, $f0, $f0, $e0, $e0, $c0, $c0, $80, $80, $00, $00, $00, $00
    defb $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $80
    defb $fc, $fc, $fe, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $fe, $fe, $fe, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
    defb $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff
end_bitmap_data:
