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

buffer		= $0206 	; 81 bytes
offset		= $0257 	; 1 byte. offset of character
rate 		= $0258		; 1 bytes. used for mod operation
frame		= $0259		; 1 byte. used as frame counter
numcycles	= $025a	; 1 byte. used to count number of cycles through frames
e_offset	= $025b	; 1 byte. offset of enemy

b_flag		= $025c ; 1 byte. boolean flag

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
game_init:
	lda #0
	sta frame
	sta numcycles
	lda #8
	sta e_offset
	lda #128
	sta rate ; frame rate
	lda #0
	sta offset
	ldx offset
	lda #"."
	sta buffer,x
	lda #"&"
	sta buffer + 8

main_loop:
	lda #128
	sta rate
	lda frame
	jsr mod
	bne skip_frame
	jsr print_buffer
skip_frame:
	inc frame
	bne main_loop
	inc numcycles
	jsr move_enemy
no_move:
	jmp main_loop

	game_over_text: .asciiz "game over"

game_over:
	ldx #0
game_over_text_loop:
	lda game_over_text,x
	beq game_over_print
	sta buffer,x
	inx
	jmp game_over_text_loop
game_over_print:
	jsr print_buffer
game_over_empty_loop:
	jmp game_over_empty_loop


move_enemy:
	lda e_offset
	cmp offset
	beq game_over
	lda numcycles
	cmp #7
	bne move_enemy_cleanup
	ldx e_offset
	lda #" "
	sta buffer,x
	dex
	lda #"&"
	sta buffer,x
	lda #0
	sta numcycles
	txa
	sta e_offset
	cmp #$ff
	beq under
	cmp #39
	beq first_line
move_enemy_return:
move_enemy_cleanup:
	rts
under:
	lda #55
	sta e_offset
	jmp move_enemy_return
first_line:
	lda #15
	sta e_offset
	jmp move_enemy_return


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


mod: 			; 1-byte modulo operation
	sta value
	ldx #8
	lda #0
	sta mod10
subloop:
	rol value
	rol mod10
	lda mod10
	sec
	sbc rate
	bcc ignore
	sta mod10
ignore:
	dex
	bne subloop
	lda mod10
	rts


print_buffer:
	lda #%00000010
	jsr lcd_instruction
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


nmi:
irq:
	pha
	txa
	pha
	tya
	pha
handler:
	ldx offset
	lda #" "
	sta buffer,x
	lda PORTA
	tay 			; temporarily put result in A reg
	and #%00000001 	; left button
	bne check_again ; handle left button
	dec offset
	lda offset
	cmp #$ff		; jump to end of second line if underflow
	bne check_for_39
	lda #55
	sta offset
	jmp irq_return
check_for_39:
	cmp #39
	bne irq_return
	lda #15
	sta offset
	jmp irq_return
check_again:
	tya				; get original result back
	and #%00000010	; right button
	bne irq_return ; handle right button
	inc offset
	lda offset
	cmp #16
	bne check_for_56
	lda #40
	sta offset
	jmp irq_return
check_for_56
	cmp #56
	bne irq_return
	lda #0
	sta offset
irq_return:
	ldx offset
	lda #"."
	sta buffer,x
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
	.word irq
