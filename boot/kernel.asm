	org 0x10000
	bits 32

kmain:

halt:	cli
	hlt
	jmp halt
