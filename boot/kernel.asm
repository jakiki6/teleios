	org 0x10000
	bits 64

%define FRAMEBUFFER 0xb8000
%define VGA_H 25
%define VGA_W 80

%macro pushaq 0
	push rax
	push rbx
	push rcx
	push rdx
	push rsi
	push rdi
	push rbp
	push r8
	push r9
	push r10
	push r11
	push r12
	push r13
	push r14
	push r15
	pushfq
%endmacro

%macro popaq 0
        popfq
        pop r15
        pop r14
        pop r13
        pop r12
        pop r11
        pop r10
        pop r9
        pop r8
        pop rbp
        pop rdi
        pop rsi
        pop rdx
        pop rcx
        pop rbx
        pop rax
%endmacro


kmain:	mov dx, 0x03d4
	mov al, 0x0a			; cursor shape register
	out dx, al

	inc dx
	mov al, 0x20			; bit 5 -> disable cursor
	out dx, al

	mov rsi, strings.welcome
	call print_string

halt:	cli
	hlt
	jmp halt

print_string:
	; rsi -> null terminated string
	pushaq
.loop:	lodsb
	cmp al, 0
	je .end

	call print_char
	jmp .loop

.end:	popaq
	ret

print_char:
	; al -> char
	pushaq

	mov rdi, qword [.index]

	cmp al, 0x0a
	jne .no_nl

	add rdi, VGA_W * 2		; one full line * entry size

	jmp .end
.no_nl:	cmp al, 0x0d
	jne .no_cr

	sub rdi, FRAMEBUFFER		; get offset in framebuffer
	xchg rdi, rax			; swap
	mov rbx, VGA_W * 2
	div rbx
	mul rbx				; rax = rax // (VGA_W * 2) * (VGA_W * 2)
	xchg rdi, rax			; swap back
	add rdi, FRAMEBUFFER		; add to address

	jmp .end
.no_cr:	stosb
	mov al, 0x1f
	stosb

.end:	cmp rdi, FRAMEBUFFER + (VGA_H * VGA_W * 2)
	jb .no_scroll

	sub rdi, VGA_W * 2
	push rdi

	mov rsi, FRAMEBUFFER
	mov rdi, FRAMEBUFFER - (VGA_W * 2)
	mov rcx, VGA_H + 1
.scroll:
	push rcx

	mov rcx, VGA_W * 2
	rep movsb

	pop rcx
	loop .scroll

	pop rdi
.no_scroll:
	mov qword [.index], rdi
	popaq
	ret

.index:	dq FRAMEBUFFER

strings:
.welcome:
	db "TeleiOS", 0

symbols:
	; format:
	;   name: 240 bytes (null terminated)
	;   address: 8 bytes
        ;   next: 8 bytes (0 -> no next)
.halt:	db "KernelHalt"			; name
	times 239 - ($ - .halt) db 0	; filler
	db 0				; null terminator
	dq halt				; address
	dq 0				; next

free_list: \
	equ 0x30000
	; format:
	;   start: 8 bytes
	;   size: 8 bytes
	;   next: 8 bytes (0 -> no next)
