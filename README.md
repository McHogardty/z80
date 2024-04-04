# Breadboard z80

This repo contains code and schematics relating to my breadboard z80 project. I've tried to organise the code into folders that progressed as I built out the board. My general process was to add one component at a time, then write some assembly to test it before moving on to the next component.

I use z88dk/z80asm for assembling the code. This will allow me to also write C code for it in the future.

## Components

This list includes the components I've added so far. I have more that I want to add, but the wiring takes a while and I can really only do it on weekends.

* **Z80 CMOS variant (Z84C0008PEG)**. At the time of writing, these are still manufactured and you can buy a new CMOS chip for a good price from one of the major suppliers. I chose the 8 MHz variant because it seemed to be the most common and all of the other Z80 family chips I purchased were all also available in the 8 MHz variant.
* **512K x 8 multi-purpose Flash (SST39SF040)**. This is far too large for the addressable space, but I got it off eBay and was keen to try it out. I have some AT28C256 chips for ROM as well, but they can sometimes be hard to come by so I was interested in trying out some alternatives.
* **128K x 8 static RAM (AS6C1008)**. Again this was too large for the addressable space, but there were no 64K chips in DIP format.
* **Z80 Peripheral IO chip (Z84C2008PEG)**. This allowed me to latch data for debugging with LEDs, and also to hook up a small display.
* **Adafruit 1.3" OLED display (938)**. This is a 128 x 64 monochrome display that uses I2C by default, but can be converted to using SPI by breaking some jumpers on the back of the board.
* **Quad 2-input OR gates (74HC32)**. This is used to produce the necessary control signals for the RAM and ROM.
* **Quad 2-input NAND gates (74HC00)**. This is used to combine the reset and M1 signals for the PIO chip because they share the same pin.

I also have the following utility components that aren't specific to this project but I still find extremely useful.

* **555 timer circuit (NE555P)**. I can use this to create a manual or low-frequency clock, which is super useful for debugging, particularly at the start.
* **3mm LEDs with buil

## Memory map

For the initial build I decided that I didn't want to implement any ROM paging, so I decided to use 1/8 of the address space for ROM and the remainder for RAM.

* `0x0000` to `0x1FFF`: ROM
* `0x2000` to `0xFFFF`: RAM

## IO address map

I forgot to purchase a line decoder chip, so I have initally only used the Z80 PIO chip, but the intention will be that it start at address `0x00` in the IO address space.

* `0x00` to `0x04`: Z80 PIO
