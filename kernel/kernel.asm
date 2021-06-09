	org 0x10000
	bits 64

%include "macros.asm"

kmain:	mov dx, 0x03d4
	mov al, 0x0a			; cursor shape register
	out dx, al

	inc dx
	mov al, 0x20			; bit 5 -> disable cursor
	out dx, al

	println "TeleiOS"

;	mov rsi, 0x40000
;	mov rdi, 0xb8000 + (VGA_W * 2 * 3)
;	mov rcx, (VGA_W * 2 * (VGA_H - 3))
;	rep movsb

	println "Setting up MM"
	call setup_mm

	println "Registering interrupts"
	call setup_interrupts

halt:	println "Hanging!"
.hlt	cli
	hlt
	jmp .hlt

%include "vga.asm"
%include "interrupts.asm"
%include "mm.asm"

symbols:
	; format:
	;   name: 240 bytes (null terminated)
	;   address: 8 bytes
	;   next: 8 bytes (0 -> no next)
.halt:	db "KernelHalt"			; name
	times 239 - ($ - .halt) db 0	; filler
	db 0				; null terminator
	dq halt				; address
	dq .print_string		; next
.print_string:
	db "VGAPrintString"		; name
					; filler
	times 239 - ($ - .print_string) db 0
	db 0				; null terminator
	dq print_string			; address
	dq 0				; next

free_list: \
	equ 0x30000
	; format:
	;   start: 8 bytes
	;   size: 8 bytes
	;   next: 8 bytes (0 -> no next)
