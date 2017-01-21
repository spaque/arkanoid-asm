
;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
;
; The keyboard module's got the keystrokes
; associated procedures, which were installed
; at the beggining of the program. If there's
; a keystroke with no associated function
; the keyboard handler does nothing but return
;
;------------------------------------------------


;------------------------------------------------


        PUBLIC  InstallMyKeyb
        PUBLIC  Keyboard
        PUBLIC  RestoreKeyb
        PUBLIC  InitPad
        PUBLIC  TurnPadDir


        EXTRN   DrawPad:FAR
        EXTRN   RestorePad:FAR

        EXTRN   InitShot:FAR

        EXTRN   Delay:FAR

        EXTRN   SpeakerOn:FAR
        EXTRN   SpeakerOff:FAR

        EXTRN   gflags:BYTE
        EXTRN   nvirus:WORD
        EXTRN   virdelay:WORD
        EXTRN   shot:BYTE


;------------------------------------------------


_KDATA  SEGMENT

oldoff  DW  ?
oldseg  DW  ?

nballs  DW  ?
gmode   DB  1

keybflags   DB  ?
origflags   DB  ?

procedures  DW  90  DUP  (?)

pad_pos DB  37
pad_len DB  04h
pad_del DW  100

_KDATA  ENDS


;------------------------------------------------


_KCODE  SEGMENT
        ASSUME  CS:_KCODE, DS:_KDATA


;------------------------------------------------
; Sets up the procedures' array
;
; Input: None
; Output: None
;------------------------------------------------
InstallProcs  PROC
        PUSH    BX
        PUSH    DI
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        MOV     BX, OFFSET Nothin
        XOR     SI, SI
AGAIN:  MOV     DI, SI
        SHL     DI, 01h
        MOV     procedures[DI], BX
        INC     SI
        CMP     SI, 90
        JBE     AGAIN

        MOV     BX, nballs

        MOV     SI, 75
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET MoveLeft

        MOV     SI, 77
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET MoveRight

        MOV     SI, 72
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET SpeedUpB

        MOV     SI, 80
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET SpeedDownB

        MOV     SI, 15
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET TurnSound

        MOV     SI, 86
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET ChgPadLength

        MOV     SI, 30
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyA

        MOV     SI, 48
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyB

        CMP     BX, 01h
        JE      CONT

        MOV     SI, 46
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyC

        MOV     SI, 32
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyD

        CMP     BX, 02h
        JBE     CONT

        MOV     SI, 18
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyE

        MOV     SI, 33
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyF

        CMP     BX, 03h
        JBE     CONT

        MOV     SI, 34
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyG

        MOV     SI, 35
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyH

        CMP     BX, 04h
        JBE     CONT

        MOV     SI, 23
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyI

        MOV     SI, 36
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET KeyJ

CONT:   MOV     SI, 78
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET SpeedUpP

        MOV     SI, 74
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET SpeedDownP

        MOV     SI, 57
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET MShot

        MOV     SI, 59
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET F1

        MOV     SI, 60
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET F2

        MOV     SI, 61
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET F3

        MOV     SI, 42
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET LeftShift

        MOV     SI, 54
        SHL     SI, 01h
        MOV     procedures[SI], OFFSET RightShift

        MOV     SI, 02h
        MOV     procedures[SI], OFFSET Exit

        POP     DS
        POP     SI
        POP     DI
        POP     BX

        RET
InstallProcs  ENDP


;------------------------------------------------
; Installs the keyboard interrupt handler
;
; Input: None
; Output: None
;------------------------------------------------
InstallMyKeyb  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     AX, _KDATA
        MOV     DS, AX

        MOV     AX, SEG nvirus
        MOV     ES, AX
        MOV     BX, OFFSET nvirus
        MOV     AX, ES:[BX]
        MOV     nballs, AX

        MOV     gmode, 01h

        MOV     AX, 40h
        MOV     ES, AX
        MOV     AL, ES:[17h]
        MOV     origflags, AL
        MOV     keybflags, AL
        AND     ES:[17h], BYTE PTR 0Fh

        XOR     AX, AX
        MOV     ES, AX
        
        MOV     AX, ES:[24h]
        MOV     [oldoff], AX
        MOV     AX, ES:[26h]
        MOV     [oldseg], AX

        MOV     AX, OFFSET Keyboard
        MOV     BX, SEG Keyboard

        CLI
        MOV     ES:[24h], AX
        MOV     ES:[26h], BX
        CALL    InstallProcs
        STI

        POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
InstallMyKeyb  ENDP


;------------------------------------------------
; Initializes the paddle's data
;
; Input: None
; Output: None
;------------------------------------------------
InitPad  PROC FAR
        PUSH    AX
        PUSH    DS

        MOV     AX, _KDATA
        MOV     DS, AX

        CMP     gmode, 03h
        JB      END_IP

        MOV     AH, pad_pos
        MOV     AL, pad_len
        CALL    RestorePad

        MOV     pad_pos, BYTE PTR 37
        MOV     pad_len, BYTE PTR 04h
        MOV     pad_del, WORD PTR 100

        MOV     AH, pad_pos
        MOV     AL, pad_len
        CALL    DrawPad

END_IP: POP     DS
        POP     AX

        RET
InitPad  ENDP


;------------------------------------------------
; Moves the paddle to the left
;
; Input: None
; Output: None
;------------------------------------------------
MoveLeft  PROC
        PUSH    AX
        PUSH    DS

        MOV     AX, _KDATA
        MOV     DS, AX

        CMP     gmode, 03h
        JB      END_ML

        CMP     pad_pos, 01h
        JBE     END_ML

        MOV     AX, pad_del
        CALL    Delay
        MOV     AH, pad_pos
        MOV     AL, pad_len
        CALL    RestorePad
        DEC     BYTE PTR pad_pos
        DEC     AH
        CALL    DrawPad

END_ML: POP     DS
        POP     AX

        RET
MoveLeft  ENDP


;------------------------------------------------
; Moves the paddle to the right
;
; Input: None
; Output: None
;------------------------------------------------
MoveRight  PROC
        PUSH    AX
        PUSH    DS

        MOV     AX, _KDATA
        MOV     DS, AX

        CMP     gmode, 03h
        JB      END_MR

        MOV     AL, pad_pos
        ADD     AL, pad_len
        CMP     AL, 79
        JAE     END_MR

        MOV     AX, pad_del
        CALL    Delay
        MOV     AH, pad_pos
        MOV     AL, pad_len
        CALL    RestorePad
        INC     BYTE PTR pad_pos
        INC     AH
        CALL    DrawPad

END_MR: POP     DS
        POP     AX

        RET
MoveRight  ENDP


;------------------------------------------------
; Decreases the delay of a specific ball
;
; Input: SI=number of the ball to be accelerated
; Output: None
;------------------------------------------------
DecDelay  PROC
        PUSH    BX
        PUSH    SI
        PUSH    ES

        MOV     BX, SEG virdelay
        MOV     ES, BX
        MOV     BX, OFFSET virdelay

        SHL     SI, 01h
        CMP     ES:[BX+SI], WORD PTR 10
        JBE     END_DD
        SUB     ES:[BX+SI], WORD PTR 10

END_DD: POP     ES
        POP     SI
        POP     BX

        RET
DecDelay  ENDP


;------------------------------------------------
; Increases the ball's delay specified
;
; Input: SI=number of the ball to be slowed down
; Output: None
;------------------------------------------------
IncDelay  PROC
        PUSH    BX
        PUSH    SI
        PUSH    ES

        MOV     BX, SEG virdelay
        MOV     ES, BX
        MOV     BX, OFFSET virdelay

        SHL     SI, 01h
        CMP     ES:[BX+SI], WORD PTR 2000
        JAE     END_ID
        ADD     ES:[BX+SI], WORD PTR 10

END_ID: POP     ES
        POP     SI
        POP     BX

        RET
IncDelay  ENDP


;------------------------------------------------
; Speeds up all the balls
;
; Input: None
; Output: None
;------------------------------------------------
SpeedUpB  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        MOV     BX, nballs

        XOR     SI, SI
        
        CMP     gmode, 03h
        JB      NOTYET
        CALL    DecDelay
        JMP     END_SU

        XOR     SI, SI
NOTYET: CALL    DecDelay
        INC     SI
        CMP     SI, BX
        JB      NOTYET

END_SU: POP     DS
        POP     SI
        POP     BX

        RET
SpeedUpB  ENDP


;------------------------------------------------
; Slows down all the balls
;
; Input: None
; Output: None
;------------------------------------------------
SpeedDownB  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        MOV     BX, nballs

        XOR     SI, SI

        CMP     gmode, 03h
        JB      HERE
        CALL    IncDelay
        JMP     END_SD

        XOR     SI, SI
HERE:   CALL    IncDelay
        INC     SI
        CMP     SI, BX
        JB      HERE

END_SD: POP     DS
        POP     SI
        POP     BX

        RET
SpeedDownB  ENDP


;------------------------------------------------
; Turns the sounds on or off
;
; Input: None
; Output: None
;------------------------------------------------
TurnSound  PROC
        PUSH    BX
        PUSH    ES

        MOV     BX, SEG gflags
        MOV     ES, BX
        MOV     BX, OFFSET gflags

        TEST    ES:[BX], BYTE PTR 08h
        JNZ     QSND

        OR      ES:[BX], BYTE PTR 08h
        MOV     BX, 0B800h
        MOV     ES, BX
        MOV     ES:[1002h], BYTE PTR 0Eh
        MOV     ES:[1003h], BYTE PTR 0Fh
        MOV     ES:[2002h], BYTE PTR 0Eh
        MOV     ES:[2003h], BYTE PTR 0Fh
        CALL    SpeakerOn
        JMP     END_TS

QSND:   AND     ES:[BX], BYTE PTR 0F7h
        MOV     BX, 0B800h
        MOV     ES, BX
        MOV     ES:[1002h], BYTE PTR 20h
        MOV     ES:[1003h], BYTE PTR 07h
        MOV     ES:[2002h], BYTE PTR 20h
        MOV     ES:[2003h], BYTE PTR 07h
        CALL    SpeakerOff

END_TS: POP     ES
        POP     BX

        RET
TurnSound  ENDP


;------------------------------------------------
; Modifies the state of a flag so that we
; can recognize some keystrokes
;
; Input: AL=keystroke scan code
; Output: None
;------------------------------------------------
LeftShift  PROC
        PUSH    BX
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        OR      AL, AL
        JS      BREAKL

        OR      keybflags, 02h
        JMP     ENDLSH

BREAKL: AND     keybflags, 0FDh

ENDLSH: POP     DS
        POP     BX

        RET
LeftShift  ENDP


;------------------------------------------------
; Modifies the state of a flag so that we
; can recognize some keystrokes
;
; Input: AL=keystroke scan code
; Output: None
;------------------------------------------------
RightShift  PROC
        PUSH    BX
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        OR      AL, AL
        JS      BREAKR

        OR      keybflags, 01h
        JMP     ENDRSH

BREAKR: AND     keybflags, 0FEh

ENDRSH: POP     DS
        POP     BX

        RET
RightShift  ENDP


;------------------------------------------------
; Changes the paddle's length
;
; Input: None
; Output: None
;------------------------------------------------
ChgPadLength  PROC
        PUSH    AX
        PUSH    DS

        MOV     AX, _KDATA
        MOV     DS, AX

        CMP     gmode, 03h
        JB      END_CL

        MOV     AH, pad_pos
        MOV     AL, pad_len
        CALL    RestorePad

        TEST    keybflags, BYTE PTR 03h
        JZ      DECL

        MOV     AL, pad_pos
        ADD     AL, pad_len
        CMP     AL, 79
        JAE     END_CL
        INC     BYTE PTR pad_len
        JMP     END_CL

DECL:   CMP     pad_len, 01h
        JBE     END_CL
        DEC     BYTE PTR pad_len

END_CL: MOV     AH, pad_pos
        MOV     AL, pad_len
        CALL    DrawPad

        POP     DS
        POP     AX

        RET
ChgPadLength  ENDP


;------------------------------------------------
; Increases the 1st ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyA  PROC
        PUSH    SI

        XOR     SI, SI
        CALL    DecDelay

        POP     SI

        RET
KeyA  ENDP


;------------------------------------------------
; Decreases the 1st ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyB  PROC
        PUSH    SI

        XOR     SI, SI
        CALL    IncDelay

        POP     SI

        RET
KeyB  ENDP


;------------------------------------------------
; Increases the 2nd ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyC  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KC

        MOV     SI, 01h
        CALL    DecDelay

END_KC: POP     DS
        POP     SI
        POP     BX

        RET
KeyC  ENDP


;------------------------------------------------
; Decreases the 2nd ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyD  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KD

        MOV     SI, 01h
        CALL    IncDelay

END_KD: POP     DS
        POP     SI
        POP     BX

        RET
KeyD  ENDP


;------------------------------------------------
; Increases the 3rd ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyE  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KE

        MOV     SI, 02h
        CALL    DecDelay

END_KE: POP     DS
        POP     SI
        POP     BX

        RET
KeyE  ENDP


;------------------------------------------------
; Decreases the 3rd ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyF  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KF

        MOV     SI, 02h
        CALL    IncDelay

END_KF: POP     DS
        POP     SI
        POP     BX

        RET
KeyF  ENDP


;------------------------------------------------
; Increases the 4th ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyG  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KG

        MOV     SI, 03h
        CALL    DecDelay

END_KG: POP     DS
        POP     SI
        POP     BX

        RET
KeyG  ENDP


;------------------------------------------------
; Decreases the 4th ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyH  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KH

        MOV     SI, 03h
        CALL    IncDelay

END_KH: POP     DS
        POP     SI
        POP     BX

        RET
KeyH  ENDP


;------------------------------------------------
; Increases the 5th ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyI  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KI

        MOV     SI, 04h
        CALL    DecDelay

END_KI: POP     DS
        POP     SI
        POP     BX

        RET
KeyI  ENDP


;------------------------------------------------
; Decreases the 5th ball's speed
;
; Input: None
; Output: None
;------------------------------------------------
KeyJ  PROC
        PUSH    BX
        PUSH    SI
        PUSH    DS

        MOV     BX, _KDATA
        MOV     DS, BX

        CMP     gmode, 03h
        JE      END_KJ

        MOV     SI, 04h
        CALL    IncDelay

END_KJ: POP     DS
        POP     SI
        POP     BX

        RET
KeyJ  ENDP


;------------------------------------------------
; Increases the paddle's speed
;
; Input: None
; Output: None
;------------------------------------------------
SpeedUpP  PROC
        PUSH    AX
        PUSH    ES

        MOV     AX, _KDATA
        MOV     DS, AX

        CMP     gmode, 03h
        JB      ENDSUP

        CMP     pad_del, WORD PTR 0
        JBE     ENDSUP
        SUB     pad_del, WORD PTR 10

ENDSUP: POP     ES
        POP     AX

        RET
SpeedUpP ENDP


;------------------------------------------------
; Decreases the paddle's speed
;
; Input: None
; Output: None
;------------------------------------------------
SpeedDownP  PROC
        PUSH    AX
        PUSH    ES

        MOV     AX, _KDATA
        MOV     DS, AX

        CMP     gmode, 03h
        JB      ENDSDP

        CMP     pad_del, WORD PTR 500
        JAE     ENDSDP
        ADD     pad_del, WORD PTR 10

ENDSDP: POP     ES
        POP     AX

        RET
SpeedDownP  ENDP


;------------------------------------------------
; Initializes the shot of the paddle
;
; Input: None
; Output: None
;------------------------------------------------
MShot  PROC
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     BX, _KDATA
        MOV     DS, BX
        MOV     BX, SEG shot
        MOV     ES, BX
        MOV     BX, OFFSET shot

        CMP     ES:[BX], BYTE PTR 01h
        JE      END_S

        CMP     gmode, 03h
        JNE     END_S
        MOV     AH, pad_pos
        MOV     AL, pad_len
        CALL    InitShot

END_S:  POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
MShot  ENDP


;------------------------------------------------
; It does nothing
;
; Input: None
; Output: None
;------------------------------------------------
Nothin  PROC
        RET
Nothin  ENDP


;------------------------------------------------
; Turns the game to first mode
;
; Input: None
; Output: None
;------------------------------------------------
F1  PROC
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     BX, _KDATA
        MOV     DS, BX
        MOV     BX, SEG gflags
        MOV     ES, BX
        MOV     BX, OFFSET gflags

        CMP     gmode, 01h
        JE      END_F1

        MOV     gmode, 01h
        OR      ES:[BX], BYTE PTR 10h
        AND     ES:[BX], BYTE PTR 0FBh

        AND     ES:[BX], BYTE PTR 1Fh
        OR      ES:[BX], BYTE PTR 20h

END_F1: POP     ES
        POP     DS
        POP     BX

        RET
F1  ENDP


;------------------------------------------------
; Turns the game to mode two
;
; Input: None
; Output: None
;------------------------------------------------
F2  PROC
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     BX, _KDATA
        MOV     DS, BX
        MOV     BX, SEG gflags
        MOV     ES, BX
        MOV     BX, OFFSET gflags

        CMP     gmode, 02h
        JE      END_F2

        MOV     gmode, 02h
        OR      ES:[BX], BYTE PTR 10h
        AND     ES:[BX], BYTE PTR 0FBh

        AND     ES:[BX], BYTE PTR 1Fh
        OR      ES:[BX], BYTE PTR 40h

END_F2: POP     ES
        POP     DS
        POP     BX

        RET
F2  ENDP


;------------------------------------------------
; Turns the game to third mode
;
; Input: None
; Output: None
;------------------------------------------------
F3  PROC
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     BX, _KDATA
        MOV     DS, BX
        MOV     BX, SEG gflags
        MOV     ES, BX
        MOV     BX, OFFSET gflags

        CMP     gmode, 03h
        JE      END_F3

        MOV     gmode, 03h
        OR      ES:[BX], BYTE PTR 10h
        AND     ES:[BX], BYTE PTR 0FBh

        AND     ES:[BX], BYTE PTR 1Fh
        OR      ES:[BX], BYTE PTR 80h

END_F3: POP     ES
        POP     DS
        POP     BX

        RET
F3  ENDP


;------------------------------------------------
; Modifies the state of the game flags
; with the aim of finish the program
;
; Input: None
; Output: None
;------------------------------------------------
Exit  PROC
        PUSH    BX
        PUSH    ES

        MOV     BX, SEG gflags
        MOV     ES, BX
        MOV     BX, OFFSET gflags

        OR      ES:[BX], BYTE PTR 01h
        AND     ES:[BX], BYTE PTR 0FBh

        POP     ES
        POP     BX

        RET
Exit  ENDP


;------------------------------------------------
; My own keyboard handler
;
; Input: None
; Output: None
;------------------------------------------------
Keyboard  PROC  FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS

        IN      AL, 60h

        STI

        CMP     AL, 0E0h
        JE      DONE
        CMP     AL, 0AAh
        JE      VALIDS
        CMP     AL, 0B6h
        JE      VALIDS
        CMP     AL, 90
        JA      DONE

VALIDS: MOV     BX, _KDATA
        MOV     DS, BX

        XOR     BH, BH
        MOV     BL, AL
        AND     BL, 7Fh

        SHL     BX, 01h
        MOV     BX, procedures[BX]
        CALL    NEAR PTR BX

DONE:   MOV     AL, 20h
        OUT     20h, AL

        POP     DS
        POP     BX
        POP     AX

        IRET
Keyboard  ENDP


;------------------------------------------------
; Turns the paddle's direction
;
; Input: None
; Output: None
;------------------------------------------------
TurnPadDir  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DI
        PUSH    SI
        PUSH    DS

        MOV     AX, _KDATA
        MOV     DS, AX

        MOV     SI, 75
        SHL     SI, 01h
        MOV     AX, procedures[SI]

        MOV     DI, 77
        SHL     DI, 01h
        MOV     BX, procedures[DI]

        MOV     procedures[DI], AX
        MOV     procedures[SI], BX

        POP     DS
        POP     SI
        POP     DI
        POP     BX
        POP     AX

        RET
TurnPadDir  ENDP


;------------------------------------------------
; Restores the original keyboard handler
;
; Input: None
; Output: None
;------------------------------------------------
RestoreKeyb  PROC  FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     AX, _KDATA
        MOV     DS, AX

        MOV     AX, 40h
        MOV     ES, AX
        MOV     AL, origflags
        MOV     ES:[17h], AL

        XOR     AX, AX
        MOV     ES, AX

        MOV     AX, [oldoff]
        MOV     BX, [oldseg]

        CLI
        MOV     ES:[24h], AX
        MOV     ES:[26h], BX
        STI

        POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
RestoreKeyb  ENDP

_KCODE  ENDS
        END


;------------------------------------------------
