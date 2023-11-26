; wozmon x86-64
; Converted by Ian Seyler (ian@seyler.me)
;
; 6502 to x86-64 register mapping
; A = AL
; X = RBX
; Y = RCX
; Variable XAM = RDX
;
; Notes - Capital letter are expected for input
; The original variables XAML and XAMH are not used


BITS 64
ORG 0x001E0000

%include 'api/libBareMetal.asm'

RESET:
				; Clear decimal arithmetic mode.
				;
	mov cl, 0x7F		; Mask for DSP data direction register.
				; Set it up.
				; KBD and DSP control register mask.
				; Enable interrupt, set CA1, CB1, for
				;  positive edge sense/output mode.

	; The remaining lines are all we need for the RESET on x86-64
	cld			; Clear direction flag
	mov rdi, temp_string	; Base address of input (IN)

NOTCR:
	cmp al, backspace_key	; Backspace?
	je BACKSPACE		; Yes.
	cmp al, escape		; ESC?
	je ESCAPE		; Yes.
	inc cl			; Advance text index.
	jns NEXTCHAR		; Auto ESC if > 127.

ESCAPE:
	mov al, newline
	call ECHO
	mov al, prompt		; "\"
	call ECHO		; Output it.

GETLINE:
	mov al, newline		; CR.
	call ECHO		; Output it.
	mov rcx, 1		; Initialize text index.

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
				; Load character. B7 should be '1'.
	mov [rdi+rcx], al	; Add to text buffer.
	call ECHO		; Display character.
	cmp al, enter_key	; CR?
	jne NOTCR		; No.

; DEBUG Start - This just echos what was input
;	mov al, 0x00
;	mov [rdi+rcx], al
;	mov rsi, temp_string
;	call output
;	jmp GETLINE
; DEBUG end

; Here be dragons!

	mov cl, 0xFF		; Reset text index.
	mov al, 0x00		; For XAM mode.
	mov bx, ax		; 0 -> X.

SETSTOR:
	shl al, 1		; Leaves $7B if setting STOR mode
SETMODE:
	mov [MODE], al		; $00 = XAM, $7B = STOR, $AE = BLOK XAM
BLSKIP:
	inc cl			; Advance text index.
NEXTITEM:
	mov al, [rdi+rcx]	; Get character.
	cmp al, enter_key	; CR?
	je GETLINE		; Yes, done this line.
	cmp al, '.'		; "."?
	; TODO - check value. On Apple 1 '.' is AE
	jc BLSKIP		; Skip delimiter.
	je SETMODE		; Set BLOCK XAM mode.
	cmp al, ':'		; ":"?
	; TODO - check value. On Apple 1 ':' is BA
	je SETSTOR		; Yes, set STOR mode.
	cmp al, 'r'		; "R"?
	je RUN			; Yes, run user program.
	xor rdx, rdx
;	mov [L], bl		; $0 -> L.
;	mov [H], bl		; and H.
	mov [YSAV], cl		; Save Y for comparison.
NEXTHEX:
	mov al, [rdi+rcx]	; Get character for hex test.
	xor al, 0x30		; Map digits $0-9
	cmp al, 0x0A		; Digit?
	jl DIG			; Yes.
	add al, 0x89		; Map letter "A"-"F" to $FA-$FF
	cmp al, 0xFA		; Hex letter?
	jc NOTHEX		; No, character not hex.

	; To be removed
;	and al, 0x0F
DIG:
	shl al, 4		; Hex digit to MSD of A
	mov bx, 0x04		; Shift count.
HEXSHIFT:
	shl al, 1		; Hex digit left, MSB to carry.
	rcl rdx, 1
;	rol byte [L], 1		; Rotate into LSD.
;	rol byte [H], 1		; Rotate into MSD's.
	dec bl			; Done 4 shifts?
	jne HEXSHIFT		; No, loop.
	inc cl			; Advance text index.
	; TODO conditional jump like original?
	jmp NEXTHEX		; Always taken. Check next character for hex.
NOTHEX:
	cmp cl, byte [YSAV]	; Check if L, H empty (no hex digits).
	je ESCAPE		; Yes, generate ESC sequence.
				; Test MODE byte.
	; TODO conditional jump
	jmp NOTSTOR		; B6 = 0 for STOR, 1 for XAM and BLOCK XAM
	mov al, dl;[L]		; LSD's of hex data.
				; Store at current 'store index'
				; Increment store index.
				; Get next item. (no carry).
				; Add carry to 'store index' high order.

TONEXTITEM:
	jmp NEXTITEM		; Get next command item.

RUN:
;	call [XAM]		; Run at current XAM index.
NOTSTOR:
	jmp XAMNEXT		; B7 = 0 for XAM, 1 for BLOCK XAM
	mov bx, 0x02		; Byte count.
SETADR:
				; Copy hex data to
				; 'store index'.
				; And to 'XAM index'.
				; Next of 2 bytes.
				; Loop unless X = 0.
NXTPRNT:
;	jne PRDATA		; NE means no address to print.
	mov al, newline
	call ECHO
	mov al, newline		; CR.
	call ECHO		; Output it.
	; The next 4 lines differ due to running with 64-bit addresses
	mov rax, rdx		; 'Examine index' high-order byte
	call dump_rax		; Output it in hex format.
				; Low-order 'examine index' byte
				; Output it in hex format.
	mov al, ':'		; ":".
	call ECHO		; Output it.
PRDATA:
	mov al, ' '		; Blank.
	call ECHO		; Output it.
	mov al, byte [rdx+rbx]	; Get data byte at `examine index`
	call PRBYTE		; Output it in hex format.
	jmp GETLINE
XAMNEXT:
				; 0 -> MODE (XAM mode).
;	mov al, [rdx]
;	inc rdx
;	mov al, [XAML]
				; Compare 'examine index' to hex data.
;	mov al, [XAMH]
	; TODO Conditional jump
;	jmp TONEXTITEM		; Not less, so no more data to output.
;	inc byte [XAML]
;	jne MOD8CHK		; Increment 'examine index'.
;	inc byte [XAMH]

MOD8CHK:
;	mov rax, rdx		; Check low-order 'examine index' byte
;	and al, 0x07		; For MOD 8 = 0
	jmp NXTPRNT		; Always taken.

PRBYTE:
	push ax			; Save A for LSD.
	shr al, 4		; MSD to LSD position.
	call PRHEX		; Output hex digit.
	pop ax			; Restore A.
PRHEX:
	and al, 0x0F		; Mask LSD for hex print.
	or al, '0'		; Add "0".
	cmp al, '9'+1		; Digit?
	jl ECHO			; Yes, output it.
	add al, 7		; Add offset for character.
ECHO:
				; DA bit (B7) cleared yet?
				; No, wait for display.
	call output_char	; Output character.
	ret			; Return.

align 16
; Variables
XAM		dq 0x0000000000000000
XAML		db 0x00
XAMH		db 0x00
STL		db 0x00
STH		db 0x00
L		db 0x00
H		db 0x00
YSAV		db 0x00
MODE		db 0x00


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
	call PRBYTE
	ret
; -----------------------------------------------------------------------------


tchar: db 0, 0, 0		; Used by output_char

align 16
temp_string:

; =============================================================================
; EOF
