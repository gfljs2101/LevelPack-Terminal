#!/bin/bash

# --- Clean up and Assemble ---
rm -f boot.bin kernel.bin disk.img example.txt readme.txt

nasm -f bin -o boot.bin boot.asm
nasm -f bin -o kernel.bin kernel.asm

# --- Create Disk Image and Files ---
dd if=/dev/zero of=disk.img bs=512 count=2880
echo "Hello from example.txt!" > example.txt
echo "This is the README file." > readme.txt

# --- Create Filesystem Structures ---
dd if=/dev/zero of=disk.img bs=512 count=1 seek=6 conv=notrunc # Superblock
dd if=/dev/zero of=disk.img bs=512 count=1 seek=7 conv=notrunc # Inode table
dd if=/dev/zero of=disk.img bs=512 count=1 seek=20 conv=notrunc # Root dir

# --- Create Inode for example.txt (inode 1) ---
filesize=$(stat -c%s example.txt)
size_hex=$(printf "%08x" $filesize)
size_le_hex=$(echo $size_hex | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')
inode_hex="A481${size_le_hex}15000000" # mode=file, pointer=sector 21
echo -n $inode_hex | xxd -r -p | dd of=disk.img bs=1 seek=$((7*512)) conv=notrunc status=none
printf "\x01\x00example.txt" | dd of=disk.img bs=1 seek=$((20*512)) conv=notrunc

# --- Create Inode for readme.txt (inode 2) ---
filesize=$(stat -c%s readme.txt)
size_hex=$(printf "%08x" $filesize)
size_le_hex=$(echo $size_hex | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/')
inode_hex="A481${size_le_hex}16000000" # mode=file, pointer=sector 22
echo -n $inode_hex | xxd -r -p | dd of=disk.img bs=1 seek=$((7*512 + 64)) conv=notrunc status=none
printf "\x02\x00readme.txt" | dd of=disk.img bs=1 seek=$((20*512 + 32)) conv=notrunc

# --- Write Binaries and Data ---
dd if=boot.bin of=disk.img conv=notrunc
dd if=kernel.bin of=disk.img seek=1 conv=notrunc
dd if=example.txt of=disk.img seek=21 conv=notrunc
dd if=readme.txt of=disk.img seek=22 conv=notrunc

echo "Build complete. disk.img is ready."
