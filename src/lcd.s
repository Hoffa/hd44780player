;-------------------------------------------------------------------------------
; File: lcd.s
; Author: Christoffer Rehn
; Last modified: 30/4/2015
;
; Provides some utility functions for the HD44780 LCD controller.
;
; Label prefix: lcd_
;-------------------------------------------------------------------------------

lcd_b_e		EQU	0x1	; E
lcd_b_rs	EQU	0x2	; RS
lcd_b_rw	EQU	0x4	; R/not(W)
lcd_b_led	EQU	0x10	; LED enable
lcd_b_bl	EQU	0x20	; Backlight enable
lcd_b_busy	EQU	0x80	; Busy

lcd_clrscr	EQU	0x1	; Clear screen command

lcd_row_0	EQU	0x80
lcd_row_1	EQU	0xc0

;-------------------------------------------------------------------------------
; r_putc
; Prints a character on the LCD display.
; Input:
;   R0: character
;   R1: bt_data or bt_ctrl
;-------------------------------------------------------------------------------
r_putc
		PUSH	{R4}

		MOV	R3, #bt_io

		LDRB	R2, [R3, #bt_ctrl]
		ORR	R2, R2, #(lcd_b_rw OR lcd_b_bl)	; R/not(W) = 1 and enable backlight
		BIC	R2, R2, #lcd_b_rs		; RS = 0
		BIC	R2, R2, #lcd_b_led		; Disable LEDs
		STRB	R2, [R3, #bt_ctrl]

lcd_l_putc_busy	ORR	R2, R2, #lcd_b_e		; E = 1
		STRB	R2, [R3, #bt_ctrl]

		LDRB	R4, [R3, #bt_data]		; Read status

		BIC	R2, R2, #lcd_b_e		; E = 0
		STRB	R2, [R3, #bt_ctrl]

		ANDS	R4, R4, #lcd_b_busy
		BNE	lcd_l_putc_busy

		BIC	R2, R2, #lcd_b_rw		; R/not(W) = 0
		CMP	R1, #bt_data
		ORREQ	R2, R2, #lcd_b_rs		; RS = 1 if R1 == lcd_data
		BICNE	R2, R2, #lcd_b_rs		; RS = 0 otherwise
		STRB	R2, [R3, #bt_ctrl]

		STRB	R0, [R3, #bt_data]		; Write character

		ORR	R2, R2, #lcd_b_e		; E = 1
		STRB	R2, [R3, #bt_ctrl]

		BIC	R2, R2, #lcd_b_e		; E = 0
		STRB	R2, [R3, #bt_ctrl]

		POP	{R4}
		MOV	PC, LR

;-------------------------------------------------------------------------------
; r_puts
; Prints a string on the LCD display.
; Input:
;   R0: string
;-------------------------------------------------------------------------------
r_puts
		PUSH	{LR}

		MOV	R2, R0
		MOV	R1, #bt_data

l_puts_c	LDRB	R0, [R2], #1
		CMP	R0, #0
		BEQ	puts_end

		PUSH	{R1, R2}
		BL	r_putc
		POP	{R1, R2}
		B	l_puts_c

puts_end	POP	{LR}
		MOV	PC, LR

;-------------------------------------------------------------------------------
; r_clrscr
; Clears the LCD display.
;-------------------------------------------------------------------------------
r_clrscr
		PUSH	{LR}

		MOV	R0, #lcd_clrscr
		MOV	R1, #bt_ctrl
		BL	r_putc

		POP	{LR}
		MOV	PC, LR

;-------------------------------------------------------------------------------
; r_move_cursor
; Moves the LCD cursor to specified location.
; Input:
;   R0: x (0-15)
;   R1: y (0-1)
;-------------------------------------------------------------------------------
r_move_cursor
		PUSH	{LR}

		CMP	R1, #0
		ADDEQ	R0, R0, #lcd_row_0
		ADDNE	R0, R0, #lcd_row_1
		MOV	R1, #bt_ctrl
		BL	r_putc

		POP	{LR}
		MOV	PC, LR