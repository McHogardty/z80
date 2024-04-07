# I2C subroutines

This folder is a work in progress. I'm planning on writing out a bitmap to the display.

Now that I have got the stack working, I was looking forward to setting up some I2C subroutines and outputting something useful onto the OLED display.

This example is not entirely focused on subroutines, but more about using the display now that I have RAM and a stack. In fact, I really only need one subroutine for this, which is one that completes an I2C transaction. On reflection I could have condensed the code in `03-i2c` using these techniques, but I was excited to add the RAM chip so I decided not to.

## Lessons learned

I got some extremely unreliable results when starting out. I was very confused why, because it even seemed as if the clock wasn't cycling. After failing to find anything obvious, I went through my mental checklist, which led me to replace the jumper wires for reset and clock signals with 22 AWG solid core wires. This fixed the problem.
