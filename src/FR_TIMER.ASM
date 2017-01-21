
;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
; That module have any necessary function
; related to the time. It sinchronizes all
; the movements. The timer handler have a
; milisecond precision. It can give random
; numbers, random screen positions and random
; directions.
;
;------------------------------------------------


;------------------------------------------------


        PUBLIC  InstallMyTimer
        PUBLIC  Timer
        PUBLIC  RestoreTimer
        PUBLIC  Random
        PUBLIC  RandomPos
        PUBLIC  RandomDir
        PUBLIC  GetSeed
        PUBLIC  ReboundSnd
        PUBLIC  Delay

        PUBLIC  timecount
        PUBLIC  virdelay

        EXTRN   gflags:BYTE
        EXTRN   nvirus:WORD
        EXTRN   shot:BYTE
        EXTRN   extra:BYTE

        EXTRN   MoveVirus:FAR
        EXTRN   UpdVirus:FAR
        EXTRN   MoveShot:FAR
        EXTRN   MoveExtra:FAR


;------------------------------------------------


_TDATA  SEGMENT

oldoff  DW  ?
oldseg  DW  ?

seed    DW  ?

nballs  DW  ?

timecount DW  00h
oldcount  DW  00h
sndcount  DW  00h
vircount  DW  05h  DUP  (00h)
shotcount DW  00h
extcount  DW  00h

sounds    DW  659, 784, 523, 2088
snddelay  DW  10, 20, 50, 10
virdelay  DW  05h  DUP  (1000)
shotdelay DW  50
extdelay  DW  200

_TDATA  ENDS


;------------------------------------------------

_TCODE  SEGMENT
        ASSUME  CS:_TCODE, DS:_TDATA

;------------------------------------------------
; Installs my timer interrupt handler
;
; Input:
; Output:
;------------------------------------------------
InstallMyTimer  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     AX, _TDATA
        MOV     DS, AX

        MOV     AX, SEG nvirus
        MOV     ES, AX
        MOV     BX, OFFSET nvirus
        MOV     AX, ES:[BX]
        MOV     nballs, AX

        XOR     AX, AX
        MOV     ES, AX

        MOV     AX, ES:[20h]
        MOV     [oldoff], AX
        MOV     ES:[1E0h], AX
        MOV     AX, ES:[22h]
        MOV     [oldseg], AX
        MOV     ES:[1E2h], AX

        MOV     AX, OFFSET Timer
        MOV     BX, SEG Timer

        CLI
        MOV     ES:[20h], AX
        MOV     ES:[22h], BX

        MOV     AL, 00110110b
        OUT     43h, AL
        JMP     $+2
        MOV     AL, 0A9h
        OUT     40h, AL
        JMP     $+2
        MOV     AL, 04h
        OUT     40h, AL
        JMP     $+2
        STI

        POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
InstallMyTimer  ENDP


;------------------------------------------------
; The timer interrupt handler
;
; Input: None
; Output: None
;------------------------------------------------
Timer  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DX
        PUSH    DI
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     AX, _TDATA
        MOV     DS, AX

        INC     WORD PTR timecount

        MOV     BX, SEG gflags
        MOV     ES, BX
        MOV     BX, OFFSET gflags
        XOR     DX, DX
        MOV     DL, ES:[BX]

        TEST    DL, 04h
        JNZ     MOVE
        JMP     SND
MOVE:   TEST    DL, 80h
        JZ      M12

        CMP     vircount[00h], 00h
        JA      DECVC
        MOV     AX, virdelay[00h]
        MOV     vircount[00h], AX
        XOR     DI, DI
        CALL    MoveVirus
        CALL    UpdVirus
        JMP     SND
DECVC:  DEC     WORD PTR vircount[00h]
        JMP     SND

M12:    XOR     DI, DI
MOVV:   MOV     SI, DI
        SHL     SI, 01h
        CMP     vircount[SI], 00h
        JA      NEXTV
        CALL    MoveVirus
NEXTV:  INC     DI
        CMP     DI, nballs
        JB      MOVV

        XOR     DI, DI
UPDV:   MOV     SI, DI
        SHL     SI, 01h
        CMP     vircount[SI], 00h
        JA      DECC
        MOV     AX, virdelay[SI]
        MOV     vircount[SI], AX
        CALL    UpdVirus
        JMP     NEXTB
DECC:   DEC     WORD PTR vircount[SI]
NEXTB:  INC     DI
        CMP     DI, nballs
        JB      UPDV

SND:    CMP     sndcount, 00h
        JE      CSHOT
        CMP     sndcount, 01h
        JA      DECDEL
        IN      AL, 61h
        AND     AL, 0FCh
        OUT     61h, AL

DECDEL: DEC     sndcount

CSHOT:  MOV     BX, OFFSET shot
        CMP     ES:[BX], BYTE PTR 01h
        JNE     CEXTRA
        CMP     shotcount, 00h
        JA      DECS
        MOV     AX, shotdelay
        MOV     shotcount, AX
        CALL    MoveShot
        JMP     CEXTRA
DECS:   DEC     WORD PTR shotcount

CEXTRA: MOV     BX, OFFSET extra
        CMP     ES:[BX], BYTE PTR 01h
        JNE     DONEXT
        CMP     extcount, 00h
        JA      DECE
        MOV     AX, extdelay
        MOV     extcount, AX
        CALL    MoveExtra
        JMP     DONEXT
DECE:   DEC     WORD PTR extcount

DONEXT: CMP     oldcount, 00h
        JA      DECOLD
        JMP     OLDINT
DECOLD: DEC     WORD PTR oldcount

        MOV     AL, 20h
        OUT     20h, AL
        JMP     END_T

OLDINT: MOV     oldcount, 55
        INT     78h

END_T:  POP     ES
        POP     DS
        POP     SI
        POP     DI
        POP     DX
        POP     BX
        POP     AX

        IRET
Timer  ENDP


;------------------------------------------------
; Restores the original timer handler
;
; Input: None
; Output: None
;------------------------------------------------
RestoreTimer  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     AX, _TDATA
        MOV     DS, AX

        XOR     AX, AX
        MOV     ES, AX

        MOV     AX, [oldoff]
        MOV     BX, [oldseg]

        CLI
        MOV     ES:[20h], AX
        MOV     ES:[22h], BX

        MOV     AL, 00110110b
        OUT     43h, AL
        JMP     $+2
        MOV     AL, 00h
        OUT     40h, AL
        JMP     $+2
        OUT     40h, AL
        JMP     $+2
        STI

        POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
RestoreTimer  ENDP


;------------------------------------------------
; Obtains a pseudorandom number within the
; interval [0,range-1]
;
; Input: BX=range
; Output: BX=pseudorandom number
;------------------------------------------------
Random  PROC  FAR
        PUSH    AX
        PUSH    DX
        PUSH    DS

        MOV     AX, _TDATA
        MOV     DS, AX

        XOR     AX, AX
        OUT     43h, AL
        IN      AL, 40h
        MOV     AH, AL
        IN      AL, 40h

        ADD     AX, seed
        ROL     AX, 01h
        ROL     AX, 01h
        ROL     AX, 01h
        ROL     AX, 01h
        XOR     DX, DX
        DIV     BX
        MOV     BX, DX

        POP     DS
        POP     DX
        POP     AX

        RET
Random  ENDP


;------------------------------------------------
; Given two max coordinates it returns a
; random position within the coordinates
;
; Input: BH=max row
;        BL=max column
; Output: BH=random row
;         BL=random column
;------------------------------------------------
RandomPos  PROC FAR
        PUSH    AX

        MOV     AX, BX

        XOR     BX, BX
        MOV     BL, AH
        CALL    Random
        MOV     AH, BL

        XOR     BX, BX
        MOV     BL, AL
        CALL    Random

        MOV     BH, AH

        POP     AX

        RET
RandomPos  ENDP

;------------------------------------------------
; Returns two random directions, wich may
; be 1 or -1
;
; Input: None
; Output: AH=random direction
;         AL=random direction
;------------------------------------------------
RandomDir  PROC FAR
        PUSH    BX
        PUSH    CX

        MOV     BX, 0FFFFh
        CALL    Random
        OR      BH, BH
        JS      NEGA
        MOV     AH, BYTE PTR 1
        JMP     COL
NEGA:   MOV     AH, BYTE PTR -1
COL:    OR      BL, BL
        JNS     POS
        MOV     AL, BYTE PTR -1
        JMP     DONE
POS:    MOV     AL, BYTE PTR 1

DONE:   POP     CX
        POP     BX

        RET
RandomDir  ENDP


;------------------------------------------------
; Gets the seed value so we can
; generate a better pseudorandom number
;
; Input: None
; Output: None
;------------------------------------------------
GetSeed  PROC FAR
        PUSH    AX
        PUSH    DS

        MOV     AX, _TDATA
        MOV     DS, AX

        XOR     AX, AX
        OUT     43h, AL
        IN      AL, 40h
        MOV     AH, AL
        IN      AL, 40h

        MOV     seed, AX

        POP     DS
        POP     AX

        RET
GetSeed  ENDP


;------------------------------------------------
; Activates the speaker with a specific
; frequency, and it remains active till
; the timer handler deactivates it
;
; Input: SI=kind of sound to make (0-3)
; Output: None
;------------------------------------------------
ReboundSnd  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DX
        PUSH    DS

        MOV     AX, _TDATA
        MOV     DS, AX

        SHL     SI, 01h
        MOV     BX, sounds[SI]
        MOV     DX, 12h
        MOV     AX, 34DCh
        DIV     BX
        MOV     BX, AX

        MOV     AL, 10110110b
        OUT     43h, AL

        MOV     AL, BL
        OUT     42h, AL
        MOV     AL, BH
        OUT     42h, AL

        MOV     BX, snddelay[SI]
        MOV     sndcount, BX

        IN      AL, 61h
        OR      AL, 03h
        OUT     61h, AL

        POP     DS
        POP     DX
        POP     BX
        POP     AX

        RET
ReboundSnd  ENDP


;------------------------------------------------
; Makes a delay in the program
;
; Input: AX=Delay time
; Output: None
;------------------------------------------------
Delay  PROC FAR
        PUSH    BX
        PUSH    DS

        MOV     BX, _TDATA
        MOV     DS, BX

        MOV     BX, timecount
        ADD     BX, AX

AWAIT:  CMP     BX, timecount
        JA      AWAIT

        POP     DS
        POP     BX

        RET
Delay  ENDP


_TCODE  ENDS
        END


;------------------------------------------------
