

byte_array = bytearray([0x18] * 2**13)

with open("jmp.bin", "wb") as BIN:
    BIN.write(byte_array)
