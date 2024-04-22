
from bdfparser import Font


font = Font("spleen/spleen-5x8.bdf")


chars_to_output = range(ord(" "), ord("~") + 1)


with open("spleen-5x8.asm", "w") as ASM_FILE:
    for c in chars_to_output:
        columns = [0] * 5
        for row in font.glyph(chr(c)).draw().bindata:
            for i, pixel in enumerate(row):
                col = columns[i] >> 1

                if pixel == '1':
                    col = col | 0x80
                
                columns[i] = col

        ASM_FILE.write(f"    defb {', '.join('0x%.2x' % col for col in columns)}  ; {chr(c)}\n")

