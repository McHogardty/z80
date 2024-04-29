

PIO_DATA_A = $00
PIO_DATA_B = $01
PIO_CTRL_A = $02
PIO_CTRL_B = $03

CTC_CHAN_0 = $04
CTC_CHAN_1 = $05
CTC_CHAN_2 = $06
CTC_CHAN_3 = $07

PIO_MODE_3 = $cf

    section code


; We're using interrupt mode 2 with the peripheral chips. In this mode, a 16-bit vector is formed from the I register
; as the high byte, and an 8-bit vector placed on the bus by the peripheral.
; We're using the zero page for the vector table. After the hardware reset sequence, the program counter is reset to
; $0000, so we need to make sure that there is a jump instruction to the software reset subroutine.
interrupt_vector_table:
    jp reset   ; 3 bytes.

    ; The CTC requires four interrupt vectors. We are able to specify the high 5 bytes, so we need to skip to $08.
    defs 5, $0 ; 5 bytes
interrupt_ctc_start:
    defw handle_channel_0_interrupt
    defw handle_channel_1_interrupt
    defs 244, $0

reset:
    di

    ld SP, $ffff

    ; Set up the I register and enter interrupt mode 2.
    ld A, interrupt_vector_table>>8
    ld I, A
    im 2
    ei

    ; Mode 3, port B.
    ld A, $cf
    out (PIO_CTRL_B), A
    ; All output.
    ld A, $00
    out (PIO_CTRL_B), A

    ; Initialise the framebuffer control bytes.
    ; 0x3d + write bit = $7a
    ld A, $7a
    ld (framebuffer_control_bytes), A
    ; 01000000 = data only with continuation bit set.
    ld A, $40
    ld (framebuffer_control_bytes + 1), A

    ; Zero out the frame buffer. The technique we use is to fill the first byte with $00,
    ; then copy it to the next byte, and so on. This allows us to use the LDIR instruction.
    ld HL, framebuffer
    ld DE, framebuffer + 1
    ; If the size of the framebuffer is n, then we need to do the copy n - 1 times, since we have filled
    ; the first two bytes.
    ld BC, end_framebuffer - framebuffer - 1
    ld (HL), $00
    ldir

    ; Initialise the display.
    ld HL, display_init_sequence
    ld B, (end_display_init_sequence - display_init_sequence) & $ff  ; LSB of the byte count.
    ld D, (((end_display_init_sequence - display_init_sequence) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction

    ; Write the framebuffer out to the display.
    ld HL, framebuffer_control_bytes
    ld B, (end_framebuffer - framebuffer_control_bytes) & $ff  ; LSB of the byte count.
    ld D, (((end_framebuffer - framebuffer_control_bytes) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction

    ; Turn on the display.
    ld HL, display_on_sequence
    ld B, (end_display_on_sequence - display_on_sequence) & $ff  ; LSB of the byte count.
    ld D, (((end_display_on_sequence - display_on_sequence) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction

    ; Initialise the character coordinates to (1, 1).
    ld A, $01
    ld (character_coordinates), A
    ld (character_coordinates + 1), A
    
    ; Reset the timer counter.
    ld A, 0
    ld (ticks_count), A

    ; Program the interrupt vector for the CTC. I could not find a way to do this in the assembler because I don't think we can
    ; select low-order bytes of symbols.
    ld HL, interrupt_ctc_start
    ld A, L
    and $f8
    out (CTC_CHAN_0), A
    ; Set up channel 1 to count to 123.
    ld A, %11000101  ; Enable interrupts, counter mode, 16 prescalar, time constant follows, falling edge of trigger input.
    out (CTC_CHAN_1), A
    ld A, 12
    out (CTC_CHAN_1), A
    ; We have the output of channel 0 hooked up to the trigger for channel 1 so we can cascade.
    ld A, %00100101  ; Disable interrupts, timer mode, 256 prescalar, time constant follows, trigger on time constant load.
    out (CTC_CHAN_0), A
    ld A, $00
    out (CTC_CHAN_0), A

    ; Write our message out to the display. It is null-terminated.
    ld HL, message
write_message:
    ld A, (ticks_count)
    cp 1
    jp m, write_message
    ld A, 0
    ld (ticks_count), A
    ld A, (HL)
    or A
    jp z, end_write_message
    call char_out
    inc HL
    push HL
    ; Write the framebuffer out to the display.
    ld HL, framebuffer_control_bytes
    ld B, (end_framebuffer - framebuffer_control_bytes) & $ff  ; LSB of the byte count.
    ld D, (((end_framebuffer - framebuffer_control_bytes) - 1) >> 8) + 1  ; MSB of the byte count plus 1.
    call i2c_transaction
    pop HL
    jp write_message
end_write_message:

loop:
    jp loop

message:
    defb "I got the timer circuit working, lesgo!!! :)", 0
endmessage:


; This was originally used for testing but is now not used for anything.
handle_channel_0_interrupt:
    ei
    reti

; Interrupt service routine for CTC channel 1. The CTC is configured to interrupt approximately every 100ms at 8 MHz.
;
; Modifies: AF' (but not AF).
;
handle_channel_1_interrupt:
    ex AF, AF'
    ld A, (ticks_count)
    inc A
    ld (ticks_count), A
exit_channel_1_interrupt:
    ex AF, AF'
    ei
    reti



; Output the ASCII code point stored in A to the next available position. Currently only code points 32 (<sp>) to 126 (~).
; This subroutine internally tracks the next character position in RAM.
;
; Modifies: AF, BC, DE, IX, IY
;
;
char_out:
    push HL
    ; Put the address of the first column of bits into IX. Each character is represented in ROM by 5 bytes,
    ; and we start at code point 32, so each character starts at 5 * (A - 32).
    sub 32
    ; Store 5 * A in BC as follows: put it in HL, double it twice, store A in BC and add it back.
    ld H, $0
    ld L, A
    add HL, HL
    add HL, HL
    ld B, $0
    ld C, A
    add HL, BC
    ld B, H
    ld C, L

    ld IX, font
    add IX, BC

    ; Counter for the loop - there are 5 columns. Each iteration of the loop outputs one column.
    ld B, 5
    ; Re-load our current coordinates.
    ld A, (character_coordinates)
    ld D, A
    ld A, (character_coordinates + 1)
    ld E, A
    
write_pixel_column:
    ; The draw_pixel subroutine modifies BC and we don't want to lose our loop index.
    push BC
    ld A, (IX)   
    bit 0, A
    jp z, write_dark_pixel_0
write_light_pixel_0:
    set 7, E
    jp finish_writing_pixel_0
write_dark_pixel_0:
    res 7, E
finish_writing_pixel_0:
    call draw_pixel
    inc E

    ld A, (IX)
    bit 1, A
    jp z, write_dark_pixel_1
write_light_pixel_1:
    set 7, E
    jp finish_writing_pixel_1
write_dark_pixel_1:
    res 7, E
finish_writing_pixel_1:
    call draw_pixel
    inc E

    ld A, (IX)
    bit 2, A
    jp z, write_dark_pixel_2
write_light_pixel_2:
    set 7, E
    jp finish_writing_pixel_2
write_dark_pixel_2:
    res 7, E
finish_writing_pixel_2:
    call draw_pixel
    inc E

    ld A, (IX)
    bit 3, A
    jp z, write_dark_pixel_3
write_light_pixel_3:
    set 7, E
    jp finish_writing_pixel_3
write_dark_pixel_3:
    res 7, E
finish_writing_pixel_3:
    call draw_pixel
    inc E

    ld A, (IX)
    bit 4, A
    jp z, write_dark_pixel_4
write_light_pixel_4:
    set 7, E
    jp finish_writing_pixel_4
write_dark_pixel_4:
    res 7, E
finish_writing_pixel_4:
    call draw_pixel
    inc E

    ld A, (IX)
    bit 5, A
    jp z, write_dark_pixel_5
write_light_pixel_5:
    set 7, E
    jp finish_writing_pixel_5
write_dark_pixel_5:
    res 7, E
finish_writing_pixel_5:
    call draw_pixel
    inc E

    ld A, (IX)
    bit 6, A
    jp z, write_dark_pixel_6
write_light_pixel_6:
    set 7, E
    jp finish_writing_pixel_6
write_dark_pixel_6:
    res 7, E
finish_writing_pixel_6:
    call draw_pixel
    inc E

    ld A, (IX)
    bit 7, A
    jp z, write_dark_pixel_7
write_light_pixel_7:
    set 7, E
    jp finish_writing_pixel_7
write_dark_pixel_7:
    res 7, E
finish_writing_pixel_7:
    call draw_pixel

    ; Jump back to the top of the column, increment to the next column and continue.
    ld A, E
    sub 7
    ld E, A
    inc D
    inc IX
    pop BC
    dec B
    jp z, fix_up_coords

    ; We can't use djnz because write_pixel_column is more than 127 away from this address :(
    jp write_pixel_column

fix_up_coords:
    pop HL
    ; Check if we have gone past the final column on the screen. If so, reset the column
    ; back to the start and move to the next row of characters. For 5-wide chars, we can fit
    ; 25 on each row, which goes to column 125 with a 1-pixel left-border (0-indexed).
    ; Also check then if we have gone past the final row. With characters 8px high and 1px of space
    ; between them, we can fit 7 rows of characters, ending at row 63.
    ld A, D
    cp 125
    jp m, finish_char_out
    ld D, 1
    ld A, E
    add 9
    cp 63
    ld E, A
    jp m, finish_char_out
    ld E, 1
finish_char_out:
    ld A, D
    ld (character_coordinates), A
    ld A, E
    ld (character_coordinates + 1), A
    ret


; Draw a pixel on the screen. Takes an (x, y) pixel coordinate pair and whether the pixel should be on or off. All of the data
; is passed to this subroutine in DE.
;
; D is expected to contain the x coordinate in the 7 least significant bits. E is expected to contain
; the y coordinate in the 6 least significant bits. The most significant bit of E contains the value of the pixel. The other
; bits of DE are expected to be zero.
;
; DDDDDDDDEEEEEEEE
; 0xxxxxxxp0yyyyyy
;
; Modifies: AF, BC, HL, IY
;
draw_pixel:
    ; Given a coordinate (x, y), the pixel we want to modify lives at 128 * floor(y / 8) + x.
    ld IY, framebuffer
    ld H, 0
    ; Clear the MSB and keep only bits 3, 4, and 5 to clear the remainder of y / 8 and the pixel data.
    ld A, E
    and $38
    ; Divide by 8.
    srl A
    srl A
    srl A
    ld L, A
    ; Multiply by 128 = 2**7 by shifting left 7 bits.
    srl H
    rr L
    ld H, L
    ld L, 0
    rr L
    ; Add x, which is in D.
    ld B, 0
    ld C, D
    add IY, BC
    ; The coordinates are now in HL. Just so we can add 128 * floor(y / 8) to IY using DE. Remember to move DE back.
    ex DE, HL
    add IY, DE

    ; Calculate the mask required to set the particular pixel. The pixel position is given by y mod 8.
    ld A, L
    and $07
    ld B, A
    ld A, $01
    jp z, update_buffer

shift_pixel:
    sla A
    djnz shift_pixel    

    ; Read the framebuffer and set the particular pixel.
update_buffer:
    ld C, (IY)
    bit 7, L
    jp z, reset_pixel
    or C
    jp set_buffer_byte
reset_pixel:
    cpl
    and C
set_buffer_byte:
    ld (IY), A
    ; We remembered to put DE back.
    ex DE, HL
    ret

; Transmit the sequence of bytes starting at HL. Supports a 16-bit loop for the byte length. B should
; contain the LSB of the byte count, and D should contain the MSB + 1 of the byte count. E.g. if the byte count is
; 27, then B should contain 0x1B and D should contain 0x01. The exception occurs if the LSB is 0, since this counts as
; 256 for the purposes of the loop. E.g. if the byte count is 256, then B should contain 0 and D should only contain 1.
;
; Modifies: AF, BC, DE, HL.
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
display_on_sequence:
    defb $7a, 00
    ; 16. Set display on (0xAF)
    defb $af
end_display_on_sequence:

font:
    defb 0x00, 0x00, 0x00, 0x00, 0x00  ;  
    defb 0x00, 0x00, 0x5f, 0x00, 0x00  ; !
    defb 0x00, 0x07, 0x00, 0x07, 0x00  ; "
    defb 0x24, 0x7e, 0x24, 0x7e, 0x24  ; #
    defb 0x44, 0x4a, 0xff, 0x32, 0x00  ; $
    defb 0xc6, 0x30, 0x0c, 0x63, 0x00  ; %
    defb 0x30, 0x4e, 0x59, 0x26, 0x50  ; &
    defb 0x00, 0x00, 0x07, 0x00, 0x00  ; '
    defb 0x00, 0x3c, 0x42, 0x81, 0x00  ; (
    defb 0x00, 0x81, 0x42, 0x3c, 0x00  ; )
    defb 0x54, 0x38, 0x38, 0x54, 0x00  ; *
    defb 0x10, 0x10, 0x7c, 0x10, 0x10  ; +
    defb 0x00, 0x80, 0x60, 0x00, 0x00  ; ,
    defb 0x10, 0x10, 0x10, 0x10, 0x00  ; -
    defb 0x00, 0x00, 0x40, 0x00, 0x00  ; .
    defb 0xc0, 0x30, 0x0c, 0x03, 0x00  ; /
    defb 0x3c, 0x52, 0x4a, 0x3c, 0x00  ; 0
    defb 0x00, 0x44, 0x7e, 0x40, 0x00  ; 1
    defb 0x64, 0x52, 0x52, 0x4c, 0x00  ; 2
    defb 0x24, 0x42, 0x4a, 0x34, 0x00  ; 3
    defb 0x1e, 0x10, 0x7c, 0x10, 0x00  ; 4
    defb 0x4e, 0x4a, 0x4a, 0x32, 0x00  ; 5
    defb 0x3c, 0x4a, 0x4a, 0x30, 0x00  ; 6
    defb 0x06, 0x62, 0x12, 0x0e, 0x00  ; 7
    defb 0x34, 0x4a, 0x4a, 0x34, 0x00  ; 8
    defb 0x0c, 0x52, 0x52, 0x3c, 0x00  ; 9
    defb 0x00, 0x00, 0x48, 0x00, 0x00  ; :
    defb 0x00, 0x80, 0x68, 0x00, 0x00  ; ;
    defb 0x00, 0x18, 0x24, 0x42, 0x00  ; <
    defb 0x28, 0x28, 0x28, 0x28, 0x00  ; =
    defb 0x00, 0x42, 0x24, 0x18, 0x00  ; >
    defb 0x02, 0x51, 0x09, 0x06, 0x00  ; ?
    defb 0x3c, 0x42, 0x5a, 0x5c, 0x00  ; @
    defb 0x7c, 0x12, 0x12, 0x7c, 0x00  ; A
    defb 0x7e, 0x4a, 0x4a, 0x34, 0x00  ; B
    defb 0x3c, 0x42, 0x42, 0x42, 0x00  ; C
    defb 0x7e, 0x42, 0x42, 0x3c, 0x00  ; D
    defb 0x3c, 0x4a, 0x4a, 0x42, 0x00  ; E
    defb 0x7c, 0x12, 0x12, 0x02, 0x00  ; F
    defb 0x3c, 0x42, 0x4a, 0x7a, 0x00  ; G
    defb 0x7e, 0x08, 0x08, 0x7e, 0x00  ; H
    defb 0x00, 0x42, 0x7e, 0x42, 0x00  ; I
    defb 0x40, 0x42, 0x3e, 0x02, 0x00  ; J
    defb 0x7e, 0x08, 0x08, 0x76, 0x00  ; K
    defb 0x3e, 0x40, 0x40, 0x40, 0x00  ; L
    defb 0x7e, 0x0c, 0x0c, 0x7e, 0x00  ; M
    defb 0x7e, 0x0c, 0x30, 0x7e, 0x00  ; N
    defb 0x3c, 0x42, 0x42, 0x3c, 0x00  ; O
    defb 0x7e, 0x12, 0x12, 0x0c, 0x00  ; P
    defb 0x3c, 0x42, 0xc2, 0xbc, 0x00  ; Q
    defb 0x7e, 0x12, 0x12, 0x6c, 0x00  ; R
    defb 0x44, 0x4a, 0x4a, 0x32, 0x00  ; S
    defb 0x02, 0x02, 0x7e, 0x02, 0x02  ; T
    defb 0x3e, 0x40, 0x40, 0x7e, 0x00  ; U
    defb 0x1e, 0x60, 0x60, 0x1e, 0x00  ; V
    defb 0x7e, 0x30, 0x30, 0x7e, 0x00  ; W
    defb 0x66, 0x18, 0x18, 0x66, 0x00  ; X
    defb 0x4e, 0x50, 0x50, 0x3e, 0x00  ; Y
    defb 0x62, 0x52, 0x4a, 0x46, 0x00  ; Z
    defb 0x00, 0xff, 0x81, 0x81, 0x00  ; [
    defb 0x03, 0x0c, 0x30, 0xc0, 0x00  ; \
    defb 0x00, 0x81, 0x81, 0xff, 0x00  ; ]
    defb 0x08, 0x04, 0x02, 0x04, 0x08  ; ^
    defb 0x80, 0x80, 0x80, 0x80, 0x00  ; _
    defb 0x00, 0x01, 0x02, 0x00, 0x00  ; `
    defb 0x20, 0x54, 0x54, 0x78, 0x00  ; a
    defb 0x7f, 0x44, 0x44, 0x38, 0x00  ; b
    defb 0x38, 0x44, 0x44, 0x44, 0x00  ; c
    defb 0x38, 0x44, 0x44, 0x7f, 0x00  ; d
    defb 0x38, 0x54, 0x54, 0x5c, 0x00  ; e
    defb 0x08, 0x7e, 0x09, 0x01, 0x00  ; f
    defb 0x98, 0xa4, 0xa4, 0x5c, 0x00  ; g
    defb 0x7f, 0x04, 0x04, 0x78, 0x00  ; h
    defb 0x00, 0x08, 0x7a, 0x40, 0x00  ; i
    defb 0x80, 0x80, 0x7a, 0x00, 0x00  ; j
    defb 0x7f, 0x10, 0x28, 0x44, 0x00  ; k
    defb 0x00, 0x3f, 0x40, 0x40, 0x00  ; l
    defb 0x7c, 0x18, 0x18, 0x7c, 0x00  ; m
    defb 0x7c, 0x04, 0x04, 0x78, 0x00  ; n
    defb 0x38, 0x44, 0x44, 0x38, 0x00  ; o
    defb 0xfc, 0x24, 0x24, 0x18, 0x00  ; p
    defb 0x18, 0x24, 0x24, 0xfc, 0x00  ; q
    defb 0x78, 0x04, 0x04, 0x0c, 0x00  ; r
    defb 0x48, 0x54, 0x54, 0x24, 0x00  ; s
    defb 0x04, 0x3f, 0x44, 0x40, 0x00  ; t
    defb 0x3c, 0x40, 0x40, 0x7c, 0x00  ; u
    defb 0x1c, 0x60, 0x60, 0x1c, 0x00  ; v
    defb 0x7c, 0x30, 0x30, 0x7c, 0x00  ; w
    defb 0x64, 0x18, 0x18, 0x64, 0x00  ; x
    defb 0x9c, 0xa0, 0xa0, 0x7c, 0x00  ; y
    defb 0x44, 0x64, 0x54, 0x4c, 0x00  ; z
    defb 0x18, 0x7e, 0x81, 0x81, 0x00  ; {
    defb 0x00, 0x00, 0xff, 0x00, 0x00  ; |
    defb 0x81, 0x81, 0x7e, 0x18, 0x00  ; }
    defb 0x10, 0x08, 0x10, 0x10, 0x08  ; ~


    section bss
    org $2000

; RAM data for the frame buffer for a 128 x 64 display. We include two extra bytes at the beginning so that the buffer in RAM is exactly equal to the
; byte sequence required to write to the display using the I2C protocol.
;
; Each byte represents a vertical column of 8 pixels starting from the top-left corner of the screen. The LSB of the byte represents the
; top of the column of pixels, and the MSB is the bottom of the column.
;
; By convention, we define the pixel coordinate system from the top-left to the bottom-right of the display. So, (0,0) is the top-left corner, (127, 0) is the
; top-right corner, (0, 63) is the bottom-left corner and (127, 63) is the bottom-right corner.
;
; Given a pixel coordinate (x, y), the position in the framebuffer is given by x + 128 * floor(y/8), and the particular bit we are writing is
; y mod 8.
; Examples: (0, 0) translates to bit 0 at position 0. (127, 63) translates to bit 7 position 1023.
;
framebuffer_control_bytes:
    defs 2, $00
framebuffer:
    ; The display is 128 x 64 pixels, which is 128 x 8 bytes.
    defs 128*8, $00
end_framebuffer:
; Store the pixel coordinate of the top-left pixel of the next text character.
; The first byte is expected to contain the x coordinate in the 7 least significant bits. The second byte is expected to contain
; the y coordinate in the 6 least significant bits. The other bits are "don't care".
character_coordinates:
    defs 2, $00

; Track the number of 100 ms ticks that have been counted by the CTC channel 1.
ticks_count:
    defb 0