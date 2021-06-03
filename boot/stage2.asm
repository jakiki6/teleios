org 0x8000

stage2:
	mov eax, dword [0x7c00 + 12]	; total blocks
	shl eax, 3			; times sizeof(uint64_t)
	add eax, dword [0x7c00 + 28]	; plus block size
	sub eax, 1			; minus 1
	div dword [0x7c00 + 28]		; divided by the block size
	add eax, 16			; allocation table starts at block 16

	mov dword [directory_start], eax

	mov dword [DAP.lba_lower], eax	; read first sector of directory
        mov word [DAP.offset_segment], 0
        mov word [DAP.offset_offset], buffer

	push ax
	mov ah, 0x42
	mov dl, byte [0x7d00]
	mov si, DAP

	mov bp, errors.read_directory
	clc
	int 0x13
	pop ax
	jc error

	mov bx, 0
	mov bp, errors.find_directory

	mov eax, dword [directory_start]
	jmp .proc

.next:	add bx, 256
	cmp bh, 1
	jne .skip
	inc dword [DAP.lba_lower]
	xor bx, bx

.skip:	push ax
	mov ah, 0x42
        mov dl, byte [0x7d00]
        mov si, DAP

	clc
        int 0x13
	pop ax
        jc error

.proc:	cmp dword [bx+buffer], 0	; end of directory?
	je error
					; normal entry?
	cmp dword [bx+buffer], 0xfffffffd
	je .next

					; deleted entry?
	cmp dword [bx+buffer], 0xfffffffe
        je .next

	cmp byte [bx+buffer+8], 0	; file?
	jne .next

	mov si, buffer + 9		; is filename our kernel?
	mov di, kernel_name
	call strcmp
	jc .next

	mov eax, dword [bx+buffer+240]	; read starting block
	mov cx, 0			; pointer to other buffer

.rd:	mov dword [DAP.lba_lower], eax
        mov word [DAP.offset_segment], 0x1000
        mov word [DAP.offset_offset], cx

	push ax
        mov ah, 0x42
        mov dl, byte [0x7d00]
        mov si, DAP

	mov bp, errors.read_block
	clc
	int 0x13
	pop ax
	jc error

	add cx, 512

	mov ebx, eax
	shr eax, 6			; get index in allocation table
	add eax, 16

	mov dword [DAP.lba_lower], eax
	mov word [DAP.offset_segment], 0
	mov word [DAP.offset_offset], buffer
	
	push ax
        mov ah, 0x42
        mov dl, byte [0x7d00]
        mov si, DAP

	mov bp, errors.read_chain
	clc
        int 0x13
	pop ax
        jc error

	and ebx, 63			; mask to index in sector
	shl ebx, 3			; times size of qword
	add ebx, buffer			; get index in buffer

	mov eax, dword [ebx]
	mov ebx, eax

	mov bp, errors.found_reserved_block
	cmp eax, 0xfffffff0
	je error

	cmp eax, 0xffffffff
	je .done

	shr ebx, 6			; read chain table
	add ebx, 16
	mov dword [DAP.lba_lower], ebx
	push ax
	mov ah, 0x42
	mov dl, byte [0x7d00]
	mov si, DAP

	mov bp, errors.read_chain
        clc
        int 0x13
	pop ax
        jc error

	jmp .rd

.done:	in al, 0x70		; disable NMI
	and al, 0x7f
	out 0x70, al

	in al, 0x92		; enable A20 line
	or al, 0x02
	out 0x92, al

	cli

	lgdt [gdt_desc]

	mov eax, cr0
	or al, 1
	mov cr0, eax

	mov ax, 0x10
	mov ds, ax

	jmp 0x08:.pmode

	bits 32
.pmode:	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax

	xor eax, eax
	xor ebx, ebx
	xor ecx, ecx
	xor edx, edx
	xor esi, esi
	xor edi, edi
	xor ebp, ebp

	mov esp, 0x20000

	push 2
	popfd

	jmp 0x10000

	bits 16
error:
	mov ah, 0x0e
	mov bx, 0x0007
	mov si, bp

.loop:	lodsb
	cmp al, 0
	je .hlt
	int 0x10
	jmp .loop

.hlt:	cli
	hlt
	jmp .hlt

strcmp:	cmp byte [si], 0
	jne .1
	cmp byte [di], 0
	je .success
	jmp .error
.1:	cmpsb
	je strcmp

.error:	stc
.success:
	ret

print_eax:
	pusha
	mov dword [.eax], eax

	mov cx, 8
.loop:	mov bx, .table

	mov edx, eax
	and eax, 0xf0000000
	shr eax, 28
	xlat
	mov ah, 0x0e
	mov bx, 0x0007
	int 0x10
	xchg edx, eax

	shl eax, 4
	loop .loop

	mov ax, 0x0e0a
	mov bx, 0x0007
	int 0x10
	mov al, 0x0d
	int 0x10

	mov eax, dword [.eax]
	popa
	ret
.eax:	dd 0
.table:	db "0123456789abcdef"
.tmp:	dd 0

DAP:
.header:
    db 0x10     ; header
.unused:
    db 0x00     ; unused
.count:  
    dw 0x0001   ; number of sectors
.offset_offset:   
    dw buffer   ; offset
.offset_segment:  
    dw 0x0000   ; offset
.lba_lower:
    dd 0        ; lba
.lba_upper:
    dd 0        ; lba
.end:

buffer:	equ 0xa000

kernel_name:
	db "kernel.bin", 0

directory_start:
	dd 0

errors:
.read_directory:
	db "Cannot read the directory", 0x0a, 0x0d, 0
.find_directory:
	db "Error while finding file in directory", 0x0a, 0x0d, 0
.read_block:
	db "Error while reading a block", 0x0a, 0x0d, 0
.read_chain:
	db "Error while reading a chain entry", 0x0a, 0x0d, 0
.found_reserved_block:
	db "Found reserved block while reading chain", 0x0a, 0x0d, 0

gdt_desc:
	dw gdt_entries.end - gdt_entries - 1
	dd gdt_entries
gdt_entries:
.empty:	dq 0
.code:	dw 0xffff
	dw 0
	db 0
	db 0b10011010
	db 0b11001111
	db 0
.data:	dw 0xffff
	dw 0
	db 0
	db 0b10010010
	db 0b11001111
	db 0
.end:
