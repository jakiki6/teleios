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

.done:	in al, 0x92		; enable A20 line
	or al, 0x02
	out 0x92, al

	xor edi, edi
	push 0x3000
	pop es
	mov ecx, 0x1000
	xor eax, eax
	rep stosd


	lea eax, dword [es:di + 0x1000]	; pml4
	or eax, 0b11			; present+write
	mov dword [es:di], eax

	mov eax, 0b11			; address 0 + present+write
	mov dword [es:di + 0x1000], eax

	cli
	mov al, 0xff			; disable all irqs
	out 0xa1, al
	out 0x21, al

	nop
	nop

	lidt [idt]

	mov eax, 0b10100000		; set pae and pge bit
	mov cr4, eax

	mov edx, 0x30000		; point to pml4
	mov cr3, edx

	mov ecx, 0xc0000080		; read from efer
	rdmsr

	or eax, 0x00000100		; set lme bit
	wrmsr

	mov ebx, cr0			; activate long mode
	or ebx, 0x80000001		; enable paging and protetion
	mov cr0, ebx

	lgdt [gdt.desc]			; load gdt

	jmp 0x08:long_mode		; JUMP

	align 8
gdt:
.null:	dq 0x0000000000000000		; unused
.code:	dq 0x00209A0000000000		; 64 bit r-x
.data:	dq 0x0000920000000000		; 64 bit rw-
.desc:
	dw gdt.desc - gdt - 1
	dd gdt

	bits 64
long_mode:
	mov ax, 0x10
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax

	mov edi, 0xb8000
	mov rcx, 500
	mov rax, 0x1f201f201f201f20
	rep stosq

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

idt:	dw 0
	dd 0
