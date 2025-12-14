#!/bin/bash

# Assemble the bootloader
nasm -f bin -o boot.bin boot.asm

# Assemble the kernel
nasm -f bin -o kernel.bin kernel.asm

# Create a disk image
dd if=/dev/zero of=disk.img bs=512 count=2880

# Write the bootloader to the disk image
dd if=boot.bin of=disk.img conv=notrunc

# Write the kernel to the disk image
dd if=kernel.bin of=disk.img seek=1 conv=notrunc
