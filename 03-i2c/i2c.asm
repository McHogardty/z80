
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

; Send the I2C start condition. This occurs when SDA goes low
; before SCL.
i2c_start:
    res 1, D
    ld A, PIO_MODE_3
    out (PIO_CTRL_A), A
    out (C), D
    res 0, D
    out (PIO_CTRL_A), A
    out (C), D
i2c_transmit_address:
    ; Save A for input.
    ld E, PIO_MODE_3
    res 0, D
    ; The address of the display is 0x3C for commands. So we set each data bit and
    ; pulse the clock.
    ; 0 (3 = 011)
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1 (D = 1101)
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0 = write
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
i2c_recv_ack:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack
notify_ack:
    set 2, A
    jp clock_low
notify_nack:
    set 3, A
clock_low:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_control_byte:
    ; Transmit a control byte to indicate that we are sending a command.
    ; 00000000, MSB = continuation bit, we can send a string of command data bytes before a stop condition.
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
i2c_recv_ack_1:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_1
notify_ack_1:
    set 2, A
    jp clock_low_1
notify_nack_1:
    set 3, A
clock_low_1:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D

; 1. Display off (0xAE)
i2c_transmit_display_off:
    ; Send the command byte to turn the display off.
    ; 0xAE = 10101110
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
i2c_recv_ack_2:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_2
notify_ack_2:
    set 2, A
    jp clock_low_2
notify_nack_2:
    set 3, A
clock_low_2:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 2. Set clock divide ratio/oscillator frequency (0xD5, 0x80)

i2c_transmit_clock_divide_ratio_command:
    ; Send the command byte to set the clock divide ratio.
    ; 0xD5 = 11010101
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_3:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_3
notify_ack_3:
    set 2, A
    jp clock_low_3
notify_nack_3:
    set 3, A
clock_low_3:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_clock_divide_ratio_data:
    ; Send the data byte to set the clock divide ratio.
    ; 0x80 = 10000000
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_4:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_4
notify_ack_4:
    set 2, A
    jp clock_low_4
notify_nack_4:
    set 3, A
clock_low_4:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 3. Set multiplex ratio (0xA8, 0x3F)

i2c_transmit_mux_command:
    ; Send the command byte to set the multiplex ratio.
    ; A8 = 10101000
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_5:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_5
notify_ack_5:
    set 2, A
    jp clock_low_5
notify_nack_5:
    set 3, A
clock_low_5:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_mux_data:
    ; Send the data byte to set the multiplex ratio.
    ; 3F = 00111111
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_6:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_6
notify_ack_6:
    set 2, A
    jp clock_low_6
notify_nack_6:
    set 3, A
clock_low_6:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 4. Set display offset (0xD3, 0x00)

i2c_transmit_offset_command:
    ; Send the command byte to set the display offset.
    ; D3 = 11010011
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_7:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_7
notify_ack_7:
    set 2, A
    jp clock_low_7
notify_nack_7:
    set 3, A
clock_low_7:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_offset_data:
    ; Send the data byte to set the display offset.
    ; 00 = 00000000
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_8:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_8
notify_ack_8:
    set 2, A
    jp clock_low_8
notify_nack_8:
    set 3, A
clock_low_8:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D

; 5. Set display start line (0x40)

i2c_transmit_start_line_command:
    ; Send the command byte to set the display start line.
    ; 40 = 01000000
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_9:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_9
notify_ack_9:
    set 2, A
    jp clock_low_9
notify_nack_9:
    set 3, A
clock_low_9:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 6. Set segment remap (0xA1)


i2c_transmit_remap_command:
    ; Send the command byte to set the segment remap register.
    ; A1 = 10100001
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_10:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_10
notify_ack_10:
    set 2, A
    jp clock_low_10
notify_nack_10:
    set 3, A
clock_low_10:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 7. Set COM output scan direction (0xC8)


i2c_transmit_scan_command:
    ; Send the command byte to set the COM output scan direction.
    ; C8 = 11001000
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_11:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_11
notify_ack_11:
    set 2, A
    jp clock_low_11
notify_nack_11:
    set 3, A
clock_low_11:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D

; 8. Set COM pin hardware configuration (0xDA, 0x12)


i2c_transmit_com_pin_command:
    ; Send the command byte to set the COM pin hardware configuration.
    ; DA = 11011010
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_12:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_12
notify_ack_12:
    set 2, A
    jp clock_low_12
notify_nack_12:
    set 3, A
clock_low_12:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_com_pin_data:
    ; Send the data byte to set the COM pin hardware configuration..
    ; 12 = 00010010
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_13:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_13
notify_ack_13:
    set 2, A
    jp clock_low_13
notify_nack_13:
    set 3, A
clock_low_13:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 9. Set contrast control (0x81, 0xFF)

i2c_transmit_contrast_command:
    ; Send the command byte to set the contrast control.
    ; 81 = 10000001
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_14:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_14
notify_ack_14:
    set 2, A
    jp clock_low_14
notify_nack_14:
    set 3, A
clock_low_14:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_contrast_data:
    ; Send the data byte to set the contrast control.
    ; FF = 11111111
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D


i2c_recv_ack_15:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_15
notify_ack_15:
    set 2, A
    jp clock_low_15
notify_nack_15:
    set 3, A
clock_low_15:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D

; 10. Set pre-charge period (0xD9, 0x22)


i2c_transmit_precharge_command:
    ; Send the command byte to set the pre-charge period.
    ; D9 = 11011001
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_16:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_16
notify_ack_16:
    set 2, A
    jp clock_low_16
notify_nack_16:
    set 3, A
clock_low_16:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_precharge_data:
    ; Send the data byte to set the pre-charge period.
    ; 22 = 00100010
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D


i2c_recv_ack_17:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_17
notify_ack_17:
    set 2, A
    jp clock_low_17
notify_nack_17:
    set 3, A
clock_low_17:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 11. Set VCOMH deselect level (0xDB, 0x30)

i2c_transmit_vcomh_deselect_command:
    ; Send the command byte to set the VCOMH deselect level.
    ; DN = 11011011
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D


i2c_recv_ack_18:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_18
notify_ack_18:
    set 2, A
    jp clock_low_18
notify_nack_18:
    set 3, A
clock_low_18:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D



i2c_transmit_vcomh_deselect_data:
    ; Send the data byte to set the VCOMH deselect level.
    ; 30 = 00110000
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D


i2c_recv_ack_19:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_19
notify_ack_19:
    set 2, A
    jp clock_low_19
notify_nack_19:
    set 3, A
clock_low_19:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D

; 12. Set entire display off (0xA4)


i2c_transmit_entire_display_command:
    ; Send the command byte to set the entire display setting off.
    ; A4 = 10100100
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_20:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_20
notify_ack_20:
    set 2, A
    jp clock_low_20
notify_nack_20:
    set 3, A
clock_low_20:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; 13. Set normal display (0xA6)


i2c_transmit_normal_display_command:
    ; Send the command byte to set the display to non-inverted mode.
    ; A6 = 10100110
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_21:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_21
notify_ack_21:
    set 2, A
    jp clock_low_21
notify_nack_21:
    set 3, A
clock_low_21:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D

; 14. Set the charge pump (0x8D, 0x14)


i2c_transmit_charge_pump_command:
    ; Send the command byte to set the charge pump.
    ; 8D = 10001101
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_22:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_22
notify_ack_22:
    set 2, A
    jp clock_low_22
notify_nack_22:
    set 3, A
clock_low_22:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


i2c_transmit_charge_pump_data:
    ; Send the data byte to set the charge pump.
    ; 14 = 00010100
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D


i2c_recv_ack_23:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_23
notify_ack_23:
    set 2, A
    jp clock_low_23
notify_nack_23:
    set 3, A
clock_low_23:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D




; 16. Set display on (0xAF)


i2c_transmit_display_on_command:
    ; Send the command byte to set the display on.
    ; AF = 10101111
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_24:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_24
notify_ack_24:
    set 2, A
    jp clock_low_24
notify_nack_24:
    set 3, A
clock_low_24:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


; For testing, set the whole display on.


i2c_transmit_entire_display_on_command:
    ; Send the command byte to set the entire display on.
    ; A5 = 10100101
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 0
    res 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D
    ; 1
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    res 0, D
    out (C), E
    out (C), D

i2c_recv_ack_25:
    ; Set the data pin to input and pulse the clock to poll for an ack.
    set 1, D
    out (C), E
    out (C), D
    set 0, D
    out (C), E
    out (C), D
    in A, (PIO_DATA_A)
    bit 1, A
    jp nz, notify_nack_25
notify_ack_25:
    set 2, A
    jp clock_low_25
notify_nack_25:
    set 3, A
clock_low_25:
    ; The clock and data pins are currently an input and high, so we need to make sure
    ; that we don't drive the line high when we output the other pin.
    res 0, A
    res 1, A
    out (PIO_DATA_A), A
    res 0, D
    out (C), E
    out (C), D


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

loop:
    jp loop