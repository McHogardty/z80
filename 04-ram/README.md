
# Adding the RAM

This was a fairly simple task, since the pinout for the RAM is identical to the ROM. The main difference was the WE and CS signals. Fortunately, this RAM chip has an active-high chip-select pin, which means that I can just use the same signal as the active-low chip-select signal on the ROM to ensure that only one of the ROM or RAM chips are selected at a time. The active-low write-enable signal was fairly easy to add, since it's just a logical-OR of the active-low MREQ and WR signals from the Z80.

For testing, the assembly initialises the PIO, then attempts to read and write to RAM, outputting data to the PIO for debugging. My plan is to write a more thorough memory testing routine once I have the display outputting text.
