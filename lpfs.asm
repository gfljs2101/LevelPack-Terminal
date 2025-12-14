; LevelPackFileSystem (LPFS)
bits 16

;
; Constants
;
FS_MAGIC equ 0x4C504653 ; "LPFS"

;
; Data Structures
;

; Superblock: Contains metadata about the file system
superblock:
    .magic_number dd FS_MAGIC
    .total_blocks dd 0
    .inode_blocks dd 0
    .data_blocks dd 0
    .block_size dw 512

; Inode: Represents a file or directory
inode:
    .mode dw 0 ; File type and permissions
    .size dd 0
    .blocks dd 0
    .pointers times 12 dd 0 ; Direct pointers
    .single_indirect dd 0
    .double_indirect dd 0

; Directory Entry
dir_entry:
    .inode_num dd 0
    .name times 28 db 0
