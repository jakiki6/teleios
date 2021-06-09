setup_interrupts:
	lidt [idt]
	ret

isr_div_by_zero:
	int_prologue

	println "Div by 0 you idiot"

	int_epilogue

isr_nop:
	iretq

isr_nmi:
	int_prologue

	println "NMI"
	inc qword [.nmi_count]

	int_epilogue
.nmi_count:
	dq 0
	
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

	align 8
idt:	idt_entry isr_div_by_zero, TRAP_GATE	; we wanna skip it
	idt_entry isr_nop, TRAP_GATE		; debug
	idt_entry isr_nmi, INT_GATE		; NMI
	align 8
.desc:	dw $ - idt
	dd idt
