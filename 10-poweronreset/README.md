
# Power on reset

I didn't write any code for this iteration, just wired up a power-on-reset IC.

It took quite a bit of research to find a suitable power-on-reset/supervisor IC in a DIP package. There was actually more of a variety than I was expecting. I settled on the ADM707, which was fairly simple but had the main features I was looking for - 5V compatible, a debounced manual reset input and a reset output that is asserted for a minimum period of time after power on. It also has a power failure detection circuit, but I wasn't expecting to need this so I just tied the input to GND.

I could have build this circuit from simpler components, but I was honestly feeling a little lazy, and I wanted to try out a supervisor IC out of interest.

## Lessons learned

This IC was extremely sensitive to power fluctuations and noise. Even just wiggling the power lines was enough to cause it to assert a reset signal. A decoupling capacitor across the VCC and GND pins as well as a larger capacitor across the power rails were both required to get it to work predictably.
