# Adding the OLED display

This folder contains the code I used to test the OLED display. This was a fairly long journey - my first time bit-banging I2C and my first time working with a display over I2C. The display was an Adafruit 938, which uses an SSD1306 chip internally to drive a 128 x 64 resolution monochrome display. It supports I2C by default (at address 0x3D), but can be converted to SPI by breaking a jumper on the back of the board.

The assembly code for testing only does two things - send the initialisation sequence to the display, and then sends a command to turn the entire display on (irrespective of what is stored in the GDDRAM). As a result of having no RAM at this point, the stack and subroutines weren't available to me, which meant that I had to manually bit-bang the entire command sequence. I probably could have refactored my code to be a bit more concise, but I was mostly just concerned with getting it to work at this point, with the knowledge that I would be creating some I2C subroutines later.

My experience with using the PIO for this task differs slightly from using the 6502 VIA. The VIA only has one mode for each port (equivalent to mode 3 for the PIO). That means that you simply need to write to the data direction register to change pins from input to output (and vice versa). For the PIO, you need to set the mode in the control register and then write the byte to set the direction of each pin. At higher clock frequencies (100 Hz or greater) this probably won't matter too much, but I was running the board at ~4 Hz for debugging and this made it fairly slow.

## Lessons learned

Make sure that you consult the datasheet for your specific display to check what initialisation sequence you need to send.  The display requires a fairly complicated initialisation sequence that involves sending a string of command bytes to the display. The values of these commands are highly specific to the hardware implementation by the manufactuer. After reading several different datasheets and a lot of research I was able to figure out the command sequence.

The other challenge was figuring out how to use the I2C protocol specified by the display. It is possible to send multiple command or data bytes in one transaction (but not both), but this wasn't very explicit in the documentation. After some trial and error I was able to figure it out.
