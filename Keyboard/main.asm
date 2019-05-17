;
; Keyboard.asm
;
; Created: 2019-03-19 08:52:37
; Author : Mateusz
;
.INCLUDE "m328pdef.inc"
.ORG 0x0000 
RJMP init
.ORG 0x0012
RJMP Timer2OverflowInterrupt
.ORG 0x0020
RJMP Timer0OverflowInterrupt

init:
	;set timer0 prescalerto 8
	;LDI	R17,2
	LDI	R17,4
	OUT TCCR0B,R17	;The prescaler is set to 8
	
	;set timer2 prescalerto 8
	LDI R17,7
	STS TCCR2B,R17
	


	;set correct ‘reload values’
	;LDI R16,0xB9	;Setting the TCNT value
	LDI R16,56	;Setting the TCNT value
	OUT TCNT0,R16

	LDI R16,255
	STS TCNT2,R16

	;enable global interrupt & timer0 interrupt
	LDI	R18,0x80
	OUT	SREG,R18
	LDI R19,1
	STS	TIMSK0,R19

	STS TIMSK2,R19

	;Clearing the outputs
	SBI DDRB,3			
	SBI DDRB,4
	SBI DDRB,5
	CBI PORTB,4
	CBI PORTB,5

;Send data to screenbuffer------------------------------------------------------------------------------
LDI ZL,0x00						; ZL is the register R30------Z = ZL+ZH
LDI ZH,0x01						;init Z to point do address 0x0100----------ZH is the register R31
LDI R17 ,0x00					;we will write this value to every byte of the whole screenbuffer

LDI R21,70						;need to write 70 bytes to fill the whole screenbuffer
WriteByteToScreenbuffer:
ST Z+,R17						;write value from Ra to address pointed by Z and auto-increse Z pointer
DEC R21
BRNE WriteByteToScreenbuffer	;write 70 bytes
;-------------------------------------------------------------------------------------------------------

;Send data to screenbuffer------------------------------------------------------------------------------
LDI YL,0x00						; ZL is the register R30------Z = ZL+ZH
LDI YH,0x02						;init Z to point do address 0x0100----------ZH is the register R31
LDI R17 ,0x00					;we will write this value to every byte of the whole screenbuffer

LDI R21,70						;need to write 70 bytes to fill the whole screenbuffer
WriteObstacleToScreenbuffer:
ST Y+,R17						;write value from Ra to address pointed by Z and auto-increse Z pointer
DEC R21
BRNE WriteObstacleToScreenbuffer	;write 70 bytes
;-------------------------------------------------------------------------------------------------------
;Send data to movebuffer------------------------------------------------------------------------------
LDI XL,0x00						; ZL is the register R30------Z = ZL+ZH
LDI XH,0x03						;init Z to point do address 0x0100----------ZH is the register R31
LDI R17 ,0x00					;we will write this value to every byte of the whole screenbuffer

LDI R21,70						;need to write 70 bytes to fill the whole screenbuffer
WriteMoveToMovebuffer:
ST X+,R17						;write value from Ra to address pointed by Z and auto-increse Z pointer
DEC R21
BRNE WriteMoveToMovebuffer	;write 70 bytes
;-------------------------------------------------------------------------------------------------------

;Add a line on the screen
;LDI ZL,0x12						; ZL is the register R30------Z = ZL+ZH  We use ZL to address directly the right pointer
LDI ZL,9						; ZL is the register R30------Z = ZL+ZH  We use ZL to address directly the right pointer
LDI ZH,0x01						;init Z to point do address 0x0100----------ZH is the register R31
LDI R17, 0x70
;STD Z+3,R17
ST Z,R17

;Add a obstacle on the screen

LDI YL,69						; ZL is the register R30------Z = ZL+ZH  We use ZL to address directly the right pointer
LDI YH,0x02						;init Z to point do address 0x0100----------ZH is the register R31
LDI R17, 0x10
;STD Z+3,R17
ST Y,R17

LDI R25,6						;Initial direction (right) of the snake
LDI R23,3						;Initial length of the snake.
LDI R21,10						; R21 is used as the counter for the move interrupt

InitKeyboard:
    ; Configure input pin PB0 
	LDI R16,0xFF
	OUT DDRD,R16
	NOP
	OUT PORTD,R16
	NOP

	LDI R16,0xF0
	OUT DDRD,R16
	NOP
	LDI R16,0x0F
	OUT PORTD,R16
	NOP
	
Main:
	SBI PORTC,2
	SBI PORTC,3

	SBIS PIND,1						; Skip next instruction if the least significant bit of pin D is set.
	RJMP right
	SBIS PIND,2
	RJMP upOrDown
	SBIS PIND,3
	RJMP left

	RJMP Main



	/*LDI R23,8
	DEC R23
	ROR R17*/










right:
	; Configure input pin PB0 
	LDI R16,0xFF
	OUT DDRD,R16
	NOP
	OUT PORTD,R16
	NOP

	LDI R16,0x0F
	OUT DDRD,R16
	NOP
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,6
	LDI R25,6
	
	;RJMP endReading
	RJMP InitKeyboard
upOrDown:
	; Configure input pin PB0 
	LDI R16,0xFF
	OUT DDRD,R16
	NOP
	OUT PORTD,R16
	NOP

	LDI R16,0x0F
	OUT DDRD,R16
	NOP
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,5
	LDI R25,2
	SBIS PIND,7
	LDI R25,8

	;RJMP endReading
	RJMP InitKeyboard
left:
	; Configure input pin PB0 
	LDI R16,0xFF
	OUT DDRD,R16
	NOP
	OUT PORTD,R16
	NOP

	LDI R16,0x0F
	OUT DDRD,R16
	NOP
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,6
	LDI R25,4
	;RJMP endReading
	RJMP InitKeyboard


moveRight:
	; Horisontal movement----------------------------------
	;checkPast:
	ROR R17							; Horisontal diplacement
	BRCC isZero
	/* 
	The carry bit is set so we've got to change the rectangle to the one on the right 
	*/
	ST Z,R17						; Write R17 to the current Z
	ROR R17							; Rotating R17 here puts back the carry into the bit sequence
	LDI R18,65						; We've got to check if we reached the screen boundary
	CheckWall5:
	CP ZL,R18
	BRNE notLineX5
	ADIW Z,4
	ST Z,R17
	CLC
	RJMP notDown
	notLineX5:
	SUBI R18,10
	BRGE CheckWall5

	LDI R18,60
	CheckWall0:
	CP ZL,R18
	BRNE notLineX0
	ADIW Z,4
	ST Z,R17
	CLC
	RJMP notDown
	notLineX0:
	SUBI R18,10
	BRGE CheckWall0
	ST -Z,R17
	CLC
	RJMP notDown
	isZero:
	ST Z,R17							; Horisontal diplacement
	
	
	
	/*;SBIW Z,1
	MOV R18,ZL
	ADIW Z,1
	LD R17,Z
	ROR R17
	BRCC noPast
	MOV ZL,R18
	LD R17,Z
	ORI R17,0x80
	ST Z,R17
	noPast:
	LDI ZH,0x01
	MOV ZL,R18
	LD R17,Z*/






	;RJMP checkPast



	RJMP notDown
	;------------------------------------------------------

moveLeft:
	; Horisontal movement----------------------------------
	ROL R17							; Horisontal diplacement
	BRCC noCarry
	ST Z,R17
	ROL R17
	
	LDI R18,69
	CheckWall9:
	CP ZL,R18
	BRNE notLineX9
	SBIW Z,4
	ST Z,R17
	CLC
	RJMP notDown
	notLineX9:
	SUBI R18,10
	BRGE CheckWall9

	LDI R18,64
	CheckWall4:
	CP ZL,R18
	BRNE notLineX4
	SBIW Z,4
	ST Z,R17
	CLC
	RJMP notDown
	notLineX4:
	SUBI R18,10
	BRGE CheckWall4
	ADIW Z,1
	ST Z,R17
	CLC
	RJMP notDown
	noCarry:
	ST Z,R17							; Horisontal diplacement
	RJMP notDown
	;------------------------------------------------------

Timer2OverflowInterrupt:
	PUSH R22
	PUSH R23
	PUSH YL
	DEC R21								; Decrement the counter
	BRNE notDown						; Since the interrupt happens to often we add a counter which makes it proceed to the code every 10 times.
	LDI R21,10
	LDI ZH,0x01

	CPI R25,6
	BRNE notRight
	RJMP moveRight
	
	notRight:

	CPI R25,4
	BRNE notLeft
	RJMP moveLeft

	notLeft:

	CPI R25,8
	BRNE notUp
	;Vertical movement-------------------------------
	LDI R18,0
	ST Z,R18							; Set Z to 0

	MOV R19,ZL
	CPI ZL,60							; Compare ZL to 70 if higher then change the rect
	BRLO ChangeRectUp
	LDI R18,65
	SUB ZL,R18							;Subtract 65 from ZL but don't worry we add 10 at the end!
	CPI R19,65							;Compare the original ZL with 75 to see if we are at the top of the screen
	BRLO ChangeRectUp
	;LDI R18,10
	SBIW ZL,10
	ChangeRectUp:
	ADIW ZL,10							; Subtract 10 from Z
	LDI ZH,0x01
	ST Z,R17
	RJMP notDown
	;------------------------------------------------
	notUp:

	CPI R25,2
	BRNE notDown
	;Vertical movement-------------------------------
	LDI R18,0
	ST Z,R18							; Set Z to 0

	MOV R19,ZL							; Value of ZL to R19
	CPI ZL,10							; Compare ZL to 20 if smaller then change the rect
	BRSH ChangeRect
	LDI R18,65						
	ADD ZL,R18							;Adding 65 to ZL since it is lower than 20
	CPI R19,5							;Compare the original ZL with 15 to see if we are at the bottom of the screen
	BRSH ChangeRect
	;LDI R18,10
	ADIW ZL,10							;We're at the bottom so ZL = ZL + 65 + 10
	ChangeRect:
	SBIW ZL,10							; Subtract 10 from Z
	LDI ZH,0x01
	ST Z,R17

	;------------------------------------------------
	notDown:
	/*
	This small section is responisible for eating an obstacle/object.
	*/
	MOV YL,ZL
	LD R22,Y
	SUB R22,R17
	BRNE noOnObstacle
	ST Y,R22
	noOnObstacle:
	POP YL
	POP R23
	POP R22
	RETI

Timer0OverflowInterrupt:

/*
The goal of the interrupt is to refresh the screen,
*/

;Initialising Z
PUSH R16
PUSH R17						;save R17 on the stack
PUSH R18
PUSH R19
PUSH ZL
PUSH YL

/* 
We use 2 poiners registers for the screen Z contains the snake while Y the object the snake can eat.
*/

LDI ZL,0x00
LDI ZH,0x01						;init Z to point do address 0x0100
LD R17,Z+						;write value from address pointed by Z to Ra and auto-increse Z pointer

LDI YL,0x00
LDI YH,0x02						;init Z to point do address 0x0100
LD R18,Y+						;write value from address pointed by Z to Ra and auto-increse Z pointer


;Rows counter
LDI R22,0x02
;lDI R22,0
;LDI R19,7

Send1Row:
    ;CPI R22,0x80
	;BRNE pa
	;LDI R22,0x01
	;pa:

	;Byte counter
	LDI R20,8
	;Columns counter
	LDI R16,80	
	CLC
	COLUMNS:
	CBI PORTB,3							;Set PB3 low
	ROR R17								;Rotate R17 right througth carry
	BRCC NOPB3							;Branch if carry is 0
	SBI PORTB,3							;carry is 1 => set PB3 high
NOPB3:
	ROR R18								;Rotate R18 right througth carry
	BRCC noObstacle							;Branch if carry is 0
	SBI PORTB,3							;carry is 1 => set PB3 high

noObstacle:
	CBI PORTB,5							;Set PB5 low
	SBI PORTB,5							;Set PB5 high
	DEC R20
	BRNE CONTINUE						;Branch if not all the bits have been analysed
								
	LDI R20,8
	LD R17,Z+							;write value from address pointed by Z to Ra and auto-increse Z pointer
	LD R18,Y+
CONTINUE:
	DEC R16
	BRNE COLUMNS

LDI R16,8	;Rows counter
CLC
ROWS:
	CBI PORTB,3							;Set PB3 low
	ROR R22								;Rotate R22 right througth carry
	BRCC NOONE							;Branch if carry is 0
	SBI PORTB,3							;carry is 1 => set PB3 high
NOONE:
    CBI PORTB,5							;Set PB5 low
	SBI PORTB,5							;Set PB5 high
	DEC R16
	BRNE ROWS
	
notRow8:
CBI PORTB,4								;Set PB4 low
SBI PORTB,4								;Set PB4 high
;Delay
;PB4 delay parameters
LDI R16,2
LDI R20,255

LDI R23,9								;Setting up the delay between SBI PB4 and CBI PB4
LDI R24,255
time1:
	time2:
		DEC R23
		BRNE time2
		LDI R23,9
	DEC R24
	BRNE time1
	LDI R24,255

CBI PORTB,4								;Set PB4 low

TST R22									;Check if R22 = 0x00
BRNE Send1Row							;If R22 != 0x00 plot next row if not, stop the time interrupt
;ROL R22
POP YL
POP ZL
POP R19
POP R18
POP R17									;restore R17 from the stack
POP R16
CLC
RETI
;RJMP Send1Row


	







/*;Read data from screenbuffer for one row----------------------------------------------------------------
LDI ZL,0x00
LDI ZH,0x01						;init Z to point do address 0x0100

LDI R21,70						;need to write 70 bytes to fill the whole screenbuffer
ReadByteFromScreenbuffer:
LD R17,Z+						;write value from address pointed by Z to Ra and auto-increse Z pointer
DEC R21
BRNE ReadByteFromScreenbuffer	;write 70 bytes
;-------------------------------------------------------------------------------------------------------
*/






/*;Send data to screenbuffer
LDI ZL,0x00						; ZL is the register R30
LDI ZH,0x01						;init Z to point do address 0x0100----------ZH is the register R31
LDI Ra ,0x55					;we will write this value to every byte of the whole screenbuffer

LDI Rb,70						;need to write 70 bytes to fill the whole screenbuffer
WriteByteToScreenbuffer:
ST Z+,Ra						;write value from Ra to address pointed by Z and auto-increse Z pointer
DEC Rb
BRNE WriteVyteToScreenbuffer	;write 70 bytes

;Read data from screenbuffer for one row
LDI ZL,0x00
LDI ZH,0x01						;init Z to point do address 0x0100

LDI Rb,70						;need to write 70 bytes to fill the whole screenbuffer
WriteByteToScreenbuffer:
LD Ra,Z+						;write value from address pointed by Z to Ra and auto-increse Z pointer
DEC Rb
BRNE WriteVyteToScreenbuffer	;write 70 bytes
*/


;-------------------------------------------------------------


/*INIT:
	LDI R16,0b00000000	; Load Immediate
	LDI R18,10
	CBI DDRB,5			; Clear Bit in I/O Register
	CBI DDRB,4
;LOOP: 80 COL
ROW:
	CPI R18,0			; Compare Register with Immediate
	BREQ SEND
	DEC R18				; Decrement
	MOV R17,R16
	ROL R17		;Rotate Left Through Carry
	CBI DDRB,3	;PB3
	BRCC LABEL	;Branch if Carry Cleared
	SBI DDRB,3	;PB3
	
LABEL:
	SBI DDRB,5	;PB5
	CBI DDRB,5	
	JMP ROW

LDI R19,8
LOOP:
	
	
SEND:
	SBI DDRB,4	;PB4
	CBI DDRB,4
	JMP INIT

	;LSL R16		;Logical shift left*/