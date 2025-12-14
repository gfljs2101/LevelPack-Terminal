bits 16

org 0x0000

start:
    ; Initialize data segment
    mov ax, cs
    mov [kernel_boot_drive], dl ; Save boot drive from bootloader
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
    call print_newline

    ; Main loop
    jmp main_loop

main_loop:
    ; Display prompt
    mov si, prompt
    call print_string

    ; Read user input
    call read_line
    call print_newline

    ; Process command
    mov si, buffer
    cmp byte [si], 0
    je main_loop ; if input is empty, loop again

    ; Check for 'cat' command
    mov di, cmd_cat
    mov cx, 4
    repe cmpsb
    je .handle_cat

    ; If not 'cat', try 'help'
    mov si, buffer
    mov di, cmd_help
    mov cx, 5 ; 'help' + null
    repe cmpsb
    je .handle_help

    ; Unknown command
    mov si, unknown_cmd_msg
    call print_string
    jmp main_loop

.handle_cat:
    ; SI should now point to the filename after cmpsb
    ; Trim leading spaces from filename
.trim_loop:
    cmp byte [si], ' '
    jne .trimmed
    inc si
    jmp .trim_loop
.trimmed:
    call find_file_in_root
    jc .file_not_found

    ; AX has inode. Read the file.
    push ax ; Save inode number
    mov ax, cs
    mov es, ax
    mov bx, fs_buffer
    pop ax ; Restore inode number
    call read_file
    jc .read_error

    ; Print file content (assuming it's null-terminated)
    mov si, fs_buffer
    call print_string
    call print_newline
    jmp main_loop

.file_not_found:
    mov si, file_not_found_msg
    call print_string
    jmp main_loop

.read_error:
    mov si, read_error_msg
    call print_string
    jmp main_loop

.handle_help:
    mov si, help_msg
    call print_string
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
.read_loop:
    mov ah, 0x00
    int 0x16 ; Wait for keypress

    cmp al, 0x08 ; Backspace
    je .backspace

    cmp al, 0x0d ; Enter
    je .done

    ; Buffer full?
    mov cx, di
    sub cx, buffer
    cmp cx, 254
    jge .read_loop

    ; Echo character
    mov ah, 0x0e
    int 0x10

    ; Store character
    stosb

    jmp .read_loop

.backspace:
    ; Get current cursor position
    mov ah, 0x03
    xor bh, bh
    int 0x10

    ; Don't delete past the prompt
    cmp dx, [prompt_pos]
    jle .read_loop

    ; Move cursor back, print space, move cursor back again
    mov ah, 0x0e
    mov al, 0x08
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 0x08
    int 0x10

    dec di
    jmp .read_loop

.done:
    ; Null-terminate the string
    mov al, 0
    stosb
    ret

;
; Data
;
welcome_msg: db 'Welcome to LevelPack1218 Terminal!', 0x0d, 0x0a, 0
prompt: db '> ', 0
buffer: times 256 db 0
prompt_pos: dw 0
cmd_cat: db 'cat ', 0
cmd_help: db 'help', 0
unknown_cmd_msg: db 'Unknown command. Type "help" for a list of commands.', 0x0d, 0x0a, 0
file_not_found_msg: db 'File not found.', 0x0d, 0x0a, 0
read_error_msg: db 'Error reading file.', 0x0d, 0x0a, 0
help_msg: db 'Available commands:', 0x0d, 0x0a, '  cat [filename] - Display file content', 0x0d, 0x0a, '  help           - Show this help message', 0x0d, 0x0a, 0

kernel_boot_drive: db 0
fs_buffer: times 512 db 0 ; Shared buffer for FS operations

%include "lpfs.asm"
