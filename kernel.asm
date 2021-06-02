org 0x10000
bits 32

halt:	cli
	hlt
	jmp halt
