; =============================================================================
; Wozmon x86-64
;
; A complete instruction by instruction rewrite of Steve Wozniak's system
; monitor from 1976 for the Apple-1
;
; Converted from 6502 to x86-64 by Ian Seyler (ian@seyler.me)
;
; 6502 to x86-64 register mapping:
; A = AL
; X = RBX
; Y = RCX
;
; Variables:
; The single byte variables that are used as a pair to denote memory addresses
; are consolidated into x86-64 registers instead.
; XAML & XAMH = R13
; STL & STH = R14
; L & H = R15
; IN = RDI
;
; Notes:
; Capital letter are expected for input
; =============================================================================


BITS 64				; Specify 64-bit
ORG 0x001E0000			; Wozmon expects to be loaded at this address

%include 'api/libBareMetal.asm'	; Needed for kernel I/O calls

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
	mov rdi, IN		; Base address of input (IN)
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
	mov al, prompt		; "\".
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
	; The next two lines are just for BareMetal
	mov al, newline
	call ECHO
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
	; On Apple 1 '.' is AE. On BareMetal is 2E
	jc BLSKIP		; Skip delimiter.
	je SETMODE		; Set BLOCK XAM mode.
	cmp al, ':'		; ":"?
	; On Apple 1 ':' is BA. On BareMetal is 3A
	je SETSTOR		; Yes, set STOR mode.
	cmp al, 'R'		; "R"?
	je RUN			; Yes, run user program.
	xor r15, r15		; $0 -> L.
				; and H.
	mov [YSAV], cl		; Save Y for comparison.
NEXTHEX:
	mov al, [rdi+rcx]	; Get character for hex test.
	xor al, 0x30		; Map digits $0-9
	cmp al, 0x0A		; Digit?
	jl DIG			; Yes.
	add al, 0x89		; Map letter "A"-"F" to $FA-$FF
	cmp al, 0xFA		; Hex letter?
	jc NOTHEX		; No, character not hex.
DIG:
	shl al, 4		; Hex digit to MSD of A.
	mov bx, 0x04		; Shift count.
HEXSHIFT:
	shl al, 1		; Hex digit left, MSB to carry.
	rcl r15, 1		; Rotate into LSD.
				; Rotate into MSD's.
	dec bl			; Done 4 shifts?
	jne HEXSHIFT		; No, loop.
	inc cl			; Advance text index.
	jne NEXTHEX		; Always taken. Check next character for hex.
NOTHEX:
	cmp cl, byte [YSAV]	; Check if L, H empty (no hex digits).
	je ESCAPE		; Yes, generate ESC sequence.
	mov al, byte [MODE]	; Test MODE byte.
	cmp al, 0x74
	jne NOTSTOR		; B6 = 0 for STOR, 1 for XAM and BLOCK XAM
				; LSD's of hex data.
	mov [r14], r15b		; Store at current 'store index'
	inc r14			; Increment store index.
				; Get next item. (no carry).
				; Add carry to 'store index' high order.
TONEXTITEM:
	jmp NEXTITEM		; Get next command item.
RUN:
	call r13		; Run at current XAM index.
	jmp GETLINE
NOTSTOR:
	cmp byte [MODE], 0
	jne XAMNEXT		; B7 = 0 for XAM, 1 for BLOCK XAM
				; Byte count.
SETADR:
				; Copy hex data to
	mov r14, r15		; 'store index'.
	mov r13, r15		; And to 'XAM index'.
				; Next of 2 bytes.
				; Loop unless X = 0.
NXTPRNT:
	jnz PRDATA		; NE means no address to print.
	mov al, newline		; CR.
	call ECHO		; Output it.
				; 'Examine index' high-order byte.
				; Output it in hex format.
				; Low-order 'examine index' byte.
				; Output it in hex format.
	; The next 6 lines differ due to running with 64-bit addresses
	mov rax, r13
	mov bl, 8
NEXTADDR:
	rol rax, 8
	call PRBYTE
	dec bl
	jnz NEXTADDR
	mov al, ':'		; ":".
	call ECHO		; Output it.
PRDATA:
	mov al, ' '		; Blank.
	call ECHO		; Output it.
	mov al, byte [r13]	; Get data byte at 'examine index'.
	call PRBYTE		; Output it in hex format.
XAMNEXT:
	mov byte [MODE], 0x00	; 0 -> MODE (XAM mode).
	cmp r13, r15		; Compare 'examine index' to hex data.
	jge TONEXTITEM		; Not less, so no more data to output.
	inc r13			; Increment 'examine index'.
MOD8CHK:
	mov al, r13b		; Check low-order 'examine index' byte
	and al, 0x07		; For MOD 8 = 0
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

; Variables
YSAV		db 0x00
MODE		db 0x00
tchar		db 0x00

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
; output_char -- Output a single character
; IN:	RSI = String Address
; OUT:	Nothing, all registers preserved
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


align 16
IN:

; =============================================================================
; EOF
