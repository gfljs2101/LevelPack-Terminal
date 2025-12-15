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

.trim_leading_whitespace:
    cmp byte [si], ' '
    jne .done_trimming
    inc si
    jmp .trim_leading_whitespace
.done_trimming:

    ; si now points to the first non-space character.
    cmp byte [si], 0
    je .done ; Input was empty or just spaces

    mov bx, si ; Save start of the actual command in bx

    ; Find the end of the command and null-terminate it.
    ; SI will continue from where it is.
.find_end_of_cmd:
    lodsb
    cmp al, ' '
    je .found_space
    cmp al, 0
    je .found_null
    jmp .find_end_of_cmd

.found_space:
    mov byte [si-1], 0 ; Null-terminate the command
    jmp .scan_args
.found_null:
    dec si ; Point to the null terminator
    jmp .scan_args

.scan_args:
    ; Now SI points to the start of the arguments. Let's save it.
    mov [command_args_ptr], si
    mov si, bx         ; Reset SI to the start of the command (from bx).
    mov di, commands   ; DI points to the command table
.cmd_loop:
    cmp byte [di], 0
    je .unknown_cmd

    push si
    push di
    add di, 2 ; Point DI to the command string in the table
.compare_loop:
    mov al, [si]
    mov ah, [di]

    ; Convert input char to lowercase for case-insensitive comparison
    cmp al, 'A'
    jl .al_is_lower
    cmp al, 'Z'
    jg .al_is_lower
    add al, 32
.al_is_lower:

    cmp al, ah
    jne .next_cmd
    cmp al, 0
    je .found_cmd ; Both are null, exact match
    inc si
    inc di
    jmp .compare_loop

.next_cmd:
    pop di
    pop si
    add di, 32 ; Move to the next command entry
    jmp .cmd_loop

.found_cmd:
    pop di ; DI now points to the correct command table entry
    pop si
    mov bx, [di] ; Get the handler address from the start of the entry
    call bx
    jmp .done

.unknown_cmd:
    mov si, unknown_cmd_msg
    call print_string
.done:
    ret

handle_cat:
    mov si, [command_args_ptr]

.skip_whitespace:
    lodsb
    cmp al, ' '
    je .skip_whitespace
    cmp al, 0
    je .no_filename
    dec si ; Found the start of the filename

    ; Now SI points to the filename argument
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

.no_filename:
    mov si, missing_filename_msg
    call print_string
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
command_args_ptr: dw 0
unknown_cmd_msg: db 'Unknown command. Type "help".', 0x0d, 0x0a, 0
file_not_found_msg: db 'File not found.', 0x0d, 0x0a, 0
read_error_msg: db 'Error reading file.', 0x0d, 0x0a, 0
missing_filename_msg: db 'Missing filename for cat.', 0x0d, 0x0a, 0
reboot_msg: db 'Rebooting...', 0x0d, 0x0a, 0
help_msg: db 'Commands: cat, help, cls, ls, reboot', 0x0d, 0x0a, 0

commands:
    dw handle_cat, 'cat', 0
    times 26 db 0
    dw handle_help, 'help', 0
    times 25 db 0
    dw handle_cls, 'cls', 0
    times 26 db 0
    dw handle_ls, 'ls', 0
    times 27 db 0
    dw handle_reboot, 'reboot', 0
    times 23 db 0
    db 0

kernel_boot_drive: db 0
fs_buffer: times 512 db 0

%include "lpfs.asm"
