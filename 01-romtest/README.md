# ROM Test

This folder contains the code I used to test the initial ROM wiring. I produced two different binaries that I wrote to the Flash ROM. Both of these were produced using Python 3 scripts. At this stage I only had the Z80 and the ROM chips wired up, with LEDs on the bus for debugging/introspection.

The first was a binary filled with `nop` instructions (`0x00`). If it works correctly, then we would expect to see the program counter increment by 1 each machine cycle.

The second was a binary filled with the `jmp` instruction (`0x18`). If this works correctly, then the program counter should increase by `0x18` every second machine cycle.
