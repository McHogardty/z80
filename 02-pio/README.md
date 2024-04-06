# Adding the PIO

This folder contains the code I used to test the board once I added the Z80 PIO chip. The premise was to simply configure the chip as required and then simply output patterns to each port that could be observed using LEDs.

The code is pretty simple. On port A it alternates each LED on or off, and flips them each cycle. On port B it switches on two consecutive LEDs and each cycle it shifts them left by one bit.

I have not yet wired up the interrupt line for the PIO. The plan was to try and get the display working before looking at interrupts.

## Lessons learned

You absolutely need to wire up the reset line to the M1 pin on the PIO. I had a lot of problems when plugging the board in, because the Z80 would often run instructions before I could hit the reset button on the board, but in that time it had already sent data to the PIO and misconfigured it. Without the hardware reset I ended up with very weird results.

The PIO also seems to be fairly sensitive to noise on the board. I would get intermittent issues until I added some decoupling capacitors. The Z80 itself and the ROM chip were both performing fine though (based upon my observations of what was happening on the bus using debug LEDs). At this step I also made sure to improve power distribution across the board, as I suspected voltage drops were at play (particularly because of the number of debug LEDs I was using). I ran power distribution wires across both sides of all boards and moved the location of the AC adaptor. This helped significantly and I was measuring 5V across the whole board after I did this (rather than 4.8V furthest from the power supply).

