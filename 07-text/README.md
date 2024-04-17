# Text

My next goal was to output some characters onto the screen. This meant getting access to bitmap fonts (or crafting my own).

I found a font I liked at Dafont called [Minecraftia](https://www.dafont.com/minecraftia.font). Full credit for the font goes to Andrew Tyler. While it's a monospaced bitmap-style font, it only came in ttf format, so I needed a way to convert it to a bitmap.

After some research, I found an excellent script by Jared Sanson at [his personal blog](https://jared.geek.nz/2014/01/custom-fonts-for-microcontrollers/). I'm extremely grateful for him making the script available - it saved me a fair amount of effort. I made some modifications to output an asm file as well as C headers. I used the Pillow library (rather than PIL), running with Python 3.10 on WSL2.

Overall this was a fun project I was able to complete in one night. Conveniently I was able to use all of my work from the previous projects, with very little extra work.
