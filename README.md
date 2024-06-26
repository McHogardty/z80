# Breadboard z80

![Breadboard Z80 after project 9](./images/after-project-9.jpg)

This repo contains code and schematics relating to my breadboard z80 project. I've tried to organise the code into folders that progressed as I built out the board. My general process was to add one component at a time, then write some assembly to test it before moving on to the next component.

I use z88dk/z80asm for assembling the code. This will allow me to also write C code for it in the future.

I'm publishing this code for a few reasons. Firstly, as a record for me in the future, I learned a lot during this project and don't want to forget it. The process of writing it up also helped with my thought process when solving unfamiliar problems. Secondly, I hope it can help someone else who is completing their own hobby projects and needs some assistance. Lastly, I'm pretty proud of this project, it's been one of the most rewarding things I've done.

## Components

This list includes the components I've added so far. I have more that I want to add, but the wiring takes a while and I can really only do it on weekends.

* **Z80 CMOS variant (Z84C0008PEG)**. At the time of writing, these are still manufactured and you can buy a new CMOS chip for a good price from one of the major suppliers. I chose the 8 MHz variant because it seemed to be the most common and all of the other Z80 family chips I purchased were all also available in the 8 MHz variant.
* **512K x 8 multi-purpose Flash (SST39SF040)**. This is far too large for the addressable space, but I got it off eBay and was keen to try it out. I have some AT28C256 chips for ROM as well, but they can sometimes be hard to come by so I was interested in trying out some alternatives.
* **128K x 8 static RAM (AS6C1008)**. Again this was too large for the addressable space, but there were no 64K chips in DIP format.
* **Z80 Peripheral IO chip (Z84C2008PEG)**. This allowed me to latch data for debugging with LEDs, and also to hook up a small display.
* **Adafruit 1.3" OLED display (938)**. This is a 128 x 64 monochrome display that uses I2C by default, but can be converted to using SPI by breaking some jumpers on the back of the board.
* **Quad 2-input OR gates (74HC32)**. This is used to produce the necessary control signals for the RAM and ROM.
* **Quad 2-input NAND gates (74HC00)**. This is used to combine the reset and M1 signals for the PIO chip because they share the same pin.
* **Crystal oscillators (ECS-100AX-xxx)**. I have 1 MHz, 4 MHz and 8 MHz oscillators. The board runs well (as far as I can tell) at 8 MHz.
* **Z80 counter/timer circuit chip (Z84C3008PEG)**. For offloading timer/counter functions to hardware. I'm hoping I can also use it as a baud rate generator later on.
* **3-to-8 line decoder/demultiplexer (74HC138)**. This decoder is used to select the correct peripheral chip during IO cycles.

I also have the following utility components that aren't specific to this project but I still find extremely useful.

* **555 timer circuit (NE555P)**. I can use this to create a manual or low-frequency clock, which is super useful for debugging, particularly at the start.
* **3mm LEDs with built-in resistors**. These were extremely useful in debugging what was happening on the bus, the I2C lines, output ports, etc.
* **Lots of wire**. I use 22 AWG solid core wire. It's fairly pricey, but very reliable and can handle a fair amount of power.
* **Jumper cables**. These are useful for testing, but I would strongly recommend NOT using them for power delivery or for reliable signals at higher clock speeds. They tend to be subpar for those purposes in my experience.
* **100 nF capacitors**. One for each chip as a bypass capacitor to reduce noise.
* **Various electrolytic capacitors**. These go on the power rails to help with noise reduction and also maintaining voltages when there is a significant increase in power draw. I got a set of them from Jaycar with various capacities, e.g. 330 uF, 470 uF.
* **5 V DC adaptor with a 2.1 mm tip and a breakout adaptor**. I don't currently own a benchtop power supply, so I use one of these. Sometimes I use the Arduino power rails powered by USB, particularly if I'm using it as a logic analyser.
* **An SPST switch**. Used for a manual reset circuit.
* **Resistors of various values, mainly 1K**. These are used for pullups on different lines (interrupt, reset, I2C bus lines).

## Memory map

For the initial build I decided that I didn't want to implement any ROM paging, so I decided to use 1/8 of the address space for ROM and the remainder for RAM.

* `0x0000` to `0x1FFF`: ROM
* `0x2000` to `0xFFFF`: RAM

## IO address map

* `0x00` to `0x03`: Z80 PIO
* `0x04` to `0x07`: Z80 CTC

## Schematic

The most up-to-date schematic is shown below and named `schematic` in the [schematics](./schematics) folder.

![schematic](./schematics/schematic.png)
