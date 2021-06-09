setup_mm:
	mov qword [mm_ptr], 0x400000
	ret

mm_malloc:
	prologue

	mov rsi, qword [mm_ptr]
	push rsi
	add rsi, qword [rbp]
	mov qword [mm_ptr], rsi
	pop r15

	epilogue 8
	ret

mm_free:
	ret 8

mm_ptr:	dq 0
