#!/bin/bash

# --- Clean up and Assemble ---
rm -f boot.bin kernel.bin disk.img example.txt

nasm -f bin -o boot.bin boot.asm
nasm -f bin -o kernel.bin kernel.asm

# --- Create Disk Image and Filesystem Structures ---

# Create a 1.44MB floppy disk image
dd if=/dev/zero of=disk.img bs=512 count=2880

# Create a dummy superblock at sector 6
# (In a real FS, this would be properly populated)
dd if=/dev/zero of=disk.img bs=512 count=1 seek=6 conv=notrunc

# Create a sample file
echo "Hello from example.txt!" > example.txt

# --- Create Inode Table and Root Directory ---

# Create an empty inode table at sector 7
dd if=/dev/zero of=disk.img bs=512 count=1 seek=7 conv=notrunc

# Create an inode for example.txt at the start of the inode table
filesize=$(stat -c%s example.txt)
# Convert filesize to a 4-byte little-endian hex string
size_hex=$(printf "%08x" $filesize)
size_le_hex=$(echo $size_hex | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')
# Build the first part of the inode: mode (2 bytes) + size (4 bytes) + pointer (4 bytes)
# Mode: 0x81A4 (regular file, rwxr--r--), Pointer: 21 (0x15)
inode_hex_string="A481${size_le_hex}15000000"
# Convert hex string to binary and write to inode table
echo -n $inode_hex_string | xxd -r -p | dd of=disk.img bs=1 seek=$((7*512)) conv=notrunc status=none

# Create an empty root directory block at sector 20
dd if=/dev/zero of=disk.img bs=512 count=1 seek=20 conv=notrunc

# Create a directory entry for example.txt in the root directory
# Inode number (1), name
printf "\x01\x00example.txt" | dd of=disk.img bs=1 seek=$((20*512)) conv=notrunc

# --- Write Binaries and Data to Disk Image ---

# Write the bootloader to the first sector
dd if=boot.bin of=disk.img conv=notrunc

# Write the kernel starting at the second sector
dd if=kernel.bin of=disk.img seek=1 conv=notrunc

# Write the content of example.txt to its data block (sector 21)
dd if=example.txt of=disk.img seek=21 conv=notrunc

echo "Build complete. disk.img is ready."
