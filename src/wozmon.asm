BITS 64
ORG 0x001E0000

%include 'api/libBareMetal.asm'

RESET:
	; The next two lines are all we need for the RESET on x86-64
	cld			; Clear direction flag
	mov al, escape		; Set so NOTCR sends us to ESCAPE

NOTCR:
	cmp al, backspace_key	; Backspace?
	je BACKSPACE		; Yes.
	cmp al, escape		; ESC?
	je ESCAPE		; Yes.
	inc cl			; Advance text index.
	jns NEXTCHAR		; Auto ESC if > 127.
	
ESCAPE:
	mov al, prompt		; "\"
	call output_char	; Output it.

GETLINE:
	mov al, newline		; CR.
	call output_char	; Output it.
	mov rdi, temp_string	; location of input
	mov cl, 1		; Initialize text index.

BACKSPACE:
	dec cl			; Back up text index.
	js GETLINE		; Beyond start of line, reinitialize.
	; The next six lines are just for BareMetal
	mov al, backspace	; Move back by one character
	call output_char
	mov al, space		; Overwrite the old character with a space
	call output_char
	mov al, backspace
	call output_char	; Move back by one character again

NEXTCHAR:
	call [b_input]		; Key ready?
	jnc NEXTCHAR		; Loop until ready.
				; Keystroke is already in AL
	mov [rdi+rcx], al	; Add to text buffer.
	call output_char	; Display character.

	cmp al, enter_key	; CR?
	jne NOTCR		; No.

	; The next two lines are only needed for calling output below
	mov al, 0x00		; Null terminate the string
	mov [rdi+rcx], al

; Line received

	; DEBUG Display it for now
	mov rsi, temp_string
	call output
	jmp GETLINE

SETSTOR:
SETMODE:
BLSKIP:
NEXTITEM:
NEXTHEX:
DIG:
HEXSHIFT:
NOTHEX:
TONEXTITEM:
RUN:
NOTSTOR:
SETADR:
NXTPRNT:
	mov al, ':'		; ":".
	call output_char	; Output it.
PRDATA:
	mov al, ' '		; Blank.
	call output_char	; Output it.
XAMNEXT:
MOD8CHK:
	jmp NXTPRNT		; Always taken.

PRBYTE:
	push ax			; Save AL for LSD
	shr al, 4		; MSD to LSD position. This replaces 4 LSR opcodes on the 6502
	call PRHEX		; Output hex digit.
	pop ax			; Restore AL.
PRHEX:
	and al, 0x0F		; Mask LSD for hex print.
	or al, '0'		; Add "0".
	cmp al, '9'+1		; Digit?
	jl ECHO			; Yes, output it.
	add al, 7		; Add offset for character.
ECHO:
	call output_char	; Output character.
	ret			; Return.

; Constants
prompt		equ '\'
newline		equ 0x0A
eol		equ 0x00
colon		equ ':'
space		equ 0x20
backspace	equ 0x08
escape		equ 0x1B
enter_key	equ 0x1C
backspace_key	equ 0x0E


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
	call output_char
	pop rax
	and al, 0x0f			; Clear the high 4 bits
	xlatb
	call output_char
	pop rax
	pop rbx
	ret
; -----------------------------------------------------------------------------


hextable: db '0123456789ABCDEF'
tchar: db 0, 0, 0
align 16
temp_string: db 0

; =============================================================================
; EOF
