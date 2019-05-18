;
; Keyboard.asm
;
; Created: 2019-03-19 08:52:37
; Author : Mateusz
;
.INCLUDE "m328pdef.inc"
.ORG 0x0000 
RJMP PRESSstart

;.ORG 0x0012
;RJMP Timer2OverflowInterrupt

.ORG 0x001A
RJMP Timer1OverflowInterrupt
.ORG 0x0020
RJMP Timer0OverflowInterrupt

; -------------------------------------------------------- PRESS START ------------------------------------------------------------------
PRESSstart :
	LDI YL,0x00
	LDI YH,0x01
	LDI R16,0b00
	LDI R16,6         ;P
	ST Y+,R16		  
	LDI R16,7		  ;R
	ST Y+,R16
	LDI R16,2		  ;E
	ST Y+,R16
	LDI R16,8		  ;S
	ST Y+,R16
	ST Y+,R16         ;S
	LDI R16,0
	LDI R17,6
	loop :
		ST Y+,R16
		DEC R17
	BRNE loop
	LDI R16,8         ;S
	ST Y+,R16
	LDI R16,9         ;T
	ST Y+,R16
	LDI R16,1         ;A
	ST Y+,R16
	LDI R16,7         ;R
	ST Y+,R16
	LDI R16,9         ;T
	ST Y,R16

init :
	.DEF random = R23
	LDI R22,200
	LDI random,255
	SET

	CBI DDRB,0			    ; Pin PB0 is an input
	SBI PORTB,0     

	SBI DDRB,1
	        
	SBI DDRB,3			    ; Pin PB3 is an output
	CBI PORTB,3	

	SBI DDRB,4				; Pin PB4 is an output
	CBI PORTB,4

	SBI DDRB,5				; Pin PB5 is an output
	CBI PORTB,5
	RJMP start

; ------------------- shift of the row in the screen ------------------------
rowon :
	ROL R21           ; Rotate to the left
	BRCC rowoff
	SBI PORTB,3
rowoff :
	SBI PORTB,5
	CBI PORTB,5
	CBI PORTB,3
	DEC R17           ; Do this 8 times
	BRNE rowon

SBI PORTB,4           ; PB4 need to stay at one a certain amount of time
LDI R19,255
LDI R20, 9
wait1:
	wait2:
		DEC R20
		BRNE wait2
	LDI R20,9
	DEC R19
	BRNE wait1
CBI PORTB,4

DEC R16                ; Change the position of the byte in flash memory
LSR R18                ; shift to the rigth the shift register
BREQ start             ; if shift equal to 0 => go to start
RJMP display           ; go to display either
; --------------------------------------------------------------------------

start :
	LDI R16,6               ; Count from 6 to 0 to have all the flash line
	LDI R18, 0b01000000     ; Send the row
	DEC R22
	BRNE display
	BRTS clearT
	LDI R22,200
	SET
	RJMP display
	clearT :
		LDI R22,25
		CLT

display :
	LDI YL,0x10
	LDI YH,0x01             ; 16 blocks to display
	LDI R17,8               ; constant
	LDI R19,16              ; counter of each blocks

	LDI R21,0xFF            ; Transition on PIN D
	OUT DDRD,R21
	OUT PORTD,R21

	; Configure the PIN D of the keyboard
	LDI R21,0xF0   
	OUT DDRD,R21            ; PIN 7:4 are outputs and 3:0 are inputs
	LDI R21,0x0F
	OUT PORTD,R21			; PIN 3:0 have pull-up resistor on
	RJMP COUNTloop

NEWcounter :
	LDI random,255

COUNTloop :
	LDI R21,0xFF            ; Transition on PIN D
	OUT DDRD,R21
	OUT PORTD,R21

	LDI R21,0xF0   
	OUT DDRD,R21            ; PIN 7:4 are outputs and 3:0 are inputs
	LDI R21,0x0F
	OUT PORTD,R21			; PIN 3:0 have pull-up resistor on

	DEC random              ; Decrement random
	CPI random,1		    ; IF random equal 1
	BREQ NEWcounter
	SBIS PIND,0				; Button is pushed in the column 0 go to the next instruction
	RJMP READloop
	RJMP blocksloop

READloop :
	LDI R21,0xFF            ; Transition on PIN D
	OUT DDRD,R21
	OUT PORTD,R21

	LDI R21,0x0F			; PIN 7:4 are inputs and 3:0 are outputs
	OUT DDRD,R21
	LDI R21,0xF0			; PIN 7:4 have pull-up resistor on
	OUT PORTD,R21
	NOP

	SBIS PIND,4				; Button is pushed in the column 0 and row 4 go to the next instruction
	RJMP begin

blocksloop :
	LDI ZL,low(CharTable << 1)        ; First element in flash memory
	LDI ZH,high(CharTable << 1)
	BRTS show

notshow :
	LDI R21,0
	RJMP block
	LDI R20,5                ; We must shift 5 times

show :
	LD R21,-Y                       ; Load the line that we need on the flash
	MUL R21,R17                     ; multiply by eight to have the first element of the line 
	MOV R21,R0
	ADD R21,R16					    ; Add row to have the byte of the line
	ADC ZL,R21                      ; Add this value on Z
	BRCC nc
	LDI R21,1
	ADD ZH,R21
	nc :
	LPM R21,Z		                ; Load the byte at the position stored in Z in R21
	LDI R20,5                       ; We must shift 5 times

block :
	ROR R21           ; shift to the right R21 
	BRCC turnoff   
	SBI PORTB,3		  ; If it's a one turn on the LED

turnoff :
	SBI PORTB,5       ; Rising edge to put in the shift register
	CBI PORTB,5
	CBI PORTB,3       ; Don't forget to clear PB3
	DEC R20           ; Decrement counter2 5 times
	BRNE block

DEC R19               ; Decrement counter1 16 times (corresponding to the number of block)
BRNE blocksloop
MOV R21,R18           ; Put the row shifting on another register
RJMP rowon

; ---------------------------------------------------------------------------------------------------------------------------------------
; -------------------------------------------------------- SNAKE ------------------------------------------------------------------------

begin:
	.DEF direction	= R25
	.DEF bytesnake	= R17
	.DEF bytefood	= R18
	.DEF speed		= R22
	.DEF toggle		= R24			; Used to make the fruit darker
	.DEF score		= R1

	LDI speed,0x0F
	IN score, 0
	LDI toggle, 1
	;-------------------TIMERS----------------------------------

	;Set timer0 prescaler to 256
	LDI	R16,4
	OUT TCCR0B,R16	

	
	;Set timer2 with the maximum prescaler
	;LDI R16,7
	;STS TCCR2B,R16


	LDI R16,0
	STS PRR,R16
	;Set timer1 prescaler to 1024
	LDI	R16,3
	STS TCCR1B,R16	

	;Setting the TCNT0 value at 312Hz
	LDI R16,56	
	OUT TCNT0,R16

	;Setting the TCNT1 value at 1Hz -> TCNT1  = 49911
	LDI R16,0xFF	
	LDI R19,0xF0
	STS TCNT1H,R19
	STS TCNT1L,R16

	;Setting the TCNT2 with the maximum value to have the lowest frequency
	;LDI R16,255
	;STS TCNT2,R16


	;enable global interrupt & timer0 and timer2 interrupt
	LDI	R16,0x80
	OUT	SREG,R16
	LDI R16,1
	STS	TIMSK0,R16
	STS TIMSK1,R16

	;STS TIMSK2,R16


	;Clearing the outputs
	SBI DDRB,3			    ; Pin PB3 is an output
	CBI PORTB,3	

	SBI DDRB,4				; Pin PB4 is an output
	CBI PORTB,4

	SBI DDRB,5				; Pin PB5 is an output
	CBI PORTB,5

;Send maze to screenbuffer------------------------------------------------------------------------------
LDI XL,0x00						
LDI XH,0x03						
LDI R16 ,0x00					
LDI R19,7						
WriteMazeToScreenbuffer:
	ST X+,R16					
	DEC R19
	BRNE WriteMazeToScreenbuffer	


LDI R16 ,0x10					
ST X+,R16


LDI R16 ,0x00					
LDI R19,8					
WriteMazeToScreenbuffer2:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer2	

LDI R16 ,0xFE					
ST X+,R16	

LDI R16 ,0x1F					
ST X+,R16	

LDI R16 ,0x00					
LDI R19,8					
WriteMazeToScreenbuffer3:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer3

LDI R16 ,0x02					
ST X+,R16

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,4					
WriteMazeToScreenbuffer4:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer4

LDI R16 ,0xF0					
ST X+,R16

LDI R16 ,0xFF					
LDI R19,3					
WriteMazeToScreenbuffer5:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer5

LDI R16 ,0x03					
ST X+,R16

LDI R16 ,0xF0					
ST X+,R16

LDI R16 ,0xFF					
LDI R19,2					
WriteMazeToScreenbuffer6:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer6

LDI R16 ,0xFF					
ST X+,R16

LDI R16 ,0x7F					
ST X+,R16

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,9					
WriteMazeToScreenbuffer7:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer7

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,9					
WriteMazeToScreenbuffer8:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer8

LDI R16 ,0x10					
ST X+,R16

LDI R16 ,0x00					
LDI R19,7					
WriteMazeToScreenbuffer9:		
	ST X+,R16		
	DEC R19
	BRNE WriteMazeToScreenbuffer9


;Send data to screenbuffer------------------------------------------------------------------------------
LDI ZL,0x00						; ZL is the register R30------Z = ZL+ZH
LDI ZH,0x01						; init Z to point do address 0x0100----------ZH is the register R31
LDI R16 ,0x00					; We will write this value to every byte of the whole screenbuffer

LDI R19,70						; Need to write 70 bytes to fill the whole screenbuffer
WriteByteToScreenbuffer:
	ST Z+,R16					;write value from Ra to address pointed by Z and auto-increase Z pointer
	DEC R19
	BRNE WriteByteToScreenbuffer	;write 70 bytes
;-------------------------------------------------------------------------------------------------------

;Send obstacle to screenbuffer------------------------------------------------------------------------------
LDI YL,0x00						; YL is the register R32------Y = YL+YH
LDI YH,0x02						; init Y to point do address 0x0200----------YH is the register R33

LDI R19,70						;need to write 70 bytes to fill the whole screenbuffer
WriteObstacleToScreenbuffer:
	ST Y+,R16						;write value from Ra to address pointed by Y and auto-increase Y pointer
	DEC R19
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

; Add the move point on the screen at a deterministic place
LDI ZL,0					    ; Take the position of the byte
LDI bytesnake, 0x01                   ; Set one bit on the byte
ST Z,bytesnake                        ; Put the value pointed by Z

;Add food for snake on the screen
generate :
	ANDI random,0b011111111         ; We want a random number < 70 => we need 7 bits => random,7 = 0
	CPI random,70                   ; Compare random register to 70
	BRSH LSFR270                    ; If it's equal or bigger than 70 use LSFR
	RJMP food                       
LSFR270 :
	MOV R16, random                 ; Clone random to R16                    ex : R16 = 0b01111110
	MOV R19, random                 ; Clone random to R19                         R17 = 0b01111110
	LSR random                      ; Shift to the right random                   random = 0b00111111
	BST R16,0					    ; Take the first bit of R16                   T = 0
	BLD random,6                    ; Put this at seventh place of random         random = 0b00111111
	BLD R19,6                       ; Same for R19                                R17 = 0b00111110
	EOR R19,R16                     ; R19 = R16 xor R19                           R17 = 0b01000000
	BST R19,6                       ; Take the seventh bit of R19                 T = 1
	BLD random,5                    ; Put this at the sixth place of random       random = 0b00111111
	RJMP generate                   ; Test if the new random is smaller than 70

food :
	LDI bytefood, 0x80                   ; Set one bit on the byte
	LDI XL,0x00
	ADD XL,random
	LD R25,X
	AND R25,bytefood
	CPI R25,0
	BRNE LSFR270
	LDI YL,0x00                     ; Begin Y = 0x0200
	ADD YL,random				    ; Add it the random number smaller than 70
	ST Y,bytefood			      	    ; Put the value pointed by Y

LDI direction,6						;Initial direction (right) of the snake


InitKeyboard:
    ; Configure input pin PD0 
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16               ; Transition of PIND

	LDI R16,0xF0		        ; PIND 7:4 are outputs and 3:0 are inputs
	OUT DDRD,R16
	LDI R16,0x0F				; PIND 3:0 have pull-up resistor
	OUT PORTD,R16
	
Main:
	SBIS PIND,0
	RJMP restart
	SBIS PIND,1	    
	RJMP right
	SBIS PIND,2
	RJMP upOrDown
	SBIS PIND,3
	RJMP left
	RJMP Main

reset :
	LDI R16,0b10101001
	STS WDTCSR,R16

restart :
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16				; Transition of PIND

	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,5
	RJMP reset
	RJMP InitKeyboard

right:
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16				; Transition of PIND

	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,6
	LDI direction,6
	
	RJMP InitKeyboard

upOrDown:
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16

	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,5
	LDI direction,2
	SBIS PIND,7
	LDI direction,8

	RJMP InitKeyboard

left :
	LDI R16,0xFF
	OUT DDRD,R16
	OUT PORTD,R16

	LDI R16,0x0F
	OUT DDRD,R16
	LDI R16,0xF0
	OUT PORTD,R16
	NOP

	SBIS PIND,6
	LDI direction,4

	RJMP InitKeyboard


moveRight:
	; Horisontal movement----------------------------------
	ROR bytesnake							; Horisontal diplacement
	BRCC isZero
	/* 
	The carry bit is set so we've got to change the rectangle to the one on the right 
	*/

	ST Z,bytesnake						; Write R17 to the current Z
	ROR bytesnake							; Rotating R17 here puts back the carry into the bit sequence
	LDI R16,65						; We've got to check if we reached the screen boundary
	CheckWall5:
		CP ZL,R16
		BRNE notLineX5
	ADIW Z,4
	ST Z,bytesnake
	CLC
	RJMP notDown
	notLineX5:

		SUBI R16,10
		BRGE CheckWall5
	LDI R16,70

	CheckWall0:
		CP ZL,R16
		BRNE notLineX0
	ADIW Z,4
	ST Z,bytesnake
	CLC
	RJMP notDown
	notLineX0:
		SUBI R16,10
		BRGE CheckWall0
	ST -Z,bytesnake
	CLC
	RJMP notDown
	isZero:
		ST Z,bytesnake							; Horisontal diplacement
		RJMP notDown
	;------------------------------------------------------

moveLeft:
	; Horisontal movement----------------------------------
	ROL bytesnake							; Horisontal diplacement
	BRCC noCarry
	ST Z,bytesnake
	ROL bytesnake
	
	LDI R16,69
	CheckWall9:
		CP ZL,R16
		BRNE notLineX9
	SBIW Z,4
	ST Z,bytesnake
	CLC
	RJMP notDown
	notLineX9:
		SUBI R16,10
		BRGE CheckWall9


	LDI R16,64

	CheckWall4:
		CP ZL,R16
		BRNE notLineX4
	SBIW Z,4
	ST Z,bytesnake
	CLC
	RJMP notDown
	notLineX4:
		SUBI R16,10
		BRGE CheckWall4
	ADIW Z,1
	ST Z,bytesnake
	CLC
	RJMP notDown
	noCarry:
		ST Z,bytesnake							; Horisontal diplacement
		RJMP notDown
	;------------------------------------------------------


;Timer2OverflowInterrupt:
;RETI


Timer1OverflowInterrupt:
/*
This interrupt moves the spread.
*/
	PUSH YL
	PUSH XL
	PUSH R16
	PUSH R19

	LDI ZH,0x01

	CPI direction,6
	BRNE notRight
	RJMP moveRight
	
	notRight:
		CPI direction,4
		BRNE notLeft
	RJMP moveLeft

	notLeft:
		CPI direction,8
		BRNE notUp

	;Vertical movement-------------------------------
	LDI R16,0
	ST Z,R16							; Set Z to 0

	MOV R19,ZL
	CPI ZL,60							; Compare ZL to 60 if higher then change the rect
	BRLO ChangeBlockUp
	LDI R16,65
	SUB ZL,R16							;Subtract 65 from ZL but don't worry we add 10 at the end!
	CPI R19,65							;Compare the original ZL with 75 to see if we are at the top of the screen
	BRLO ChangeBlockUp
	SBIW ZL,10
	ChangeBlockUp:
		ADIW ZL,10						; Subtract 10 from Z
		LDI ZH,0x01
		ST Z,bytesnake
	RJMP notDown
	;------------------------------------------------
	notUp:
		CPI direction,2
		BRNE notDown
	;Vertical movement-------------------------------
	LDI R16,0
	ST Z,R16							; Set Z to 0

	MOV R19,ZL							; Value of ZL to R19
	CPI ZL,10							; Compare ZL to 10 if smaller then change the rect
	BRSH ChangeBlock
	LDI R16,65						
	ADD ZL,R16							;Adding 65 to ZL since it is lower than 20
	CPI R19,5							;Compare the original ZL with 5 to see if we are at the bottom of the screen
	BRSH ChangeBlock
	ADIW ZL,10							;We're at the bottom so ZL = ZL + 65 + 10
	ChangeBlock:
		SBIW ZL,10							; Subtract 10 from Z
		LDI ZH,0x01
		ST Z,bytesnake

	;------------------------------------------------
	notDown:
	/*
	This small section is responisible for eating an obstacle/object.
	*/
	MOV XL,ZL
	LD R19,X
	AND R19,bytesnake
	CPI R19,0
	BRNE Gameover
	MOV YL,ZL
	LD R19,Y
	SUB R19,bytesnake
	BRNE noOnFood

	ST Y,R19         

	; Updating the score
	LDI R16,1
	ADD score,R16

	; Turning up the speed
	LDI R16,15
	LDI R19,0xF0
	CPSE speed,R19						; Compare, Skip if Equal -> so we reached maximum speed
	ADD speed,R16

	            
	LSFR270new :
		MOV R16, random                 ; Clone random to R16                    ex : R16 = 0b01111110
		MOV R19, random                 ; Clone random to R19                         R17 = 0b01111110
		LSR random                      ; Shift to the right random                   random = 0b00111111
		BST R16,0					    ; Take the first bit of R16                   T = 0
		BLD random,6                    ; Put this at seventh place of random         random = 0b00111111
		BLD R19,6                       ; Same for R19                                R17 = 0b00111110
		EOR R19,R16                     ; R19 = R16 xor R19                           R17 = 0b01000000
		BST R19,6                       ; Take the seventh bit of R19                 T = 1
		BLD random,5                    ; Put this at the sixth place of random       random = 0b00111111
	generatenew :
		ANDI random,0b011111111         ; We want a random number < 70 => we need 7 bits => random,7 = 0
		CPI random,70                   ; Compare random register to 70
		BRSH LSFR270new                 ; If it's equal or bigger than 70 use LSFR
		LDI XL,0x00
		ADD XL,random
		LD R16,X
		AND R16,bytesnake
		CPI R16,0
		BRNE LSFR270new 
	foodnew : 
		LDI YL,0x00                     ; Begin Y = 0x0200
		ADD YL,random				    ; Add it the random number smaller than 70
		ST Y,bytesnake			      	    ; Put the value pointed by Y
	noOnFood:

		;Setting the TCNT1 

		LDI R16,0xFF	
		STS TCNT1H,speed
		STS TCNT1L,R16



		POP R19
		POP R16
		POP XL
		POP YL
		RETI

Gameover :
	RJMP mazeGame

Timer0OverflowInterrupt:
/*
The goal of the interrupt is to refresh the screen,
*/
;Initialising Z
PUSH R16
PUSH R17						;save R17 on the stack
PUSH R18
PUSH R19
PUSH R22
PUSH R25

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

LDI XL,0x00
LDI XH,0x03						
LD R25,X+						

;Rows counter
LDI R22,0x02

Send1Row:
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
		BRCC maze						;Branch if carry is 0
		SUBI toggle,1
		BRNE maze
		SBI PORTB,3							;carry is 1 => set PB3 high
		LDI toggle,3
	maze:
		ROR R25								;Rotate R18 right througth carry
		BRCC noObstacle						;Branch if carry is 0
		SBI PORTB,3							;carry is 1 => set PB3 high
		
	
	noObstacle:
		CBI PORTB,5							;Set PB5 low
		SBI PORTB,5							;Set PB5 high
		DEC R20
		BRNE CONTINUE						;Branch if not all the bits have been analysed
								
	LDI R20,8
	LD R17,Z+							;write value from address pointed by Z to Ra and auto-increse Z pointer
	LD R18,Y+
	LD R25,X+

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

	;PB4 delay parameters
	LDI R16,9								;Setting up the delay between SBI PB4 and CBI PB4
	LDI R20,255
	time1:
		time2:
			DEC R16
			BRNE time2
			LDI R16,9
		DEC R20
	BRNE time1
	LDI R20,255
	CBI PORTB,4								;Set PB4 low

	TST R22									;Check if R22 = 0x00
	BRNE Send1Row							;If R22 != 0x00 plot next row if not, stop the time interrupt
	POP YL
	POP ZL

	POP R25
	POP R22
	POP R19
	POP R18
	POP R17									;restore R17 from the stack
	POP R16
	CLC
	RETI

// ---------------------- Game over --------------------------------------------
mazeGame :
	LDI XL,0x00
	LDI XH,0x01
	LDI R16,3
	ST X+,R16
	LDI R16,1
	ST X+,R16
	LDI R16,4
	ST X+,R16
	LDI R16,2
	ST X+,R16
	LDI R16,0
	LDI R17,4
	loop1 :
		ST X+,R16
		DEC R17
	BRNE loop1
		LDI R16,5
	ST X+,R16
	LDI R16,10
	ST X+,R16
	LDI R16,2
	ST X+,R16
	LDI R16,7
	ST X+,R16
	LDI R16,0
	ST X+,R16
		LDI R16,6
	ST X+,R16
	LDI R16,9
	ST X+,R16
	LDI R16,8
	ST X,R16
	;RETI

startGame :
	LDI R16,6
	LDI R18,0b01000000

displayGame :
	LDI XL,0x10
	LDI XH,0x01
	LDI R17,8
	LDI R19,16
	 
blocksloopGame :
	LDI ZL,low(CharTable << 1)
	LDI ZH,high(CharTable << 1)
	LD R21,-X
	MUL R21,R17
	MOV R21,R0
	ADD R21,R16
	ADC ZL,R21
	BRCC ncGame
	LDI R21,1
	ADD ZH,R21
	ncGame :
		LPM R21,Z
		LDI R20,5

blockGame :
	ROR R21
	BRCC turnoffGame
	SBI PORTB,3

turnoffGame :
	SBI PORTB,5
	CBI PORTB,5
	CBI PORTB,3
	DEC R20
	BRNE blockGame

DEC R19
BRNE blocksloopGame
MOV R21,R18

rowonGame :
	ROL R21
	BRCC rowoffGame
	SBI PORTB,3

rowoffGame :
	SBI PORTB,5
	CBI PORTB,5
	CBI PORTB,3
	DEC R17
	BRNE rowonGame

SBI PORTB,4
LDI R19,255
LDI R20,9
wait1Game:
	wait2Game:
		DEC R20
		BRNE wait2Game
	LDI R20,9
	DEC R19
	BRNE wait1Game
CBI PORTB,4

DEC R16
LSR R18
BREQ startGame
RJMP displayGame

CharTable:
.db 0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000,0b00000000 ;nothing => 0
.db 0b00000100,0b00001010,0b00010001,0b00010001,0b00011111,0b00010001,0b00010001,0b00000000 ;A => 1
.db 0b00011111,0b00010000,0b00010000,0b00011111,0b00010000,0b00010000,0b00011111,0b00000000 ;E => 2
.db 0b00011111,0b00010000,0b00010000,0b00010111,0b00010001,0b00010001,0b00011111,0b00000000 ;G => 3
.db 0b00010001,0b00011011,0b00010101,0b00010001,0b00010001,0b00010001,0b00010001,0b00000000 ;M => 4
.db 0b00011111,0b00010001,0b00010001,0b00010001,0b00010001,0b00010001,0b00011111,0b00000000 ;O => 5
.db 0b00011111,0b00010001,0b00010001,0b00011111,0b00010000,0b00010000,0b00010000,0b00000000 ;P => 6
.db 0b00011111,0b00010001,0b00010001,0b00011111,0b00010100,0b00010010,0b00010001,0b00000000 ;R => 7
.db 0b00011111,0b00010000,0b00010000,0b00011111,0b00000001,0b00000001,0b00011111,0b00000000 ;S => 8
.db 0b00011111,0b00000100,0b00000100,0b00000100,0b00000100,0b00000100,0b00000100,0b00000000 ;T => 9
.db 0b00010001,0b00010001,0b00010001,0b00010001,0b00010001,0b00001010,0b00000100,0b00000000 ;V => 10

