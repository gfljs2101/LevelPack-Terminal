; A simple bootloader
org 0x7c00
bits 16

start:
    mov [boot_drive], dl ; BIOS stores boot drive in dl

    ; Set up the stack
    mov bp, 0x8000
    mov sp, bp

    ; Clear the screen
    mov ah, 0x07 ; Scroll down function
    mov al, 0x00 ; Clear entire window
    mov bh, 0x07 ; White on black
    mov cx, 0x00 ; Top left corner
    mov dx, 0x184f ; Bottom right corner
    int 0x10

    ; Print a loading message
    mov si, loading_msg
    call print_string

    ; Load the kernel from the disk
    mov ah, 0x02        ; Read sectors
    mov al, 4           ; Read 4 sectors (2KB) for the kernel
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Sector 2
    mov dh, 0           ; Head 0
    mov dl, [boot_drive] ; Drive number from BIOS
    mov bx, 0x1000      ; Segment to load to
    mov es, bx
    mov bx, 0x0000      ; Offset

    int 0x13
    jc disk_error

    ; Jump to the loaded kernel
    jmp 0x1000:0x0000

disk_error:
    mov si, disk_error_msg
    call print_string
    jmp $ ; hang forever

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0e
    int 0x10
    jmp print_string
.done:
    ret

loading_msg: db 'Loading LevelPack1218 Terminal...', 0x0d, 0x0a, 0
disk_error_msg: db 'Disk read error!', 0
boot_drive: db 0

times 510 - ($ - $$) db 0
dw 0xaa55
