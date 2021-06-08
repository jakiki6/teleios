%define FRAMEBUFFER 0xb8000
%define VGA_H 25
%define VGA_W 80
%define VGA_COLOR 0x1f

print_string:
	; 8 bytes: pointer to null terminated string
	prologue
	mov rsi, qword [rbp]

.loop:	lodsb
	cmp al, 0
	je .end

	push rax
	call print_char
	jmp .loop

.end:	epilogue 8

print_char:
	; 8 byte: char
	prologue
	mov rax, qword [rbp]

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
	xor rdx, rdx
	div rbx
	mul rbx				; rax = rax // (VGA_W * 2) * (VGA_W * 2)
	xchg rdi, rax			; swap back
	add rdi, FRAMEBUFFER		; add to address

	jmp .end
.no_cr:	stosb
	mov al, VGA_COLOR
	stosb

.end:	cmp rdi, FRAMEBUFFER + (VGA_H * VGA_W * 2)
	jb .no_scroll

	sub rdi, VGA_W * 2
	push rdi

	mov rdi, FRAMEBUFFER + (VGA_H * VGA_W * 2)
	mov rcx, VGA_W * 2
	mov ax, 0x20 | (VGA_COLOR << 8)
	rep stosw

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
	epilogue 8

.index:	dq FRAMEBUFFER
