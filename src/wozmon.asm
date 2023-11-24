BITS 64
ORG 0x001E0000

%include 'api/libBareMetal.asm'


start:
	mov al, newline		; Output a newline
	call output_char
	mov al, prompt		; Output the prompt
	call output_char
	mov al, newline		; Output a newline
	call output_char

poll:
	mov rdi, temp_string	; Query for keyboard input
	mov rcx, 100		; Accept up to 100 chars
	call input
	jrcxz poll		; input stores the number of characters received in RCX
	mov rsi, rdi
	call hex_string_to_int
	mov rsi, rax
	call dump_rax
	mov al, colon		; Output a newline
	call output_char
	mov al, space		; Output a newline
	call output_char
	lodsb
	call dump_al
	mov al, newline		; Output a newline
	call output_char
	mov al, newline		; Output a newline
	call output_char

	jmp poll


; Constants
prompt		equ '\'
newline		equ 0x0A
eol		equ 0x00
colon		equ ':'
space		equ 0x20
backspace	equ 0x08


; -----------------------------------------------------------------------------
; input -- Take string from keyboard entry
;  IN:	RDI = location where string will be stored
;	RCX = maximum number of characters to accept
; OUT:	RCX = length of string that was received (NULL not counted)
;	All other registers preserved
input:
	push rdi
	push rdx			; Counter to keep track of max accepted characters
	push rax

	mov rdx, rcx			; Max chars to accept
	xor ecx, ecx			; Offset from start

input_more:
	call [b_input]
	jnc input_halt			; No key entered... halt until an interrupt is received
input_process:
	cmp al, 0x1C			; If Enter key pressed, finish
	je input_done
	cmp al, 0x0E			; Backspace
	je input_backspace
	cmp al, 32			; In ASCII range (32 - 126)?
	jl input_more
	cmp al, 126
	jg input_more
	cmp rcx, rdx			; Check if we have reached the max number of chars
	je input_more			; Jump if we have (should beep as well)
	stosb				; Store AL at RDI and increment RDI by 1
	call output_char
	inc rcx				; Increment the counter
	jmp input_more

input_backspace:
	test rcx, rcx			; backspace at the beginning? get a new char
	jz input_more
	dec rcx
	dec rdi
	mov al, backspace
	call output_char
	mov al, space
	call output_char
	mov al, backspace
	call output_char
	jmp input_more

input_halt:
	hlt				; Halt until an interrupt is received
	call [b_input]			; Check if the interrupt was because of a keystroke
	jnc input_halt			; If not, halt again
	jmp input_process

input_done:
	xor al, al
	stosb				; NULL terminate the string
	mov al, newline
	call output_char

	pop rax
	pop rdx
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; output -- Displays text
;  IN:	RSI = message location (zero-terminated string)
; OUT:	All registers preserved
output:
	push rcx

	call string_length
	call [b_output]

	pop rcx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; output_char -- output a single character
output_char:
	push rsi
	push rcx

	mov rsi, tchar
	mov [rsi], al
	mov rcx, 1
	call [b_output]

	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; string_length -- Return length of a string
;  IN:	RSI = string location
; OUT:	RCX = length (not including the NULL terminator)
;	All other registers preserved
string_length:
	push rdi
	push rax

	xor ecx, ecx
	xor eax, eax
	mov rdi, rsi
	not rcx
	repne scasb			; compare byte at RDI to value in AL
	not rcx
	dec rcx

	pop rax
	pop rdi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; hex_string_to_int -- Convert up to 8 hexascii to bin
;  IN:	RSI = Location of hex asciiz string
; OUT:	RAX = binary value of hex string
;	All other registers preserved
hex_string_to_int:
	push rsi
	push rcx
	push rbx

	xor ebx, ebx
hex_string_to_int_loop:
	lodsb
	mov cl, 4
	cmp al, 'a'
	jb hex_string_to_int_ok
	sub al, 0x20				; convert to upper case if alpha
hex_string_to_int_ok:
	sub al, '0'				; check if legal
	jc hex_string_to_int_exit		; jump if out of range
	cmp al, 9
	jle hex_string_to_int_got		; jump if number is 0-9
	sub al, 7				; convert to number from A-F or 10-15
	cmp al, 15				; check if legal
	ja hex_string_to_int_exit		; jump if illegal hex char
hex_string_to_int_got:
	shl rbx, cl
	or bl, al
	jmp hex_string_to_int_loop
hex_string_to_int_exit:
	mov rax, rbx				; integer value stored in RBX, move to RAX

	pop rbx
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; dump_(rax|eax|ax|al) -- Dump content of RAX, EAX, AX, or AL
;  IN:	RAX = content to dump
; OUT:	Nothing, all registers preserved
dump_rax:
	rol rax, 8
	call dump_al
	rol rax, 8
	call dump_al
	rol rax, 8
	call dump_al
	rol rax, 8
	call dump_al
	rol rax, 32
dump_eax:
	rol eax, 8
	call dump_al
	rol eax, 8
	call dump_al
	rol eax, 16
dump_ax:
	rol ax, 8
	call dump_al
	rol ax, 8
dump_al:
	push rbx
	push rax
	mov rbx, hextable
	push rax			; Save RAX since we work in 2 parts
	shr al, 4			; Shift high 4 bits into low 4 bits
	xlatb
	mov [tchar+0], al
	pop rax
	and al, 0x0f			; Clear the high 4 bits
	xlatb
	mov [tchar+1], al
	push rsi
	push rcx
	mov rsi, tchar
	call output
	pop rcx
	pop rsi
	pop rax
	pop rbx
	ret
; -----------------------------------------------------------------------------


hextable: db '0123456789ABCDEF'
tchar: db 0, 0, 0
temp_string: db 0

; =============================================================================
; EOF
