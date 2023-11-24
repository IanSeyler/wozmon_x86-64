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
; string_compare -- See if two strings match
;  IN:	RSI = string one
;	RDI = string two
; OUT:	Carry flag set if same
string_compare:
	push rsi
	push rdi
	push rbx
	push rax

string_compare_more:
	mov al, [rsi]			; Store string contents
	mov bl, [rdi]
	test al, al			; End of first string?
	jz string_compare_terminated
	cmp al, bl
	jne string_compare_not_same
	inc rsi
	inc rdi
	jmp string_compare_more

string_compare_not_same:
	pop rax
	pop rbx
	pop rdi
	pop rsi
	clc
	ret

string_compare_terminated:
	test bl, bl			; End of second string?
	jnz string_compare_not_same

	pop rax
	pop rbx
	pop rdi
	pop rsi
	stc
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; string_chomp -- Strip leading and trailing spaces from a string
;  IN:	RSI = string location
; OUT:	All registers preserved
string_chomp:
	push rsi
	push rdi
	push rcx
	push rax

	call string_length		; Quick check to see if there are any characters in the string
	jrcxz string_chomp_done	; No need to work on it if there is no data

	mov rdi, rsi			; RDI will point to the start of the string...
	push rdi			; ...while RSI will point to the "actual" start (without the spaces)
	add rdi, rcx			; os_string_length stored the length in RCX

string_chomp_findend:		; we start at the end of the string and move backwards until we don't find a space
	dec rdi
	cmp rsi, rdi			; Check to make sure we are not reading backward past the string start
	jg string_chomp_fail		; If so then fail (string only contained spaces)
	cmp byte [rdi], ' '
	je string_chomp_findend

	inc rdi				; we found the real end of the string so null terminate it
	mov byte [rdi], 0x00
	pop rdi

string_chomp_start_count:		; read through string until we find a non-space character
	cmp byte [rsi], ' '
	jne string_chomp_copy
	inc rsi
	jmp string_chomp_start_count

string_chomp_fail:			; In this situation the string is all spaces
	pop rdi				; We are about to bail out so make sure the stack is sane
	xor al, al
	stosb
	jmp string_chomp_done

; At this point RSI points to the actual start of the string (minus the leading spaces, if any)
; And RDI point to the start of the string

string_chomp_copy:		; Copy a byte from RSI to RDI one byte at a time until we find a NULL
	lodsb
	stosb
	test al, al
	jnz string_chomp_copy

string_chomp_done:
	pop rax
	pop rcx
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; string_parse -- Parse a string into individual words
;  IN:	RSI = Address of string
; OUT:	RCX = word count
; Note:	This function will remove "extra" white-space in the source string
;	"This is  a test. " will update to "This is a test."
string_parse:
	push rsi
	push rdi
	push rax

	xor ecx, ecx			; RCX is our word counter
	mov rdi, rsi

	call string_chomp		; Remove leading and trailing spaces

	cmp byte [rsi], 0x00		; Check the first byte
	je string_parse_done		; If it is a null then bail out
	inc rcx				; At this point we know we have at least one word

string_parse_next_char:
	lodsb
	stosb
	test al, al			; Check if we are at the end
	jz string_parse_done		; If so then bail out
	cmp al, ' '			; Is it a space?
	je string_parse_found_a_space
	jmp string_parse_next_char	; If not then grab the next char

string_parse_found_a_space:
	lodsb				; We found a space.. grab the next char
	cmp al, ' '			; Is it a space as well?
	jne string_parse_no_more_spaces
	jmp string_parse_found_a_space

string_parse_no_more_spaces:
	dec rsi				; Decrement so the next lodsb will read in the non-space
	inc rcx
	jmp string_parse_next_char

string_parse_done:
	pop rax
	pop rdi
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; string_change_char -- Change all instances of a character in a string
;  IN:	RSI = string location
;	AL  = character to replace
;	BL  = replacement character
; OUT:	All registers preserved
string_change_char:
	push rsi
	push rcx
	push rbx
	push rax

	mov cl, al
string_change_char_loop:
	mov byte al, [rsi]
	test al, al
	jz string_change_char_done
	cmp al, cl
	jne string_change_char_no_change
	mov byte [rsi], bl

string_change_char_no_change:
	inc rsi
	jmp string_change_char_loop

string_change_char_done:
	pop rax
	pop rbx
	pop rcx
	pop rsi
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; string_from_int -- Convert a binary integer into an string
;  IN:	RAX = binary integer
;	RDI = location to store string
; OUT:	RDI = points to end of string
;	All other registers preserved
; Min return value is 0 and max return value is 18446744073709551615 so the
; string needs to be able to store at least 21 characters (20 for the digits
; and 1 for the string terminator).
; Adapted from http://www.cs.usfca.edu/~cruse/cs210s09/rax2uint.s
string_from_int:
	push rdx
	push rcx
	push rbx
	push rax

	mov rbx, 10					; base of the decimal system
	xor ecx, ecx					; number of digits generated
string_from_int_next_divide:
	xor edx, edx					; RAX extended to (RDX,RAX)
	div rbx						; divide by the number-base
	push rdx					; save remainder on the stack
	inc rcx						; and count this remainder
	test rax, rax					; was the quotient zero?
	jnz string_from_int_next_divide			; no, do another division

string_from_int_next_digit:
	pop rax						; else pop recent remainder
	add al, '0'					; and convert to a numeral
	stosb						; store to memory-buffer
	loop string_from_int_next_digit			; again for other remainders
	xor al, al
	stosb						; Store the null terminator at the end of the string

	pop rax
	pop rbx
	pop rcx
	pop rdx
	ret
; -----------------------------------------------------------------------------


; -----------------------------------------------------------------------------
; string_to_int -- Convert a string into a binary integer
;  IN:	RSI = location of string
; OUT:	RAX = integer value
;	All other registers preserved
; Adapted from http://www.cs.usfca.edu/~cruse/cs210s09/uint2rax.s
string_to_int:
	push rsi
	push rdx
	push rcx
	push rbx

	xor eax, eax			; initialize accumulator
	mov rbx, 10			; decimal-system's radix
string_to_int_next_digit:
	mov cl, [rsi]			; fetch next character
	cmp cl, '0'			; char precedes '0'?
	jb string_to_int_invalid	; yes, not a numeral
	cmp cl, '9'			; char follows '9'?
	ja string_to_int_invalid	; yes, not a numeral
	mul rbx				; ten times prior sum
	and rcx, 0x0F			; convert char to int
	add rax, rcx			; add to prior total
	inc rsi				; advance source index
	jmp string_to_int_next_digit	; and check another char

string_to_int_invalid:
	pop rbx
	pop rcx
	pop rdx
	pop rsi
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
temp_string1: times 50 db 0
temp_string2: times 50 db 0
align 4096
temp_string: db 0

; =============================================================================
; EOF
