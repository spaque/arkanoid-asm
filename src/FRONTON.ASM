
;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
;
; This is the game main module, it arranges the
; enviroment so that the game can start by
; getting game parameter and installing the
; needed interrupts handlers. It also calculates
; the next position of all the moving objects.
; It controls the execution of each game mode by
; checking the game flags byte. It's entrusted
; with the restore stuff too at the end of the
; game
;
;------------------------------------------------


;------------------------------------------------


CR      EQU  13
LF      EQU  10


;------------------------------------------------


_FDATA  SEGMENT

msg     DB  LF, CR, ' Introduzca el numero de bolas: $'

nvirus  DW  ?
rows    DB  05h  DUP  (?)
columns DB  05h  DUP  (?)
rowdir  DB  05h  DUP  (?)
coldir  DB  05h  DUP  (?)
oldch   DB  05h  DUP  (?)
oldattr DB  05h  DUP  (?)
newrow  DB  05h  DUP  (?)
newcol  DB  05h  DUP  (?)

shot    DB  00h
shotrow DB  ?
shotcol DB  ?

extra    DB  00h
extrapos DW  ?
extch    DB  20h
extatt   DB  07h
exttype  DB  ?

gflags   DB  ?  ; bit 7 -> set in mode 3, clear in other mode
                ; bit 6 -> set in mode 2, clear in other mode
                ; bit 5 -> set in mode 1, clear in other mode
                ; bit 4 -> if set, we gotta change the game mode
                ; bit 3 -> set when we wanna hear sounds and music
                ; bit 2 -> set when the ball is moving
                ; bit 1 -> set when the ball goes out in the 3rd mode
                ; bit 0 -> if set, the program gotta finish off

frlifes   DB  ?
frpoints  DW  ?

cursorpos DW  ?

HelpFile  DB  'HELP.ME',0
OutBuffer DB  ?

_FDATA  ENDS


;------------------------------------------------


        PUBLIC  gflags
        PUBLIC  nvirus
        PUBLIC  shot
        PUBLIC  extra

        PUBLIC  MoveVirus
        PUBLIC  UpdVirus
        PUBLIC  MoveShot
        PUBLIC  InitShot
        PUBLIC  MoveExtra


        EXTRN   Random:FAR
        EXTRN   RandomPos:FAR
        EXTRN   RandomDir:FAR
        EXTRN   GetSeed:FAR
        EXTRN   InstallMyTimer:FAR
        EXTRN   RestoreTimer:FAR
        EXTRN   ReboundSnd:FAR

        EXTRN   InstallMyKeyb:FAR
        EXTRN   RestoreKeyb:FAR
        EXTRN   InitPad:FAR
        EXTRN   TurnPadDir:FAR

        EXTRN   StartScreen:FAR
        EXTRN   DrawScreen:FAR
        EXTRN   DrawVirus:FAR
        EXTRN   Restore:FAR
        EXTRN   GetOffset:FAR
        EXTRN   DrawPad:FAR
        EXTRN   RestorePad:FAR
        EXTRN   DrawScore:FAR
        EXTRN   DrawLifes:FAR

        EXTRN   InstallMyIRQ7Int:FAR
        EXTRN   RestoreIRQ7Int:FAR

        EXTRN   GetInitPos:FAR


;------------------------------------------------


_STACK  SEGMENT STACK
        DB  200h  DUP  (0)
_STACK  ENDS


;------------------------------------------------


_FCODE  SEGMENT
        ASSUME  CS:_FCODE, SS:_STACK, DS:_FDATA


;------------------------------------------------
; Gets a parameter from command line
; (it must be less or equal to 5)
;
; Input: ES=PSP segment
; Output: AX=parameter
;------------------------------------------------
GetParam  PROC FAR
        PUSH    DX
        PUSH    DS

        MOV     AX, _FDATA
        MOV     DS, AX

        CMP     ES:[81h], BYTE PTR 0Dh
        JE      INVIR
        MOV     AL, ES:[82h]    ; Grab the parameter
        CMP     AL, '?'
        JE      DONE_G
        SUB     AL, '0'
        CMP     AL, 00h
        JE      INVIR
        CMP     AL, 05h
        JA      INVIR
        JMP     DONE_G

INVIR:  MOV     AH, 09h         ; If parameter < 0 or > 5, ask for it
        LEA     DX, msg
        INT     21h

        MOV     AH, 01h
        INT     21h
        SUB     AL, '0'
        CMP     AL, 00h
        JE      INVIR
        CMP     AL, 05h
        JA      INVIR

DONE_G: XOR     AH, AH

        POP     DS
        POP     DX

        RET
GetParam  ENDP


;------------------------------------------------
; Shows a help screen
;
; Input: None
; Output: None
;------------------------------------------------
Help  PROC FAR

        MOV     AX, 0300h
        XOR     BX, BX
        INT     10h             ; Get current cursor position
        XOR     DL, DL
        XCHG    DH, DL
        MOV     SI, DX

        MOV     AX, 3D00h
        LEA     DX, HelpFile
        INT     21h             ; Open the file with the help
        JC      END_H
        MOV     BX, AX          ; File handle

READ_LOOP:
        MOV     AX, 3F00h
        LEA     DX, OutBuffer
        MOV     CX, 01h
        INT     21h
        JC      END_H

        CMP     AX, 00h         ; If we read 0 bytes, we've reached EOF
        JE      END_OF_FILE
        CMP     OutBuffer, BYTE PTR CR
        JNE     NOT_CR

        INC     SI
        CMP     SI, 24          ; If the cursor's at the screen's
        JB      NOT_CR          ; bottom do a pause

        XOR     AX, AX
        INT     16h
        MOV     SI, 1

NOT_CR: MOV     AH, 02h
        MOV     DL, OutBuffer
        INT     21h
        JMP     READ_LOOP

END_OF_FILE:
        MOV     AX, 3E00h
        INT     21h

END_H:  RET
Help  ENDP


;------------------------------------------------
; Initializes all the balls' data
;
; Input: None
; Output: None
;------------------------------------------------
Init_vr  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     AX, _FDATA
        MOV     DS, AX

        MOV     AX, 0B800h
        MOV     ES, AX
        XOR     SI, SI

AGAIN:  MOV     BH, 24
        MOV     BL, 79
        CALL    RandomPos
        MOV     CX, BX
        MOV     AX, 01h
        CALL    GetOffset
        CMP     ES:[BX], BYTE PTR 20h   ; If the position isn't empty
        JE      FREEP                   ; get another one
        JMP     AGAIN

FREEP:  MOV     rows[SI], CH
        MOV     columns[SI], CL
        CALL    RandomDir               ; Generate a random direction
        MOV     rowdir[SI], AH          ; for each ball
        MOV     coldir[SI], AL

        INC     SI
        CMP     SI, nvirus
        JB      AGAIN

        POP     ES
        POP     DS
        POP     SI
        POP     CX
        POP     BX
        POP     AX

        RET
Init_vr  ENDP


;------------------------------------------------
; Initializes the program
;
; Input: None
; Output: None
;------------------------------------------------
Init_pr  PROC FAR
        PUSH    AX
        PUSH    DS

        MOV     AX, _FDATA
        MOV     DS, AX

        CALL    GetSeed                 ; Gets the program's seed

        MOV     gflags, BYTE PTR 28h    ; Start the game at mode 1
        MOV     frlifes, BYTE PTR 05h   ; Lifes for the 3rd mode
        MOV     frpoints, WORD PTR 00h  ; Points for the 3rd mode

        CALL    Init_vr                 ; Initialize balls' position

        POP     DS
        POP     AX
        RET
Init_pr  ENDP


;------------------------------------------------
; Updates the scoreboard
;
; Input: AL=attribute of the block which the
;           the ball has collided with
; Output: None
;------------------------------------------------
UpdScore  PROC FAR
        PUSH    BX
        PUSH    DS

        MOV     BX, _FDATA
        MOV     DS, BX

        XOR     AH, AH
        MOV     BX, 0Ah
        MUL     BL              ; Get the points to add
        ADD     frpoints, AX
        MOV     AX, frpoints
        CALL    DrawScore       ; Update the scoreboard in the screen

        POP     DS
        POP     BX

        RET
UpdScore  ENDP


;------------------------------------------------
; Puts the shot in the middle of the paddle
; and start its movement
;
; Input: AH=paddle's position
;        AL=paddle's length
; Output: None
;------------------------------------------------
InitShot  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     BX, _FDATA
        MOV     DS, BX
        MOV     BX, 0B800h
        MOV     ES, BX

        MOV     shot, BYTE PTR 01h   ; Tell the program there's a shot moving

        SHR     AL, 01h         ; The shot starts in the middle
        ADD     AH, AL          ; of the paddle

        MOV     shotrow, BYTE PTR 23
        MOV     shotcol, AH
        MOV     BH, 23
        MOV     BL, AH
        MOV     AX, 02h
        CALL    GetOffset
        MOV     ES:[BX], BYTE PTR 0Fh           ; Draw the shot
        MOV     ES:[BX+01h], BYTE PTR 0Eh

        POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
InitShot  ENDP


;------------------------------------------------
; Puts the extra object into its initial
; position and says to the program that
; it has to move the object
;
; Input: AX=memory displacement of object
; Output: None
;------------------------------------------------
InitExtra  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     BX, _FDATA
        MOV     DS, BX
        MOV     BX, 0B800h
        MOV     ES, BX

        CMP     extra, BYTE PTR 01h     ; If there's already a extra
        JE      END_IE                  ; skip the new one

        MOV     BX, 0FFFFh
        CALL    Random
        CMP     BX, 6FFFh               ; Sometimes appears a extra
        JAE     END_IE

        MOV     extrapos, AX
        MOV     BX, 03h
        CALL    Random                  ; Get a random extra
        ADD     BX, 04h
        XCHG    AX, BX
        MOV     exttype, AL

        MOV     ES:[BX], AL             ; Draw the extra object
        MOV     ES:[BX+01h], BYTE PTR 0Ah

        MOV     extra, BYTE PTR 01h     ;

END_IE: POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
InitExtra  ENDP


;------------------------------------------------
; Moves the shot when it's been shot out
;
; Input: None
; Output: None
;------------------------------------------------
MoveShot  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     AX, _FDATA
        MOV     DS, AX
        MOV     AX, 0B800h
        MOV     ES, AX

        MOV     AX, 02h
        MOV     BH, shotrow
        MOV     BL, shotcol
        CALL    GetOffset
        MOV     ES:[BX], BYTE PTR 20h        ; Restore the original character
        MOV     ES:[BX+1], BYTE PTR 07h      ; and attribute

        CMP     ES:[BX-0A0h], BYTE PTR 0Ah   ; If the shot have crashed
        JNE     TOP                          ; into the bricks, update
        MOV     shot, 00h                    ; the score
        MOV     AL, ES:[BX-0A0h+01h]
        MOV     ES:[BX-0A0h], BYTE PTR 20h   ; Delete the brick
        MOV     ES:[BX-0A0h+01h], BYTE PTR 07h
        CALL    UpdScore
        MOV     AX, BX
        SUB     AX, 0A0h
        CALL    InitExtra
        TEST    gflags, BYTE PTR 08h
        JZ      END_MS
        MOV     SI, 03h
        CALL    ReboundSnd                   ; Make a PC-speaker sound
        JMP     END_MS
TOP:    CMP     ES:[BX-0A0h], BYTE PTR 0DCh  ; If it reach the top
        JNE     UPDS                         ; stop the shot
        MOV     shot, 00h
        JMP     END_MS

UPDS:   DEC     shotrow
        MOV     ES:[BX-0A0h], BYTE PTR 0Fh   ; Draw the shot again
        MOV     ES:[BX-0A0h+01h], BYTE PTR 0Eh

END_MS: POP     ES
        POP     DS
        POP     SI
        POP     BX
        POP     AX

        RET
MoveShot  ENDP


;------------------------------------------------
; Moves the extra object to its next position
; in the screen when it has appeared
;
; Input: None
; Output: None
;------------------------------------------------
MoveExtra  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS
        PUSH    ES

        MOV     BX, _FDATA
        MOV     DS, BX
        MOV     BX, 0B800H
        MOV     ES, BX

        MOV     BX, extrapos

        MOV     AL, extch               ; Restore the current position
        MOV     ES:[BX], AL
        MOV     AL, extatt
        MOV     ES:[BX+01h], AL

        CMP     BX, 2F00h               ; If the extra's in the 24th row
        JB      CHKG                    ; stop it moving
        MOV     extra, BYTE PTR 00h
        JMP     END_ME
CHKG:   CMP     ES:[BX+0A0h], BYTE PTR 0DFh  ; If it's touching the paddle
        JE      GRAB                         ; grab the extra

        ADD     extrapos, 0A0h               ; Move the extra and
        MOV     AL, ES:[BX+0A0h]             ; get the original character
        MOV     extch, AL                    ; and attribute
        MOV     AL, ES:[BX+0A1h]
        MOV     extatt, AL

        MOV     AL, exttype
        MOV     ES:[BX+0A0h], AL
        MOV     ES:[BX+0A1h], BYTE PTR 0Ah
        JMP     END_ME

GRAB:   CMP     exttype, BYTE PTR 04h
        JE      ADDLIFE
        CMP     exttype, BYTE PTR 05h
        JE      ADDPOINTS
        CMP     exttype, BYTE PTR 06h
        JE      TURNPAD
        MOV     extra, BYTE PTR 00h
        JMP     END_ME

ADDLIFE:
        MOV     extra, BYTE PTR 00h
        CMP     frlifes, BYTE PTR 09h
        JE      END_ME
        INC     BYTE PTR frlifes
        MOV     AL, frlifes
        CALL    DrawLifes
        JMP     END_ME

ADDPOINTS:
        MOV     extra, BYTE PTR 00h
        ADD     frpoints, WORD PTR 100
        MOV     AX, frpoints
        CALL    DrawScore
        JMP     END_ME

TURNPAD:
        MOV     extra, BYTE PTR 00h
        CALL    TurnPadDir              ; Reverse the paddle direction

END_ME: POP     ES
        POP     DS
        POP     BX
        POP     AX

        RET
MoveExtra  ENDP


;------------------------------------------------
; Checks if there's an obstacle at the side
; of the ball and if so returns the
; obstacle's offset
;
; Input: BX=displacement of the ball
;        DX=ball's position (row,column)
; Output: AX=1 if there's a diagonal obstacle
;         SI=displacement of the obstacle
;         AX=0 if not
;------------------------------------------------
VerObs  PROC FAR
        PUSH    BX
        PUSH    CX
        PUSH    DX

        MOV     CX, DX
        ADD     DL, coldir[DI]
        MOV     AX, 02h
        IMUL    BYTE PTR coldir[DI]
        MOV     SI, AX                  ; Offset of the position beside
                                        ; the ball (got it if necessary)
        XOR     AX, AX

CHCK1:  CMP     DL, 0           ; Look for an obstacle nearby the ball
        JAE     CHCK2
        MOV     AX, 01h
        JMP     END_VO
CHCK2:  CMP     DL, 80
        JB      CHCK3
        MOV     AX, 01h
        JMP     END_VO
CHCK3:  CMP     ES:[BX+SI], BYTE PTR 20h
        JE      END_VO
        MOV     AX, 01h

END_VO: POP     DX
        POP     CX
        POP     BX

        RET
VerObs  ENDP


;------------------------------------------------
; Checks if there's an obstacle up the ball or
; down the ball and if so returns the
; obstacle's offset
;
; Input: BX=displacement of the ball
;        DX=ball's position (row,column)
; Output: AX=1 if there's a diagonal obstacle
;         SI=displacement of the obstacle
;         AX=0 if not
;------------------------------------------------
HorObs  PROC FAR
        PUSH    BX
        PUSH    CX
        PUSH    DX

        MOV     CX, DX
        MOV     AL, rowdir[DI]
        CBW
        MOV     SI, 0A0h
        IMUL    SI
        MOV     SI, AX                  ; Offset of position up or
        MOV     DX, CX                  ; down the ball
        ADD     DH, rowdir[DI]

        XOR     AX, AX

CHCK4:  CMP     DH, 0                   ; Look for an obstacle up
        JAE     CHCK5                   ; or down the ball
        MOV     AX, 01h
        JMP     END_HO
CHCK5:  CMP     DH, 24
        JBE     CHCK6
        MOV     AX, 01h
        JMP     END_HO
CHCK6:  CMP     ES:[BX+SI], BYTE PTR 20h
        JE      END_HO
        MOV     AX, 01h

END_HO: POP     DX
        POP     CX
        POP     BX

        RET
HorObs  ENDP


;------------------------------------------------
; Checks if there's an obstacle at the
; ball's next position and if so returns the
; obstacle's offset
;
; Input: BX=displacement of the ball
;        DX=ball's position (row,column)
; Output: AX=1 if there's a diagonal obstacle
;         SI=displacement of the obstacle
;         AX=0 if not
;------------------------------------------------
DiagObs  PROC FAR
        PUSH    DX

        MOV     AL, rowdir[DI]
        CBW
        MOV     SI, 0A0h
        IMUL    SI
        MOV     SI, AX
        MOV     AX, 02h
        IMUL    BYTE PTR coldir[DI]
        ADD     SI, AX                  ; Offset of the ball's next position
        XOR     AX, AX

        CMP     ES:[BX+SI], BYTE PTR 20h
        JE      END_DO
        MOV     AX, 01h

END_DO: POP     DX

        RET
DiagObs  ENDP


;------------------------------------------------
; Gets the new ball's position given its number
;
; Input: DI=ball to move (0-4)
; Output: AH=new row of the ball
;         AL=new column of the ball
;------------------------------------------------
NextPos1  PROC FAR
        PUSH    CX
        PUSH    DX
        PUSH    DS

        MOV     DX, _FDATA
        MOV     DS, DX

        MOV     DH, rows[DI]
        MOV     DL, columns[DI]

        MOV     CX, DX
        ADD     DH, rowdir[DI]
        ADD     DL, coldir[DI]

        CMP     DH, 0
        JB      COLLR1
        CMP     DH, 25
        JB      SIDES1
COLLR1: NEG     BYTE PTR rowdir[DI]

SIDES1: CMP     DL, 0
        JB      COLLC1
        CMP     DL, 80
        JB      UPD1
COLLC1: NEG     BYTE PTR coldir[DI]

UPD1:   MOV     AX, CX
        ADD     AH, rowdir[DI]
        ADD     AL, coldir[DI]

        POP     DS
        POP     DX
        POP     CX

        RET
NextPos1  ENDP


;------------------------------------------------
; Gets the new ball's position given its number
;
; Input: DI=ball to move (0-4)
; Output: AH=new row of the ball
;         AL=new column of the ball
;------------------------------------------------
NextPos2  PROC FAR
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     DX, _FDATA
        MOV     DS, DX
        MOV     DX, 0B800h
        MOV     ES, DX

        MOV     DH, rows[DI]
        MOV     DL, columns[DI]

        XOR     CX, CX

        MOV     AX, 01h
        MOV     BX, DX
        CALL    GetOffset

MOVVIR: CALL    VerObs                  ; Check out if there's obstacles
        CMP     AX, 00h
        JE      HOR
        NEG     BYTE PTR coldir[DI]
        MOV     CX, 01h

HOR:    CALL    HorObs
        CMP     AX, 00h
        JE      DIAG2
        NEG     BYTE PTR rowdir[DI]
        MOV     CX, 01h

DIAG2:  CMP     CX, 00h
        JA      UPD2
        CALL    DiagObs
        CMP     AX, 00h
        JE      UPD2
        NEG     BYTE PTR rowdir[DI]
        NEG     BYTE PTR coldir[DI]

UPD2:   MOV     CX, DX
        ADD     DH, rowdir[DI]
        ADD     DL, coldir[DI]
        MOV     BX, DX
        MOV     AX, 01h
        CALL    GetOffset
        CMP     ES:[BX], BYTE PTR 20h   ; If the next position isn't empty
        JE      EMPTY2                  ; don't move the ball
        MOV     AX, CX
        JMP     ENDNP2
EMPTY2: MOV     AX, DX

ENDNP2: POP     ES
        POP     DS
        POP     SI
        POP     DX
        POP     CX
        POP     BX

        RET
NextPos2  ENDP


;------------------------------------------------
; Gets the new ball's position given its number
;
; Input: DI=ball to move (0-4)
; Output: AH=new row of the ball
;         AL=new column of the ball
;------------------------------------------------
NextPos3  PROC FAR
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     BX, _FDATA
        MOV     DS, BX
        MOV     BX, 0B800h
        MOV     ES, BX

        MOV     DH, rows[DI]
        MOV     DL, columns[DI]

        CMP     DH, 24
        JB      NOTOUT
        OR      gflags, BYTE PTR 02h    ; If the ball's out update the flags
        AND     gflags, BYTE PTR 0FBh
        MOV     AX, DX
        TEST    gflags, BYTE PTR 08h    ; If the sound is enabled make
        JZ      NOSND0                  ; a specific sound
        MOV     SI, 02h
        CALL    ReboundSnd
NOSND0: JMP     ENDNP3

NOTOUT: XOR     CX, CX
        MOV     AX, 02h
        MOV     BX, DX
        CALL    GetOffset

        CALL    VerObs                  ; Check out if there's any obstacles
        CMP     AX, 00h                 ; around the ball (sides, up or
        JE      UPDWN                   ; down, paddle, screen sides)
        NEG     BYTE PTR coldir[DI]
        MOV     CX, 01h                    ; If there's a side crash,
        CMP     ES:[BX+SI], BYTE PTR 0DBh  ; there's no diagonal crash
        JNE     BLOCK1
        XOR     SI, SI
        JMP     SND1
BLOCK1: CMP     ES:[BX+SI], BYTE PTR 0Ah        ; Brick crash?
        JNE     UPDWN
        MOV     AL, ES:[BX+SI+1]
        MOV     ES:[BX+SI], BYTE PTR 20h
        MOV     ES:[BX+SI+1], BYTE PTR 07h
        CALL    UpdScore
        MOV     AX, BX
        ADD     AX, SI
        CALL    InitExtra
        MOV     SI, 03h
SND1:   TEST    gflags, BYTE PTR 08h
        JZ      UPDWN
        CALL    ReboundSnd

UPDWN:  CALL    HorObs
        CMP     AX, 00h
        JE      DIAG3
        NEG     BYTE PTR rowdir[DI]
        MOV     CX, 01h
        CMP     ES:[BX+SI], BYTE PTR 0DCh
        JNE     BLOCK2
        XOR     SI, SI
        JMP     SND2
BLOCK2: CMP     ES:[BX+SI], BYTE PTR 0Ah
        JNE     PAD1
        MOV     AL, ES:[BX+SI+1]
        MOV     ES:[BX+SI], BYTE PTR 20h
        MOV     ES:[BX+SI+1], BYTE PTR 07h
        CALL    UpdScore
        MOV     AX, BX
        ADD     AX, SI
        CALL    InitExtra
        MOV     SI, 03h
        JMP     SND2
PAD1:   CMP     ES:[BX+SI], BYTE PTR 0DFh
        JNE     DIAG3
        MOV     SI, 01h
SND2:   TEST    gflags, BYTE PTR 08h
        JZ      DIAG3
        CALL    ReboundSnd

DIAG3:  CMP     CX, 00h
        JA      UPD3
        CALL    DiagObs
        CMP     AX, 00h
        JE      UPD3
        NEG     BYTE PTR rowdir[DI]
        NEG     BYTE PTR coldir[DI]
        CMP     ES:[BX+SI], BYTE PTR 0Ah
        JNE     PAD2
        MOV     AL, ES:[BX+SI+1]
        MOV     ES:[BX+SI], BYTE PTR 20h
        MOV     ES:[BX+SI+1], BYTE PTR 07h
        CALL    UpdScore
        MOV     AX, BX
        ADD     AX, SI
        CALL    InitExtra
        MOV     SI, 03h
        JMP     SND3
PAD2:   CMP     ES:[BX+SI], BYTE PTR 0DFh
        JNE     UPD3
        MOV     SI, 01h
SND3:   TEST    gflags, BYTE PTR 08h
        JZ      UPD3
        CALL    ReboundSnd

UPD3:   MOV     CX, DX
        ADD     DH, rowdir[DI]
        ADD     DL, coldir[DI]
        MOV     BX, DX
        MOV     AX, 02h
        CALL    GetOffset
        CMP     ES:[BX], BYTE PTR 20h   ; If the next position isn't empty
        JE      EMPTY3                  ; don't move the ball
        MOV     AX, CX
        JMP     ENDNP3
EMPTY3: MOV     AX, DX

ENDNP3: POP     ES
        POP     DS
        POP     SI
        POP     DX
        POP     CX
        POP     BX

        RET
NextPos3  ENDP


;------------------------------------------------
; Moves the specified ball
;
; Input: DI
; Output: None
;------------------------------------------------
MoveVirus  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DS

        MOV     AX, _FDATA
        MOV     DS, AX

        TEST    gflags, BYTE PTR 80h
        JZ      CHKM2
        JMP     G3
CHKM2:  TEST    gflags, BYTE PTR 40h
        JNZ     G2
        TEST    gflags, BYTE PTR 20h
        JNZ     G1
        JMP     END_MV

G1:     CALL    NextPos1
        MOV     newrow[DI], AH
        MOV     newcol[DI], AL
        JMP     END_MV

G2:     CALL    NextPos2
        MOV     newrow[DI], AH
        MOV     newcol[DI], AL
        JMP     END_MV

G3:     CALL    NextPos3
        MOV     newrow[DI], AH
        MOV     newcol[DI], AL

END_MV: POP     DS
        POP     CX
        POP     BX
        POP     AX

        RET
MoveVirus  ENDP


;------------------------------------------------
; Restores and redraws the specified ball
;
; Input: DI
; Output: None
;------------------------------------------------
UpdVirus  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DS

        MOV     AX, _FDATA
        MOV     DS, AX

        TEST    gflags, BYTE PTR 80h
        JZ      CHKU2
        JMP     U3
CHKU2:  TEST    gflags, BYTE PTR 40h
        JNZ     U2
        TEST    gflags, BYTE PTR 20h
        JNZ     U1
        JMP     END_UV

U1:     MOV     AX, 01h
        MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        MOV     CH, oldch[DI]
        MOV     CL, oldattr[DI]
        CALL    Restore
        MOV     AX, 01h
        MOV     BH, newrow[DI]
        MOV     rows[DI], BH
        MOV     BL, newcol[DI]
        MOV     columns[DI], BL
        CALL    DrawVirus
        MOV     oldch[DI], BH
        MOV     oldattr[DI], BL
        JMP     END_MV

U2:     MOV     AX, 02h
        MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        MOV     CH, oldch[DI]
        MOV     CL, oldattr[DI]
        CALL    Restore
        MOV     AX, 02h
        MOV     BH, newrow[DI]
        MOV     rows[DI], BH
        MOV     BL, newcol[DI]
        MOV     columns[DI], BL
        CALL    DrawVirus
        MOV     oldch[DI], BH
        MOV     oldattr[DI], BL
        JMP     END_MV

U3:     MOV     AX, 03h
        MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        MOV     CH, oldch[DI]
        MOV     CL, oldattr[DI]
        CALL    Restore
        MOV     AX, 03h
        MOV     BH, newrow[DI]
        MOV     rows[DI], BH
        MOV     BL, newcol[DI]
        MOV     columns[DI], BL
        CALL    DrawVirus
        MOV     oldch[DI], BH
        MOV     oldattr[DI], BL

END_UV: POP     DS
        POP     CX
        POP     BX
        POP     AX

        RET
UpdVirus  ENDP



;------------------------------------------------
; Makes a game loop while the gflags says so
;
; Input: None
; Output: None
;------------------------------------------------
Mode1  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI
        PUSH    DS

        MOV     AX, _FDATA
        MOV     DS, AX

        MOV     AL, 01h
        CALL    DrawScreen

        XOR     DI, DI
DV1:    MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        CALL    DrawVirus
        MOV     oldch[DI], BH
        MOV     oldattr[DI], BL
        INC     DI
        CMP     DI, nvirus
        JB      DV1

        OR      gflags, BYTE PTR 04h

GLOOP1: TEST    gflags, BYTE PTR 01h
        JZ      NEXIT1
        JMP     END_M1
NEXIT1: TEST    gflags, BYTE PTR 10h
        JZ      GLOOP1

END_M1: XOR     DI, DI
        MOV     AL, 01h
RV1:    MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        MOV     CH, oldch[DI]
        MOV     CL, oldattr[DI]
        CALL    Restore
        INC     DI
        CMP     DI, nvirus
        JB      RV1

        POP     DS
        POP     DI
        POP     CX
        POP     BX
        POP     AX

        RET
Mode1  ENDP


;------------------------------------------------
; Makes a game loop while the gflags says so
;
; Input: None
; Output: None
;------------------------------------------------
Mode2  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    DS

        MOV     AX, _FDATA
        MOV     DS, AX

        MOV     AL, 02h
        CALL    DrawScreen

        XOR     DI, DI
DV2:    MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        CALL    DrawVirus
        MOV     oldch[DI], BH
        MOV     oldattr[DI], BL
        INC     DI
        CMP     DI, nvirus
        JB      DV2

        OR      gflags, BYTE PTR 04h

GLOOP2: TEST    gflags, BYTE PTR 01h
        JZ      NEXIT2
        JMP     END_M2
NEXIT2: TEST    gflags, BYTE PTR 10h
        JZ      GLOOP2

END_M2: XOR     DI, DI
        MOV     AL, 02h
RV2:    MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        MOV     CH, oldch[DI]
        MOV     CL, oldattr[DI]
        CALL    Restore
        INC     DI
        CMP     DI, nvirus
        JB      RV2

        POP     DS
        POP     DI
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
Mode2  ENDP


;------------------------------------------------
; Makes a game loop while the gflags says so
;
; Input: None
; Output: None
;------------------------------------------------
Mode3  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    DS

        MOV     AX, _FDATA
        MOV     DS, AX

        CALL    Init_vr
        MOV     frlifes, BYTE PTR 05h
        MOV     frpoints, WORD PTR 00h

        MOV     AL, 03h
        CALL    DrawScreen
        MOV     AL, frlifes
        CALL    DrawLifes
        MOV     AX, frpoints
        CALL    DrawScore
        CALL    InitPad

        XOR     DI, DI
        CALL    GetInitPos
        MOV     rows[DI], AH
        MOV     columns[DI], AL
        MOV     BX, AX
        MOV     AL, 03h
        CALL    DrawVirus
        MOV     oldch[DI], BH
        MOV     oldattr[DI], BL
        CALL    RandomDir
        MOV     rowdir[DI], AH
        MOV     coldir[DI], AL

        OR      gflags, BYTE PTR 04h

GLOOP3: TEST    gflags, BYTE PTR 01h
        JZ      NEXIT3
        JMP     END_M3
NEXIT3: TEST    gflags, BYTE PTR 10h
        JZ      NOCHG3
        JMP     END_M3
NOCHG3: TEST    gflags, BYTE PTR 02h
        JZ      GLOOP3

B_OUT:  AND     gflags, BYTE PTR 0FDh
        CMP     frlifes, 01h
        JA      DEC_L
        JMP     NLIFE
DEC_L:  DEC     BYTE PTR frlifes
        MOV     AL, frlifes
        CALL    DrawLifes

        XOR     DI, DI
        MOV     AL, 03h
        MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        MOV     CH, oldch[DI]
        MOV     CL, oldattr[DI]
        CALL    Restore
        CALL    InitPad

        MOV     BH, 12
        MOV     BL, 75
        CALL    RandomPos
        ADD     BH, 0Ah
        ADD     BL, 02h
        MOV     rows[DI], BH
        MOV     columns[DI], BL
        CALL    RandomDir
        MOV     rowdir[DI], AH
        MOV     coldir[DI], AL

        MOV     AL, 03h
        MOV     BH, rows[DI]
        MOV     BL, columns[DI]
        CALL    DrawVirus
        MOV     oldch[DI], BH
        MOV     oldattr[DI], BL
        OR      gflags, BYTE PTR 04h
        JMP     GLOOP3

NLIFE:  AND     gflags, BYTE PTR 7Fh
        OR      gflags, BYTE PTR 30h

END_M3: POP     DS
        POP     DI
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
Mode3  ENDP


;------------------------------------------------


MAIN:   MOV     AX, _FDATA
        MOV     DS, AX

        CALL    GetParam
        CMP     AL, '?'
        JNE     GO
        CALL    Help
        JMP     END_MAIN

GO:     MOV     nvirus, AX

        MOV     AX, 0300h
        XOR     BX, BX
        INT     10h
        MOV     cursorpos, DX

        CALL    StartScreen

        CALL    Init_pr

        CALL    InstallMyKeyb
        CALL    InstallMyTimer
        CALL    InstallMyIRQ7Int

GAME:   TEST    gflags, BYTE PTR 01h
        JNZ     GEXIT
        AND     gflags, BYTE PTR 0EFh
        TEST    gflags, BYTE PTR 80h
        JNZ     M3
        TEST    gflags, BYTE PTR 40h
        JNZ     M2
        TEST    gflags, BYTE PTR 20h
        JNZ     M1
        JMP     GEXIT

M1:     CALL    Mode1
        JMP     GAME
M2:     CALL    Mode2
        JMP     GAME
M3:     CALL    Mode3
        JMP     GAME

GEXIT:  MOV     AX, 0500h
        INT     10h

        MOV     AX, 0200h
        XOR     BX, BX
        MOV     DX, cursorpos
        INT     10h

        CALL    RestoreIRQ7Int
        CALL    RestoreKeyb
        CALL    RestoreTimer

END_MAIN:
        MOV     AX, 4C00h
        INT     21h

_FCODE  ENDS
        END  MAIN


;------------------------------------------------
