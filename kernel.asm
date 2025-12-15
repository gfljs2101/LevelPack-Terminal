bits 16
org 0x0000

VIDEO_MEMORY equ 0xb800
SCREEN_WIDTH equ 80
SCREEN_HEIGHT equ 25
WHITE_ON_BLACK equ 0x07

start:
    mov [kernel_boot_drive], dl ; Save boot drive from bootloader
    mov ax, cs
    mov ds, ax
    mov es, ax

    call clear_screen
    mov si, welcome_msg
    call print_string
    call print_newline

main_loop:
    mov si, prompt
    call print_string
    call read_line
    call print_newline
    call execute_command
    jmp main_loop

; ==================================================================
; KERNEL COMMANDS & DISPATCH
; ==================================================================
execute_command:
    mov si, buffer
    cmp byte [si], 0
    je .done

    mov di, commands
.cmd_loop:
    cmp byte [di], 0
    je .unknown_cmd

    push si
    push di
    add di, 2
.compare_loop:
    mov al, [si]
    mov ah, [di]
    cmp al, ah
    jne .next_cmd
    cmp al, 0
    je .found_cmd
    inc si
    inc di
    jmp .compare_loop

.next_cmd:
    pop di
    pop si
    add di, 32
    jmp .cmd_loop

.found_cmd:
    pop di
    pop si
    mov bx, [di - 2]
    call bx
    jmp .done

.unknown_cmd:
    mov si, unknown_cmd_msg
    call print_string
.done:
    ret

handle_cat:
    mov si, buffer + 4
    call find_file_in_root
    jc .file_not_found

    push ax
    mov ax, cs
    mov es, ax
    mov bx, fs_buffer
    pop ax
    call read_file
    jc .read_error

    mov si, fs_buffer
    call print_string
    call print_newline
    ret

.file_not_found:
    mov si, file_not_found_msg
    call print_string
    ret
.read_error:
    mov si, read_error_msg
    call print_string
    ret

handle_help:
    mov si, help_msg
    call print_string
    ret

handle_cls:
    call clear_screen
    ret

handle_reboot:
    mov si, reboot_msg
    call print_string
    mov ax, 0x4F53
    mov bx, 0
    int 0x15 ; Should cause a soft reboot
    jmp $

handle_ls:
    call list_root_directory
    ret

; ==================================================================
; SCREEN & VIDEO FUNCTIONS
; ==================================================================
get_cursor_pos:
    mov ah, 0x03
    xor bh, bh
    int 0x10
    ret

set_cursor_pos:
    mov ah, 0x02
    xor bh, bh
    int 0x10
    ret

scroll_screen:
    mov ah, 0x06
    mov al, 1
    mov bh, WHITE_ON_BLACK
    mov cx, 0
    mov dx, (SCREEN_HEIGHT - 1) * 256 + (SCREEN_WIDTH - 1)
    int 0x10
    ret

clear_screen:
    mov ah, 0x07
    mov al, 0
    mov bh, WHITE_ON_BLACK
    mov cx, 0
    mov dx, (SCREEN_HEIGHT - 1) * 256 + (SCREEN_WIDTH - 1)
    int 0x10
    mov dx, 0
    call set_cursor_pos
    ret

print_char:
    call get_cursor_pos
    cmp dh, SCREEN_HEIGHT - 1
    jl .no_scroll
    call scroll_screen
.no_scroll:
    mov ah, 0x0e
    int 0x10
    ret

print_string:
.loop:
    lodsb
    or al, al
    jz .done
    call print_char
    jmp .loop
.done:
    ret

print_newline:
    call get_cursor_pos
    mov dl, 0
    inc dh
    cmp dh, SCREEN_HEIGHT
    jl .set_pos
    mov dh, SCREEN_HEIGHT - 1
    call scroll_screen
.set_pos:
    call set_cursor_pos
    ret

; ==================================================================
; KEYBOARD & INPUT
; ==================================================================
read_line:
    call get_cursor_pos
    mov [prompt_pos_col], dl

    mov di, buffer
.loop:
    mov ah, 0x00
    int 0x16

    cmp al, 0x08
    je .backspace
    cmp al, 0x0d
    je .done

    mov cx, di
    sub cx, buffer
    cmp cx, 254
    jge .loop

    call print_char
    stosb
    jmp .loop

.backspace:
    call get_cursor_pos
    cmp dl, [prompt_pos_col]
    jle .loop

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
    mov al, 0
    stosb
    ret

; ==================================================================
; DATA
; ==================================================================
welcome_msg: db 'LevelPack1218 Terminal v2.0', 0x0d, 0x0a, 0
prompt: db '>', 0
buffer: times 256 db 0
prompt_pos_col: db 0
unknown_cmd_msg: db 'Unknown command. Type "help".', 0x0d, 0x0a, 0
file_not_found_msg: db 'File not found.', 0x0d, 0x0a, 0
read_error_msg: db 'Error reading file.', 0x0d, 0x0a, 0
reboot_msg: db 'Rebooting...', 0x0d, 0x0a, 0
help_msg: db 'Commands: cat, help, cls, ls, reboot', 0x0d, 0x0a, 0

commands:
    dw handle_cat, 'cat', 0
    times 27 db 0
    dw handle_help, 'help', 0
    times 26 db 0
    dw handle_cls, 'cls', 0
    times 27 db 0
    dw handle_ls, 'ls', 0
    times 28 db 0
    dw handle_reboot, 'reboot', 0
    times 24 db 0
    db 0

kernel_boot_drive: db 0
fs_buffer: times 512 db 0

%include "lpfs.asm"
