  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

;; DECLARE SOME VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0
  
gamestate     .rs 1  ; .rs 1 means reserve one byte of space
ballx         .rs 1  ; ball horizontal position
bally         .rs 1  ; ball vertical position
ballup        .rs 1  ; 1 = ball moving up
balldown      .rs 1  ; 1 = ball moving down
ballleft      .rs 1  ; 1 = ball moving left
ballright     .rs 1  ; 1 = ball moving right
ballspeedx    .rs 1  ; ball horizontal speed per frame
ballspeedy    .rs 1  ; ball vertical speed per frame
paddle1ytop   .rs 1  ; player 1 paddle top vertical position
paddle2ybot   .rs 1  ; player 2 paddle bottom vertical position
buttons1      .rs 1  ; player 1 gamepad buttons, one bit per button
buttons2      .rs 1  ; player 2 gamepad buttons, one bit per button
scoreOnes     .rs 1  ; byte for each digit in the decimal score
scoreTens     .rs 1
scoreHundreds .rs 1
keyboardDown  .rs 9  


;; DECLARE SOME CONSTANTS HERE
STATETITLE     = $00  ; displaying title screen
STATEPLAYING   = $01  ; move paddles/ball, check for collisions
STATEGAMEOVER  = $02  ; displaying game over screen
  
RIGHTWALL      = $F4  ; when ball reaches one of these, do something
TOPWALL        = $20
BOTTOMWALL     = $E0
LEFTWALL       = $04
  
PADDLE1X       = $08  ; horizontal position for paddles, doesnt move
PADDLE2X       = $F0

;;;;;;;;;;;;;;;;;;




  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down


  


;;;Set some initial ball stats
  LDA #$01
  STA balldown
  STA ballright
  LDA #$00
  STA ballup
  STA ballleft
  
  LDA #$50
  STA bally
  
  LDA #$80
  STA ballx
  
  LDA #$02
  STA ballspeedx
  STA ballspeedy


;;;Set initial score value
  LDA #$00
  STA scoreOnes
  STA scoreTens
  STA scoreHundreds


;;:Set starting game state
  LDA #STATEPLAYING
  STA gamestate


              
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop, waiting for NMI
  
 

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  JSR DrawScore

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005
    
  ;;;all graphics updates done by here, run game engine


  JSR ReadController1  ;;get the current button data for player 1
  ;;JSR ReadController2  ;;get the current button data for player 2
  JSR ReadKeyboard
  
GameEngine:  
  LDA gamestate
  CMP #STATETITLE
  BEQ EngineTitle    ;;game is displaying title screen
    
  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver  ;;game is displaying ending screen
  
  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying   ;;game is playing
GameEngineDone:  
  
  JSR UpdateSprites  ;;set ball/paddle sprites from positions

  RTI             ; return from interrupt
 
 
 
 
;;;;;;;;
 
EngineTitle:
  ;;if start button pressed
  ;;  turn screen off
  ;;  load game screen
  ;;  set starting paddle/ball position
  ;;  go to Playing State
  ;;  turn screen on
  JMP GameEngineDone

;;;;;;;;; 
 
EngineGameOver:
  ;;if start button pressed
  ;;  turn screen off
  ;;  load title screen
  ;;  go to Title State
  ;;  turn screen on 
  JMP GameEngineDone
 
;;;;;;;;;;;
 
EnginePlaying:

MoveBallRight:
  LDA ballright
  BEQ MoveBallRightDone   ;;if ballright=0, skip this section

  LDA ballx
  CLC
  ADC ballspeedx        ;;ballx position = ballx + ballspeedx
  STA ballx

  LDA ballx
  CMP #RIGHTWALL
  BCC MoveBallRightDone      ;;if ball x < right wall, still on screen, skip next section
  LDA #$00
  STA ballright
  LDA #$01
  STA ballleft         ;;bounce, ball now moving left
  ;;in real game, give point to player 1, reset ball
  jsr IncrementScore
MoveBallRightDone:


MoveBallLeft:
  LDA ballleft
  BEQ MoveBallLeftDone   ;;if ballleft=0, skip this section

  LDA ballx
  SEC
  SBC ballspeedx        ;;ballx position = ballx - ballspeedx
  STA ballx

  LDA ballx
  CMP #LEFTWALL
  BCS MoveBallLeftDone      ;;if ball x > left wall, still on screen, skip next section
  LDA #$01
  STA ballright
  LDA #$00
  STA ballleft         ;;bounce, ball now moving right
  ;;in real game, give point to player 2, reset ball
  jsr IncrementScore
MoveBallLeftDone:


MoveBallUp:
  LDA ballup
  BEQ MoveBallUpDone   ;;if ballup=0, skip this section

  LDA bally
  SEC
  SBC ballspeedy        ;;bally position = bally - ballspeedy
  STA bally

  LDA bally
  CMP #TOPWALL
  BCS MoveBallUpDone      ;;if ball y > top wall, still on screen, skip next section
  LDA #$01
  STA balldown
  LDA #$00
  STA ballup         ;;bounce, ball now moving down
MoveBallUpDone:


MoveBallDown:
  LDA balldown
  BEQ MoveBallDownDone   ;;if ballup=0, skip this section

  LDA bally
  CLC
  ADC ballspeedy        ;;bally position = bally + ballspeedy
  STA bally

  LDA bally
  CMP #BOTTOMWALL
  BCC MoveBallDownDone      ;;if ball y < bottom wall, still on screen, skip next section
  LDA #$00
  STA balldown
  LDA #$01
  STA ballup         ;;bounce, ball now moving down
MoveBallDownDone:

MovePaddleUp:
  ;;if up button pressed
  ;;  if paddle top > top wall
  ;;    move paddle top and bottom up
MovePaddleUpDone:

MovePaddleDown:
  ;;if down button pressed
  ;;  if paddle bottom < bottom wall
  ;;    move paddle top and bottom down
MovePaddleDownDone:
  
CheckPaddleCollision:
  ;;if ball x < paddle1x
  ;;  if ball y > paddle y top
  ;;    if ball y < paddle y bottom
  ;;      bounce, ball now moving left
CheckPaddleCollisionDone:

  JMP GameEngineDone
 
 
 
 
UpdateSprites:
  LDA bally  ;;update all ball sprite info
  STA $0200
  
  LDA #$30
  STA $0201
  
  LDA #$00
  STA $0202
  
  LDA ballx
  STA $0203
  
  ;;update paddle sprites
  RTS
 
 
DrawScore:
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$20
  STA $2006          ; start drawing the score at PPU $2020
  
;  LDA scoreHundreds  ; get first digit
;;  CLC
;;  ADC #$30           ; add ascii offset  (this is UNUSED because the tiles for digits start at 0)
;  CLC
;  ADC #$0A
;  STA $2007          ; draw to background

  LDA keyboardDown ; last row of matrix, highest bit is left arrow
  ; if highest bit is 0, left arrow is pressed down
  AND #$80 ; get the high bit only
  ;CLC
  BNE DrawA ; if not equal to 0, left key is NOT held down

  LDA #$23 ; 10 + 25 to get a Z character 
  JMP ZDone

  DrawA:
  LDA #$0A ; 10 to get an A

  ZDone:
  STA $2007

  LDA scoreTens      ; next digit
;  CLC
;  ADC #$30           ; add ascii offset
  CLC
  ADC #$0A
  STA $2007
  LDA scoreOnes      ; last digit
;  CLC
;  ADC #$30           ; add ascii offset
  CLC
  ADC #$0A
  STA $2007
  RTS
 
 
IncrementScore:
IncOnes:
  LDA scoreOnes      ; load the lowest digit of the number
  CLC 
  ADC #$01           ; add one
  STA scoreOnes
  CMP #$0A           ; check if it overflowed, now equals 10
  BNE IncDone        ; if there was no overflow, all done
IncTens:
  LDA #$00
  STA scoreOnes      ; wrap digit to 0
  LDA scoreTens      ; load the next digit
  CLC 
  ADC #$01           ; add one, the carry from previous digit
  STA scoreTens
  CMP #$0A           ; check if it overflowed, now equals 10
  BNE IncDone        ; if there was no overflow, all done
IncHundreds:
  LDA #$00
  STA scoreTens      ; wrap digit to 0
  LDA scoreHundreds  ; load the next digit
  CLC 
  ADC #$01           ; add one, the carry from previous digit
  STA scoreHundreds
IncDone:




 
ReadController1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController1Loop:
  LDA $4016
  LSR A            ; bit0 -> Carry
  ROL buttons1     ; bit0 <- Carry
  DEX
  BNE ReadController1Loop
  RTS
  
ReadController2:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController2Loop:
  LDA $4017
  LSR A            ; bit0 -> Carry
  ROL buttons2     ; bit0 <- Carry
  DEX
  BNE ReadController2Loop
  RTS  
  
ReadKeyboard:
  LDA #$05 ; 101
  STA $4016 ; reset to row 0, column 0
  LDX #$09
ReadKeyboardLoop:
  LDA #$04 ; 100
  STA $4016 ; select col 0, next row
  LDA $4017 ; 4 bits as 000xxxx0
  ASL A
  ASL A
  ASL A ; first one in the upper bits
  AND #$F0
  STA keyboardDown,X 
  LDA #$06 ; column 1
  STA $4016
  LDA $4017
  LSR A ; shift right one
  AND #$0F
  ORA keyboardDown, X
  STA keyboardDown, X
  DEX
  BPL ReadKeyboardLoop
  RTS




; this is silly, even for me
; keep a table of row#(0-8), col#(0-7), tile#?
; or keep a table with just incr across rows, and cols, yeah...

ScanCodeToTile2:
  LDX #$09 ; X goes per row
ScanCodeToTitleLoopRow:
  LDY #$01 ; Y per column
  LDA keyboardDown, X
ScanCodeToTitleLoopCol:
  AND Y

  ASL Y
  BCC ScanCodeToTitleLoopCol
  JMP ScanCodeToTitleLoopRow  




ScanCodeToTile:
  ; Return tile # in A
  ; "0" = 0, "A" = 10; " " = 36
  LDX #$06
  LDA keyboardDown, X
  ; K L O F6 0 P , .
  AND #$80
  BNE NotK
  LDA #$14
  RTS
  NotK:
  AND #$40
  BNE NotL
  LDA #$15
  RTS
  NotL:
  AND #$20
  BNE NotO
  LDA #$18
  RTS
  NotO:
  AND #$08
  BNE Not0
  LDA #$00
  RTS
  Not0:
  AND #$04
  BNE NotP
  LDA #$19
  RTS
  NotP:
  DEX
  LDA keyboardDown, X
  ; J U I F5 8 9 N M
  AND #$80
  BNE NotJ
  LDA #$13
  RTS
  NotJ:
  AND #$40
  BNE NotU
  LDA #$1E
  RTS
  NotU:
  AND #$20
  BNE NotI
  LDA #$12
  RTS
  NotI:
  AND #$08
  BNE Not8
  LDA #$08
  RTS
  Not8:
  AND #$04
  BNE Not9
  LDA #$09
  RTS
  Not9:
  AND #$02
  BNE NotN
  LDA #$17
  RTS
  NotN:
  AND #$01
  BNE NotM
  LDA #$16
  RTS
  NotM:
  ; do the rest
  RTS


    
        
;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $80, $32, $00, $80   ;sprite 0
  .db $80, $33, $00, $88   ;sprite 1
  .db $88, $34, $00, $80   ;sprite 2
  .db $88, $35, $00, $88   ;sprite 3


keylookup:
   ;  left rght up   clho ins  del  spc  down
  .db $25, $25, $25, $25, $25, $25, $24, $25
   ;  CTR  Q    ESC  f1   2    1    grph lshf
  .db $25, $1A, $25, $25, $02, $01, $25, $25
   ;  A    S    W    f2   3    E    Z    X
  .db $0A, $1C, $20, $25, $03, $0E, $23, $21
   ;  D    R    T    f3   4    5    C    F
  .db $0D, $1B, $1D, $25, $04, $05, $0C, $0F
   ;  H    G    Y    f4   6    7    V    B
  .db $11, $10, $22, $25, $06, $07, $1F, $0B
   ;  J    U    I    F5   8    9    N    M
  .db $13, $1E, $12, $25, $08, $09, $17, $16
   ;  K    L    O    f6   0    P    ,    .
  .db $14, $15, $18, $25, $00, $19, $25, $25
   ;  ;    :    @    f7   ^    -    /    _
  .db $25, $25, $25, $25, $25, $25, $25, $25
   ;  [    ]    ret  f8   stop yen  rshf kana
  .db $25, $25, $25, $25, $25, $25, $25, $25


  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1