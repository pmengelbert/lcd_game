
PORTB = $6000
PORTA = $6001
DDIRB = $6002
DDIRA = $6003

PCR   = $600c
IFR   = $600d
IER   = $600e

CLEAR_DISPLAY    = %00000001
TURN_DISPLAY_ON  = %00001100
SET_DISPLAY_MODE = %00111000
SET_SHIFT_MODE 	 = %00000110

ENABLE_IRQ_CA1 = %10000010

E  = %10000000
RW = %01000000
RS = %00100000

value = $0200 ; 2 bytes
mod10 = $0202 ; 2 bytes

buffer = $0204 ; 80 bytes
; next = $0254

	.org $8000

reset:
	ldx #$ff
	txs
	cli

	lda #ENABLE_IRQ_CA1
	sta IER

	lda #%00000000 ; read CA1 on negative-going edge
	sta PCR

	lda #%11111111 ; Set all pins on port B to output
	sta DDIRB

	lda #%11100000 ; Set top three pins on port A to output
	sta DDIRA

	jsr load_buffer

lcd_init:
	lda #TURN_DISPLAY_ON
	jsr lcd_instruction
	lda #CLEAR_DISPLAY
	jsr lcd_instruction
	lda #SET_DISPLAY_MODE
	jsr lcd_instruction
	lda #SET_SHIFT_MODE
	jsr lcd_instruction

main_loop:
	lda #%00000010
	jsr lcd_instruction

	; jsr print_buffer
	jmp main_loop

load_buffer:
	ldx #0
load_buffer_loop:
	lda blank_buffer,x
	sta buffer,x
	beq return_from_load_buffer
	inx
	jmp load_buffer_loop
return_from_load_buffer
	rts

print_buffer:
	ldx #0
print_loop:
	lda buffer,x
	beq end_print
	jsr lcd_print
	inx
	jmp print_loop
end_print:
	rts

lcd_instruction:
	pha
	jsr lcd_wait
	sta PORTB

	lda #0 ; Set register select and read/write for display
	sta PORTA 

	lda #E
	sta PORTA

	lda #RS ; Set register select and read/write for display
	sta PORTA

	pla
	rts

lcd_print:
	pha
	jsr lcd_wait
	sta PORTB

	lda #RS ; Set register select and read/write for display
	sta PORTA 

	lda #(RS|E)
	sta PORTA

	lda #RS ; Set register select and read/write for display
	sta PORTA

	pla
	rts

lcd_wait:
	pha
	
	lda #0
	sta DDIRB
wait:
	lda #RW
	sta PORTA

	lda #(RW|E)
	sta PORTA

	lda PORTB
	and #%10000000
	bne wait

	lda #RW ; cleanup
	sta PORTA
	lda #%11111111
	sta DDIRB
	pla
	rts

push_char:
	pha ; Push new first char onto stack
	ldy #0

char_loop:
	lda buffer,y ; Get char on string and put into X register
	tax
	pla
	sta buffer,y ; Pull char off stack and add to string
	iny
	txa
	pha ; Push char from string onto the stack
	bne char_loop

	pla
	sta buffer,y ; Pull off null terminator and put at end of string

	rts

nmi:
irqb:
	pha
	txa
	pha
	tya
	pha

	ldx #0
shoot_loop:
	lda buffer,x
	beq go_home
	lda #"0"
	sta buffer,x
	jsr print_buffer
	lda #" "
	sta buffer,x
	inx
	txa
	pha
	ldy #$ff
	ldx #$ff
short_wait:
	dex
	bne short_wait
	dey
	bne short_wait
	pla
	tax
	jmp shoot_loop

go_home:
	bit PORTA

	pla
	tay
	pla
	tax
	pla
	rti

	number: .word 1729

	blank_buffer: .asciiz "                                                                               " 

	.org $fffa
	.word nmi
	.word reset
	.word irqb
