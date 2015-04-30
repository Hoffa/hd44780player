;-------------------------------------------------------------------------------
; File: main.s
; Author: Christoffer Rehn
; Last modified: 30/4/2015
;
; Main movie player code. Handles unpacking each frame and updating the LCD
; display as necessary. The movie starts again once it reaches the end. The
; screen is updated roughly 16 frames per second.
;
; The HD44780 LCD controller allows only 8 custom characters, with each
; character being 5x8 pixels in size. This means 20x16 pixels can be
; independently controlled. Since between each block there is a gap of about one
; pixel in width, frames of size 23x16 are rendered during preprocessing. The
; gap between rows is roughly half a pixel; it is ignored.
;
; Notes:
;   - "Block" in this context refers to a custom character on the LCD display
;     (8 in total).
;
; Global variables:
;   R9: current frame address
;   R10: current frame number
;   R11: maximum frame number
;-------------------------------------------------------------------------------

		INCLUDE	boot.s

eos		EQU	0x9f	; "End of screen"

; Screen buffer; 8 bytes per block
screen		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
		DEFB	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,eos
		ALIGN

;-------------------------------------------------------------------------------
; r_init
; Initializes the movie player.
;-------------------------------------------------------------------------------
r_init
		PUSH	{LR}

		; Move cursor to top row
		MOV	R0, #0
		MOV	R1, #0
		BL	r_move_cursor

		; Draw top row blocks
		MOV	R0, #0
		MOV	R1, #bt_data

l_draw_top	CMP	R0, #4
		BGE	draw_bottom

		PUSH	{R0-R1}
		BL	r_putc
		POP	{R0-R1}
		ADD	R0, R0, #1
		B	l_draw_top

		; Move cursor to bottom row
draw_bottom	MOV	R0, #0
		MOV	R1, #1
		BL	r_move_cursor

		; Draw bottom row blocks
		MOV	R0, #4
		MOV	R1, #bt_data

l_draw_bottom	CMP	R0, #8
		BGE	init_end

		PUSH	{R0-R1}
		BL	r_putc
		POP	{R0-R1}
		ADD	R0, R0, #1
		B	l_draw_bottom

init_end	POP	{LR}
		MOV	PC, LR

;-------------------------------------------------------------------------------
; r_update
; Stores the screen buffer into CGRAM (updates LCD display).
;-------------------------------------------------------------------------------
r_update
		PUSH	{LR}

		; Point to CGRAM
		MOV	R0, #0x40
		MOV	R1, #bt_ctrl
		BL	r_putc

		; Write data
		MOV	R1, #bt_data
		ADR	R2, screen

l_update_row	LDRB	R0, [R2], #1
		CMP	R0, #eos
		BEQ	update_end

		PUSH	{R1-R2}
		BL	r_putc
		POP	{R1-R2}
		B	l_update_row

update_end	POP	{LR}
		MOV	PC, LR

;-------------------------------------------------------------------------------
; r_frame
; Loads the next frame into the screen buffer.
;
; Each block is packed as follows:
;   Byte: 00000 00011 11111 12222 22223 33333 33444 44444
;    Row: ##0## ##1## ##2## ##3## ##4## ##5## ##6## ##7##
;-------------------------------------------------------------------------------
r_frame
		PUSH	{R4-R8, R10-R11}

		LDRB	R8, [R9], #1	; R8: blocks to update
		MOV	R10, #0		; R10: current block number
		MOV	R11, #0x1	; R11: current block bitmask

l_load_block	CMP	R10, #8
		BGE	frame_end
		TST	R8, R11		; Update current block?
		BEQ	load_block_end

		ADR	R7, screen
		MOV	R0, #8
		MUL	R0, R0, R10
		ADD	R7, R7, R0	; R7: write address (screen + (8 * R10))

		LDRB	R0, [R9], #1
		LDRB	R1, [R9], #1
		LDRB	R2, [R9], #1
		LDRB	R3, [R9], #1
		LDRB	R4, [R9], #1

		; Row 0
		MOV	R5, R0
		LSR	R5, R5, #3
		STRB	R5, [R7], #1

		; Row 1
		MOV	R5, R0
		MOV	R6, R1
		LSL	R5, R5, #2
		LSR	R6, R6, #6
		ORR	R5, R5, R6
		AND	R5, R5, #0x1f
		STRB	R5, [R7], #1

		; Row 2
		MOV	R5, R1
		LSR	R5, R5, #1
		AND	R5, R5, #0x1f
		STRB	R5, [R7], #1

		; Row 3
		MOV	R5, R1
		MOV	R6, R2
		LSL	R5, R5, #4
		LSR	R6, R6, #4
		ORR	R5, R5, R6
		AND	R5, R5, #0x1f
		STRB	R5, [R7], #1

		; Row 4
		MOV	R5, R2
		MOV	R6, R3
		LSL	R5, R5, #1
		LSR	R6, R6, #7
		ORR	R5, R5, R6
		AND	R5, R5, #0x1f
		STRB	R5, [R7], #1

		; Row 5
		MOV	R5, R3
		LSR	R5, R5, #2
		AND	R5, R5, #0x1f
		STRB	R5, [R7], #1

		; Row 6
		MOV	R5, R3
		MOV	R6, R4
		LSL	R5, R5, #3
		LSR	R6, R6, #5
		ORR	R5, R5, R6
		AND	R5, R5, #0x1f
		STRB	R5, [R7], #1

		; Row 7
		MOV	R5, R4
		AND	R5, R5, #0x1f
		STRB	R5, [R7], #1

load_block_end	ADD	R10, R10, #1	; ++R10
		LSL	R11, R11, #1	; R11 <<= 1
		B	l_load_block

frame_end	POP	{R4-R8, R10-R11}
		MOV	PC, LR

;-------------------------------------------------------------------------------
; __timer_irq
; Timer interrupt. Assumed to be an 8-bit timer running at 1 kHz.
;-------------------------------------------------------------------------------
__timer_irq
		ADD	R10, R10, #1
		CMP	R10, R11
		ADRGE	R9, mov_data
		MOVGE	R10, #0

		PUSH	{LR}
		BL	r_frame
		BL	r_update
		POP	{LR}

		; Increment timer compare by 64 for 15.625 FPS
		PUSH	{R0-R1}
		MOV	R1, #bt_io
		LDRB	R0, [R1, #bt_timer_cmp]
		ADD	R0, R0, #64
		STRB	R0, [R1, #bt_timer_cmp]
		POP	{R0-R1}

		MOV	PC, LR

;-------------------------------------------------------------------------------
; __main
; Program entry.
;-------------------------------------------------------------------------------
__main
		BL	r_clrscr
		BL	r_init

		MOV	R0, #5
		MOV	R1, #0
		BL	r_move_cursor
		ADR	R0, s_mov_playing
		BL	r_puts

		MOV	R0, #5
		MOV	R1, #1
		BL	r_move_cursor
		ADR	R0, s_mov_title
		BL	r_puts

		ADR	R9, mov_data
		MOV	R10, #0
		ADR	R11, mov_frame_count
		LDR	R11, [R11]	; Maximum frame number
		B	.

		INCLUDE	movie.s