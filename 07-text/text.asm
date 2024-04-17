
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
    out (PIO_CTRL_A), A

    ; Make sure that in output mode the chip is driving the I2C bus low.
    ld A, $00
    out (PIO_DATA_A), A

    ld HL, display_init_sequence
    ld B, (end_display_init_sequence - display_init_sequence) & $ff  ; LSB of the byte count.
    ld D, (((end_display_init_sequence - display_init_sequence) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction

    ld HL, zeroes
    ld B, (end_zeroes - zeroes) & $ff  ; LSB of the byte count.
    ld D, (((end_zeroes - zeroes) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction

    ld HL, display_on_sequence
    ld B, (end_display_on_sequence - display_on_sequence) & $ff  ; LSB of the byte count.
    ld D, (((end_display_on_sequence - display_on_sequence) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction

    ld HL, text_characters
    ld B, (end_text_characters - text_characters) & $ff  ; LSB of the byte count.
    ld D, (((end_text_characters - text_characters) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction


loop:
    jp loop

; Transmit the sequence of bytes starting at HL. Supports a 16-bit loop for the byte length. B should
; contain the LSB of the byte count, and D should contain the MSB + 1 of the byte count. E.g. if the byte count is
; 27, then B should contain 0x1B and D should contain 0x01. The exception occurs if the LSB is 0, since this counts as
; 256 for the purposes of the loop. E.g. if the byte count is 256, then B should contain 0 and D should only contain 1.
;
; Modifies: A. B, C, D, E, HL, flags
;
i2c_transaction:
    exx
    ld D, $03
    ld E, PIO_MODE_3
    ld C, PIO_CTRL_A
i2c_start:
    res 1, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    exx
loop_through_byte_array:
    ld A, (HL)
    exx
    call i2c_send_byte
    exx
    
    ; A faster method for performing a 16-bit loop - store the LSB in B and the MSB + 1 in D.
    ; When B hits zero, dec D and loop through B again (which nets you 256 iterations).
    inc HL
    djnz loop_through_byte_array
    dec D
    jp nz, loop_through_byte_array

i2c_stop:
    exx
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
    exx
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
end_display_init_sequence:
zeroes:
    defb $7a, $40
    defs 16*64, $00
end_zeroes:
display_on_sequence:
    defb $7a, 00
    ; 16. Set display on (0xAF)
    defb $af
end_display_on_sequence:
text_characters:
    defb $7a, $40
    defb 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ;  
    defb 0x5f, 0x00, 0x00, 0x00, 0x00, 0x00 ; !
    defb 0x03, 0x00, 0x03, 0x00, 0x00, 0x00 ; "
    defb 0x14, 0x7f, 0x14, 0x7f, 0x14, 0x00 ; #
    defb 0x24, 0x2a, 0x6b, 0x2a, 0x12, 0x00 ; $
    defb 0x43, 0x30, 0x08, 0x06, 0x61, 0x00 ; %
    defb 0x30, 0x4a, 0x5d, 0x32, 0x48, 0x00 ; &
    defb 0x03, 0x00, 0x00, 0x00, 0x00, 0x00 ; '
    defb 0x1c, 0x22, 0x41, 0x41, 0x00, 0x00 ; (
    defb 0x41, 0x41, 0x22, 0x1c, 0x00, 0x00 ; )
    defb 0x05, 0x02, 0x02, 0x05, 0x00, 0x00 ; *
    defb 0x10, 0x10, 0x7c, 0x10, 0x10, 0x00 ; +
    defb 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00 ; ,
    defb 0x10, 0x10, 0x10, 0x10, 0x10, 0x00 ; -
    defb 0x60, 0x00, 0x00, 0x00, 0x00, 0x00 ; .
    defb 0x40, 0x30, 0x08, 0x06, 0x01, 0x00 ; /
    defb 0x3e, 0x51, 0x49, 0x45, 0x3e, 0x00 ; 0
    defb 0x40, 0x42, 0x7f, 0x40, 0x40, 0x00 ; 1
    defb 0x62, 0x51, 0x49, 0x49, 0x46, 0x00 ; 2
    defb 0x22, 0x41, 0x49, 0x49, 0x36, 0x00 ; 3
    defb 0x18, 0x14, 0x12, 0x11, 0x7f, 0x00 ; 4
    defb 0x00, 0x00                         ; Force a new line. 21 characters x 6 pixels = 126 pixels wide, leaving 2 remaining.
    defb 0x27, 0x45, 0x45, 0x45, 0x39, 0x00 ; 5
    defb 0x3c, 0x4a, 0x49, 0x49, 0x30, 0x00 ; 6
    defb 0x03, 0x01, 0x71, 0x09, 0x07, 0x00 ; 7
    defb 0x36, 0x49, 0x49, 0x49, 0x36, 0x00 ; 8
    defb 0x06, 0x49, 0x49, 0x29, 0x1e, 0x00 ; 9
    defb 0x66, 0x00, 0x00, 0x00, 0x00, 0x00 ; :
    defb 0xe6, 0x00, 0x00, 0x00, 0x00, 0x00 ; ;
    defb 0x08, 0x14, 0x22, 0x41, 0x00, 0x00 ; <
    defb 0x24, 0x24, 0x24, 0x24, 0x24, 0x00 ; =
    defb 0x41, 0x22, 0x14, 0x08, 0x00, 0x00 ; >
    defb 0x02, 0x01, 0x51, 0x09, 0x06, 0x00 ; ?
    defb 0x3e, 0x41, 0x5d, 0x5d, 0x51, 0x5e ; @
    defb 0x7e, 0x05, 0x05, 0x05, 0x7e, 0x00 ; A
    defb 0x7f, 0x45, 0x45, 0x45, 0x3a, 0x00 ; B
    defb 0x3e, 0x41, 0x41, 0x41, 0x22, 0x00 ; C
    defb 0x7f, 0x41, 0x41, 0x41, 0x3e, 0x00 ; D
    defb 0x7f, 0x45, 0x45, 0x41, 0x41, 0x00 ; E
    defb 0x7f, 0x05, 0x05, 0x01, 0x01, 0x00 ; F
    defb 0x3e, 0x41, 0x45, 0x45, 0x3d, 0x00 ; G
    defb 0x7f, 0x04, 0x04, 0x04, 0x7f, 0x00 ; H
    defb 0x41, 0x7f, 0x41, 0x00, 0x00, 0x00 ; I
    defb 0x00, 0x00                         ; Force a new line. 21 characters x 6 pixels = 126 pixels wide, leaving 2 remaining.
    defb 0x20, 0x40, 0x40, 0x40, 0x3f, 0x00 ; J
    defb 0x7f, 0x04, 0x04, 0x0a, 0x71, 0x00 ; K
    defb 0x7f, 0x40, 0x40, 0x40, 0x40, 0x00 ; L
    defb 0x7f, 0x02, 0x04, 0x02, 0x7f, 0x00 ; M
    defb 0x7f, 0x02, 0x04, 0x08, 0x7f, 0x00 ; N
    defb 0x3e, 0x41, 0x41, 0x41, 0x3e, 0x00 ; O
    defb 0x7f, 0x05, 0x05, 0x05, 0x02, 0x00 ; P
    defb 0x3e, 0x41, 0x41, 0x21, 0x5e, 0x00 ; Q
    defb 0x7f, 0x05, 0x05, 0x05, 0x7a, 0x00 ; R
    defb 0x22, 0x45, 0x45, 0x45, 0x39, 0x00 ; S
    defb 0x01, 0x01, 0x7f, 0x01, 0x01, 0x00 ; T
    defb 0x3f, 0x40, 0x40, 0x40, 0x3f, 0x00 ; U
    defb 0x0f, 0x30, 0x40, 0x30, 0x0f, 0x00 ; V
    defb 0x7f, 0x20, 0x10, 0x20, 0x7f, 0x00 ; W
    defb 0x71, 0x0a, 0x04, 0x0a, 0x71, 0x00 ; X
    defb 0x01, 0x02, 0x7c, 0x02, 0x01, 0x00 ; Y
    defb 0x61, 0x51, 0x49, 0x45, 0x43, 0x00 ; Z
    defb 0x7f, 0x41, 0x41, 0x00, 0x00, 0x00 ; [
    defb 0x01, 0x06, 0x08, 0x30, 0x40, 0x00 ; "\"
    defb 0x41, 0x41, 0x7f, 0x00, 0x00, 0x00 ; ]
    defb 0x04, 0x02, 0x01, 0x02, 0x04, 0x00 ; ^
    defb 0x00, 0x00                         ; Force a new line. 21 characters x 6 pixels = 126 pixels wide, leaving 2 remaining.
    defb 0x80, 0x80, 0x80, 0x80, 0x80, 0x00 ; _
    defb 0x00, 0x01, 0x00, 0x00, 0x00, 0x00 ; `
    defb 0x20, 0x54, 0x54, 0x54, 0x78, 0x00 ; a
    defb 0x7f, 0x48, 0x44, 0x44, 0x38, 0x00 ; b
    defb 0x38, 0x44, 0x44, 0x44, 0x28, 0x00 ; c
    defb 0x38, 0x44, 0x44, 0x48, 0x7f, 0x00 ; d
    defb 0x38, 0x54, 0x54, 0x54, 0x58, 0x00 ; e
    defb 0x04, 0x7e, 0x05, 0x05, 0x00, 0x00 ; f
    defb 0x98, 0xa4, 0xa4, 0xa4, 0x7c, 0x00 ; g
    defb 0x7f, 0x08, 0x04, 0x04, 0x78, 0x00 ; h
    defb 0x7d, 0x00, 0x00, 0x00, 0x00, 0x00 ; i
    defb 0x60, 0x80, 0x80, 0x80, 0x7d, 0x00 ; j
    defb 0x7f, 0x10, 0x28, 0x44, 0x00, 0x00 ; k
    defb 0x3f, 0x40, 0x00, 0x00, 0x00, 0x00 ; l
    defb 0x7c, 0x04, 0x18, 0x04, 0x78, 0x00 ; m
    defb 0x7c, 0x04, 0x04, 0x04, 0x78, 0x00 ; n
    defb 0x38, 0x44, 0x44, 0x44, 0x38, 0x00 ; o
    defb 0xfc, 0x28, 0x24, 0x24, 0x18, 0x00 ; p
    defb 0x18, 0x24, 0x24, 0x28, 0xfc, 0x00 ; q
    defb 0x7c, 0x08, 0x04, 0x04, 0x08, 0x00 ; r
    defb 0x48, 0x54, 0x54, 0x54, 0x24, 0x00 ; s
    defb 0x00, 0x00                         ; Force a new line. 21 characters x 6 pixels = 126 pixels wide, leaving 2 remaining.
    defb 0x02, 0x3f, 0x42, 0x00, 0x00, 0x00 ; t
    defb 0x3c, 0x40, 0x40, 0x40, 0x7c, 0x00 ; u
    defb 0x1c, 0x20, 0x40, 0x20, 0x1c, 0x00 ; v
    defb 0x3c, 0x40, 0x70, 0x40, 0x7c, 0x00 ; w
    defb 0x44, 0x28, 0x10, 0x28, 0x44, 0x00 ; x
    defb 0x9c, 0xa0, 0xa0, 0xa0, 0x7c, 0x00 ; y
    defb 0x44, 0x64, 0x54, 0x4c, 0x44, 0x00 ; z
    defb 0x08, 0x36, 0x41, 0x41, 0x00, 0x00 ; {
    defb 0xff, 0x00, 0x00, 0x00, 0x00, 0x00 ; |
    defb 0x41, 0x41, 0x36, 0x08, 0x00, 0x00 ; }
    defb 0x02, 0x01, 0x01, 0x02, 0x02, 0x01 ; ~

end_text_characters: