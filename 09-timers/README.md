
# Timers

I had two main learning goals for this subproject - firstly, try and get text to write out to the display one character at a time with a slight delay between each character, and secondly, to learn how to use interrupts.

I added a Z80 CTC chip to the board at this stage, which allowed me to offload timing/counting to hardware and use interrupts to increment counters. At this point I had to add an address decoder/demultiplexer to be able to control the chip-select pins for each of the peripheral chips. I used a 74HC138 for this purpose. There are 3 enable pins on this chip, I initially just tied them to VCC or ground depending on their active state. Fortunately all of the peripheral chips that I am currently using have separate IORQ pins, however if I use some non-Z80 family chips in the future, I will need to tie one of the enable pins to IORQ to ensure that the peripheral chips are only selected during an IO cycle. I could also use a 74HC32 to logical-or the IORQ signal with the RD and WR signals if the peripheral chips have RD and/or WR pins.

## Lessons learned

One thing I didn't appreciate very well before this point was how "slow" I2C is relative to the amount of data required to write a frame to the display. The maximum speed for normal I2C is 100kHz. It takes approx. 1000 bytes of data to transmit a full frame to the display, which means that at peak efficiency, you can transmit an entire frame approximately 10 times every second, which is not very fast. A much more efficient way to do this (mainly for text) would be to use paged addressing mode and write out a single character at a time.

A big part of this was learning how to use interrupt mode 2. I really liked the idea of having dedicated interrupt service routines for different purposes. It was a little awkward doing this for the CTC - the way you configure the vector for the CTC is to use D0 set low to indicate that you are writing a control vector and then write to the address for channel 0. The CTC then calculates the vector using the top 5 bits of the vector you provide, and setting D1 and D2 based on which channel generated the interrupt. This means that you can only define the vectors for the CTC in specific places, starting at addresses that are multiples of 8.

After some tweaking, I was fairly sure that my inefficient bit-banging of the I2C protocol was the limiting factor for getting the characters to write out faster to the display. Unfortunately I couldn't really see a way to make it go faster with the PIO (except potentially stop checking for the ack bit after each byte sent). I have some other ideas for future iterations though.
