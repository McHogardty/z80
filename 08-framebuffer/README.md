# Framebuffer

My next goal was to start laying out text on the screen and printing out arbitrary strings. While I could implement some logic specific to the SSD1306, using the paged addressing mode to position the text exactly where I wanted it, I decided I wanted to explore some techniques using framebuffers.

Setting up the framebuffer was easy - I was able to use the I2C code from previous projects with a byte sequence in RAM to output the updated frame to the display.

The tricky part came when calculating where to draw characters. Initially I was using the font bitmaps as bytemasks, but then splitting them across different bytes in the framebuffer became difficult. I ended up stopping that tactic and instead creating a subroutine to draw a single pixel at a particular coordinate. Once this was done, I was able to focus on calculating what pixels to draw for a particular character. This made it much easier than thinking about 8 pixels at a time.

Once I'd managed to get the message output on the display, I decided that I wanted a different font. I found "spleen" after a quick Google search and the Git repository is included as a submodule within this folder. It was 5x8 instead of 6x8 pixels per character which required some modification. I've included the Python script I used to convert the BDF file format to assembly for inclusion within my code.

## Lessons learned

Not all registers are created equal. I found it particularly difficult to use the index registers, because there's no built-in instruction to transfer between the index registers and the other 16 bit registers, unless you use tricky techniques like putting onto the stack.

I started out this project with the expectation that the code would be simple and that it would be "nice", but I was very wrong. I could have removed a lot of complexity if I used the paged addressing mode of the SSD1306, but I wanted to learn more about framebuffers. However, the deeper I went, the more it became clear that this wasn't a simple task. It really gives you a good appreciation for graphics engineers/video game developers.

There are plenty of tricks for doing maths on CPUs with simple instructions, e.g. doubling by adding a register to itself, or dividing by a power of two by shifting left. Once I'd established those, it became easier to think about "nice" ways to do things like multiply by 5.
