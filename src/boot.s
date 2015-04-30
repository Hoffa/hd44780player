;-------------------------------------------------------------------------------
; File: boot.s
; Author: Christoffer Rehn
; Last modified: 29/4/2015
;
; Sets up the system at boot. Timer IRQs are enabled (for updating the LCD
; display) and the main program is run in supervisor mode (for simplicity's
; sake).
;
; Label prefix: bt_
;-------------------------------------------------------------------------------

bt_svc_stack_size	EQU	64
bt_irq_stack_size	EQU	16

bt_io			EQU	0x10000000	; I/O base address
bt_data			EQU	0x0		; PIO_A
bt_ctrl			EQU	0x4		; PIO_B
bt_timer_cmp		EQU	0xc		; Timer compare
bt_irq_req		EQU	0x18		; Interrupt requests
bt_irq_enables		EQU	0x1c		; Interrupt enables

bt_svc_mode		EQU	0x13		; Supervisor mode code
bt_irq_mode		EQU	0x12		; IRQ mode code

bt_b_irq_ack		EQU	0x1
bt_b_irq_en_tc		EQU	0x1
bt_b_irq_en		EQU	0x80

		B	bt_ev_reset	; Reset
		B	.		; Undefined instruction
		B	.		; SVC
		B	.		; Prefetch abort
		B	.		; Data abort
		NOP
		B	bt_ev_irq	; IRQ
		B	.		; FIQ

		; Supervisor mode stack
		DEFS	bt_svc_stack_size
bt_svc_stack
		; IRQ mode stack
		DEFS	bt_irq_stack_size
bt_irq_stack

		INCLUDE	lcd.s

; IRQ
bt_ev_irq	; Acknowledge interrupt
		PUSH	{R0-R1}
		MOV	R1, #bt_io
		LDRB	R0, [R1, #bt_irq_req]
		BIC	R0, R0, #bt_b_irq_ack
		STRB	R0, [R1, #bt_irq_req]
		POP	{R0-R1}

		PUSH	{LR}
		BL	__timer_irq
		POP	{LR}

		SUBS	PC, LR, #4

; Reset
bt_ev_reset	MOV	R0, #bt_irq_mode	; Set IRQ mode
		MSR	CPSR_c, R0		; Switch to IRQ mode
		ADR	SP, bt_irq_stack	; Set IRQ mode stack

		ORR	R0, R0, #bt_svc_mode	; Set supervisor mode
		BIC	R0, R0, #bt_b_irq_en	; Enable IRQs
		MSR	CPSR_c, R0		; Switch to supervisor mode
		ADR	SP, bt_svc_stack	; Set supervisor mode stack

		; Enable timer interrupt
		MOV	R1, #bt_io
		LDRB	R2, [R1, #bt_irq_enables]
		ORR	R2, R2, #bt_b_irq_en_tc
		STRB	R2, [R1, #bt_irq_enables]

		B	__main