	bits 64
	org 0
	default rel

header:	times 6 nop
	int 0xff	; issue interrupt if executable gets not parsed correctly somehow
	db "teleios", 0	; magic
	dq _start	; entry offset in binary
	dq 65536	; stack size

_start:	; initial registers:
	;   rax: load address
	;   rsp: stack
	;   rsi: first entry of symbol table
	;   rdx: random number for aslr etc
	;   flags: empty
	;   every other register: 0

	jmp $
