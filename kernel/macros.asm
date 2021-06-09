%macro prologue 0
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

	mov rbp, rsp
	add rbp, 15 * 8
%endmacro

%macro epilogue 1
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
	ret %1
%endmacro

%macro println 1
	%strlen len %1
	push rsi
	mov rsi, $+19
	push rsi
	call print_string
	pop rsi
	jmp short $+2+len+3
	db %1, 0x0a, 0x0d, 0
	%undef len
%endmacro

%macro print 1
        %strlen len %1
        push rsi
        mov rsi, $+19
	push rsi
        call print_string
        pop rsi
        jmp short $+2+len+1
        db %1, 0
        %undef len
%endmacro
