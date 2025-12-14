bits 16

org 0x0000

start:
    ; Initialize data segment
    mov ax, cs
    mov ds, ax

    ; Set up video memory
    mov ax, 0xb800
    mov es, ax
    mov di, 0

    ; Clear the screen
    mov ax, 0x0720 ; White on black, space character
    mov cx, 2000
    rep stosw

    ; Print welcome message
    mov si, welcome_msg
    call print_string

    ; Main loop
    call main_loop

main_loop:
    ; Display prompt
    mov si, prompt
    call print_string

    ; Read user input
    call read_line

    ; Process command (for now, just echo it)
    mov si, buffer
    call print_string
    call print_newline

    jmp main_loop

print_string:
    mov ah, 0x0e
.loop:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .loop
.done:
    ret

print_newline:
    mov ah, 0x0e
    mov al, 0x0d
    int 0x10
    mov al, 0x0a
    int 0x10
    ret

read_line:
    ; Save the initial cursor position
    mov ah, 0x03
    xor bh, bh
    int 0x10
    mov [prompt_pos], dx

    mov di, buffer
.loop:
    mov ah, 0x00
    int 0x16 ; Wait for keypress

    cmp al, 0x08 ; Backspace
    je .backspace

    cmp al, 0x0d ; Enter
    je .done

    ; Echo character
    mov ah, 0x0e
    int 0x10

    ; Store character
    stosb

    jmp .loop

.backspace:
    ; Get current cursor position
    mov ah, 0x03
    xor bh, bh
    int 0x10

    ; Don't delete past the prompt
    cmp dx, [prompt_pos]
    jle .loop

    ; Move cursor back, print space, move cursor back again
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10

    dec di
    jmp .loop

.done:
    ; Null-terminate the string
    mov al, 0
    stosb
    ret

welcome_msg: db 'Welcome to LevelPack1218 Terminal!', 0x0d, 0x0a, 0
prompt: db '> ', 0
buffer: times 256 db 0
prompt_pos: dw 0

%include "lpfs.asm"
