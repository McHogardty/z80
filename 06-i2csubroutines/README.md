# I2C subroutines

Now that I have got the stack working, I was looking forward to setting up some I2C subroutines and outputting something useful onto the OLED display. I developed two ideas in this subproject. First, how to output a bitmap to the display, and second, how to use a 16-bit loop and handle the I2C transitions in a re-usable subroutine.

This was slightly more challenging than necessary, mainly because I wanted to try and do the entire thing in registers without using memory (except when having to read ROM to load the hard-coded byte sequences that are sent to the display). Having done this, in retrospect I could have further condensed the code in `03-i2c` without needing a stack or extra RAM, but since I was always going to be adding RAM to the board I didn't want to sink too much time into achieving that.

In order to do this entirely in memory, I had to use the shadow registers. While this works, it presents a bit of a complication when wanting to use this display/I2C with more complex programs, particularly if they use interrupts. The original intent of the shadow registers was to support rapid interrupt processing (since `exx` requires only 4 T-states, much fewer than a `push` onto the stack). This is not really compatible with using these registers for I2C bit-banging. I have a few ideas about how to solve that, but they'll need to wait until later.

## Lessons learned

I got some extremely unreliable results when starting out. I was very confused why, because it even seemed as if the clock wasn't cycling. After failing to find anything obvious, I went through my mental checklist, which led me to replace the jumper wires for reset and clock signals with 22 AWG solid core wires. This fixed the problem.

I did not realise until I had some bugs that `djnz` did not work with BC as a 16 bit loop. After some research, I discovered that the best way to perform a 16 bit loop was to use B and D. B contains the LSB of the loop counter, and D contains the MSB + 1. We save quite a few T states by using `djnz` to decrement B, and then use D to track the number of times we need to loop B through 256.

```asm
    ld B, $27
    ld D, $01

loop:
    ; Do stuff.
    djnz loop
    dec D
    jp nz loop
```
