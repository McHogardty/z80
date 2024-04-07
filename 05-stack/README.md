
# Setting up the stack

Now that the RAM is running, the next step is to set up the stack and get subroutines going. The test code in this folder sets up the stack and tests that it is working as expected. It is pretty simple - pushing data on and off the stack, and making subroutine calls. I included some nested subroutine calls including storing registers on the stack to test it all end-to-end.

After running the program currently stored in this folder, I would expect to see `0xDC` output on port A and `0xBA` output on port B.

## Lessons learned

I was observing some very weird behaviour with the `ret` instruction the Z80 seemed to consistently increment the program counter by one more than the address stored on the stack. I triple-checked the wiring and assembly code and it was all correct, so it was either a problem with the CPU itself, or there were some issues with the signals that I wasn't able to observe. After measuring some voltages with a multimeter, I was pretty sure that the debug LEDs were impacting the voltages on the bus, not massively, but just enough that in specific situations there might be problems. After removing all of the debug LEDs from the board (except for the ones on the PIO outputs), the problem went away. If I were to do this again, I would buy some line drivers/buffers to drive the LEDs rather than adding the LEDs directly to the bus.
