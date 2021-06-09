setup_interrupts:
	lidt [idt]
	ret

exception_div_by_zero:
	iretq
	
%macro idt_entry 2
	dw (0x10000 + (%1 - $$)) & 0xffff
	dw 0x0010
	db 0
	db %2
	dw ((0x10000 + (%1 - $$)) >> 16) & 0xffff
	dd (0x10000 + (%1 - $$)) >> 32
	dd 0
%endmacro

%define TRAP_GATE 0b10001111
%define INT_GATE 0b10001110

idt:	idt_entry exception_div_by_zero, INT_GATE	; we wanna skip it
	align 8
.desc:	dw $ - idt
	dd idt
