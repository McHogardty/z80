

byte_array = bytearray([0x00] * 2**13)


with open("nop.bin", "wb") as BIN:
    BIN.write(byte_array)
