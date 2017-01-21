
;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
;
; This module does anything that has something
; to do with drawing stuff in the screen. It
; draws the screens of each of the 3 modes, the
; balls and the paddle
;
;------------------------------------------------


;------------------------------------------------


        PUBLIC  StartScreen
        PUBLIC  DrawScreen
        PUBLIC  DrawVirus
        PUBLIC  Restore
        PUBLIC  GetOffset
        PUBLIC  DrawPad
        PUBLIC  RestorePad
        PUBLIC  DrawScore
        PUBLIC  DrawLifes


;------------------------------------------------


_SCDATA SEGMENT

menu1   DB  20h,07h, 0Eh,0Fh, 20h,07h, 20h,07h, 20h,07h, 20h,07h, 20h,07h
        DB  20h,9Fh, 'F',9Fh, '1',9Fh, ':',9Fh, 20h,9Fh, 'T',9Fh, 'R',9Fh
        DB  'A',9Fh, 'N',9Fh, 'S',9Fh, 20h,9Fh, 20h,07h, 20h,07h, 'F',02h
        DB  '2',02h, ':',02h, 20h,07h, 'R',02h, 'E',02h, 'B',02h, 'O',02h
        DB  'T',02h, 'E',02h, 20h,07h, 20h,07h, 20h,07h, 'F',04h, '3',04h
        DB  ':',04h, 20h,07h, 'F',04h, 'R',04h, 'O',04h, 'N',04h, 'T',04h
        DB  'O',04h, 'N',04h, 20h,07h

menu2   DB  20h,07h, 0Eh,0Fh, 20h,07h, 20h,07h, 20h,07h, 20h,07h, 20h,07h
        DB  20h,07h, 'F',01h, '1',01h, ':',01h, 20h,07h, 'T',01h, 'R',01h
        DB  'A',01h, 'N',01h, 'S',01h, 20h,07h, 20h,07h, 20h,2Fh, 'F',0AFh
        DB  '2',0AFh, ':',0AFh, 20h,0AFh, 'R',0AFh, 'E',0AFh, 'B',0AFh, 'O',0AFh
        DB  'T',0AFh, 'E',0AFh, 20h,2Fh, 20h,07h, 20h,07h, 'F',04h, '3',04h
        DB  ':',04h, 20h,07h, 'F',04h, 'R',04h, 'O',04h, 'N',04h, 'T',04h
        DB  'O',04h, 'N',04h, 20h,07h

menu3   DB  20h,07h, 0Eh,0Fh, 20h,07h, 20h,07h, 20h,07h, 20h,07h, 20h,07h
        DB  20h,07h, 'F',01h, '1',01h, ':',01h, 20h,07h, 'T',01h, 'R',01h
        DB  'A',01h, 'N',01h, 'S',01h, 20h,07h, 20h,07h, 20h,07h, 'F',02h
        DB  '2',02h, ':',02h, 20h,07h, 'R',02h, 'E',02h, 'B',02h, 'O',02h
        DB  'T',02h, 'E',02h, 20h,07h, 20h,07h, 20h,4Fh, 'F',0CFh, '3',0CFh
        DB  ':',0CFh, 20h,4Fh, 'F',0CFh, 'R',0CFh, 'O',0CFh, 'N',0CFh, 'T',0CFh
        DB  'O',0CFh, 'N',0CFh, 20h,4Fh

lifes   DB  'L',0Fh, 'I',0Fh, 'F',0Fh, 'E',0Fh, 'S',0Fh, ':',0Fh

points  DB  'P',0Fh, 'O',0Fh, 'I',0Fh, 'N',0Fh, 'T',0Fh, 'S',0Fh, ':',0Fh

_SCDATA ENDS


;------------------------------------------------


_SCCODE SEGMENT
        ASSUME  CS:_SCCODE,  DS:_SCDATA


;------------------------------------------------
; Saves the original screen so we can
; restore it later
;
; Input: None
; Output: None
;------------------------------------------------
StartScreen  PROC FAR
        PUSH    CX
        PUSH    DI
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     DI, 0B800h
        MOV     DS, DI
        MOV     ES, DI
        MOV     DI, 1000h
        XOR     SI, SI
        MOV     CX, 7FFh
        CLD
        REP     MOVSW

        POP     ES
        POP     DS
        POP     SI
        POP     DI
        POP     CX

        RET
StartScreen  ENDP


;------------------------------------------------
; Draws the scoreboard
;
; Input: AX=points
; Output: None
;------------------------------------------------
DrawScore  PROC FAR
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DI
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     BX, _SCDATA
        MOV     DS, BX
        MOV     BX, 0B800h
        MOV     ES, BX
        LEA     SI, points
        MOV     DI, 2080h
        MOV     CX, 0Eh
        REP     MOVSB

        MOV     BX, 10000
        XOR     DX, DX
        DIV     BX
        ADD     AL, '0'
        MOV     ES:[2090h], AL
        MOV     ES:[2091h], BYTE PTR 0Fh

        MOV     AX, DX
        MOV     BX, 1000
        XOR     DX, DX
        DIV     BX
        ADD     AL, '0'
        MOV     ES:[2092h], AL
        MOV     ES:[2093h], BYTE PTR 0Fh

        MOV     AX, DX
        MOV     BX, 100
        XOR     DX, DX
        DIV     BX
        ADD     AX, '0'
        MOV     ES:[2094h], AL
        MOV     ES:[2095h], BYTE PTR 0Fh

        MOV     AX, DX
        MOV     BX, 10
        XOR     DX, DX
        DIV     BX
        ADD     AL, '0'
        MOV     ES:[2096h], AL
        MOV     ES:[2097h], BYTE PTR 0Fh

        ADD     DL, '0'
        MOV     ES:[2098h], DL
        MOV     ES:[2099h], BYTE PTR 0Fh

        POP     ES
        POP     DS
        POP     SI
        POP     DI
        POP     DX
        POP     CX
        POP     BX

        RET
DrawScore  ENDP


;------------------------------------------------
; Draws the lifes's number in the screen
;
; Input: AL=lifes
; Output: None
;------------------------------------------------
DrawLifes  PROC FAR
        PUSH    BX
        PUSH    DI
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     BX, 0B800h
        MOV     ES, BX
        MOV     BX, _SCDATA
        MOV     DS, BX
        LEA     SI, lifes
        MOV     DI, 2066h
        MOV     CX, 0Ch
        REP     MOVSB

        ADD     AL, '0'
        MOV     ES:[2076h], AL
        MOV     ES:[2077h], BYTE PTR 0Fh

        POP     ES
        POP     DS
        POP     SI
        POP     DI
        POP     BX

        RET
DrawLifes  ENDP


;------------------------------------------------
; Given a video page and a position returns
; the memory offset
;
; Input: AX=active video page
;        BH=row
;        BL=column
; Output:BX=corresponding memory displacement
;------------------------------------------------
GetOffset  PROC FAR
        PUSH    AX
        PUSH    DX

        MOV     DX, 1000h
        MUL     DX
        MOV     DX, AX
        MOV     AX, 0A0h
        MUL     BH
        ADD     DX, AX
        XOR     BH, BH
        SHL     BL, 01h
        ADD     DX, BX
        MOV     BX, DX

        POP     DX
        POP     AX

        RET
GetOffset  ENDP


;------------------------------------------------
; Draws the walls in the third game mode
;
; Input: ES=video memory segment
; Output: None
;------------------------------------------------
DrawWalls  PROC FAR

        MOV     BX, 20A0h
        MOV     CX, 79
        XOR     SI, SI
LP1:    MOV     DI, SI
        SHL     DI, 01h
        MOV     ES:[BX+DI], BYTE PTR 0DCh
        MOV     ES:[BX+DI+1], BYTE PTR 04h
        INC     SI
        CMP     SI, 80
        JB      LP1

        XOR     SI, SI
        XOR     DI, DI
        MOV     BX, 2140h
LP2:    MOV     ES:[BX+DI], BYTE PTR 0DBh
        MOV     ES:[BX+DI+1], BYTE PTR 04h
        MOV     ES:[BX+DI+9Eh], BYTE PTR 0DBh
        MOV     ES:[BX+DI+9Fh], BYTE PTR 04h
        ADD     DI, 0A0h
        INC     SI
        CMP     SI, 23
        JB      LP2

        RET
DrawWalls  ENDP


;------------------------------------------------
; Draws all the bricks in the screen
;
; Input: ES=Video memory segment
; Output: None
;------------------------------------------------
DrawBlocks  PROC FAR

        MOV     BX, 2286h

        MOV     AX, 05h
LP3:    XOR     SI, SI
LP4:    MOV     DI, SI
        SHL     DI, 01h
        MOV     ES:[BX+DI], BYTE PTR 0Ah
        MOV     ES:[BX+DI+1], AL
        INC     SI
        CMP     SI, 74
        JB      LP4
        DEC     AX
        ADD     BX, 0A0h
        CMP     AX, 00h
        JA      LP3

        RET
DrawBlocks  ENDP


;------------------------------------------------
; Draws the screen corresponding to the
; current game mode
;
; Input: AL=game mode
; Output: None
;------------------------------------------------
DrawScreen  PROC FAR
        PUSH    AX
        PUSH    CX
        PUSH    DI
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     CX, _SCDATA
        MOV     DS, CX
        MOV     CX, 0B800h
        MOV     ES, CX
        MOV     CX, 90

        CMP     AL, 03h
        JE      MODE3
        CMP     AL, 02h
        JE      MODE2

MODE1:  MOV     DI, 1000h
        LEA     SI, menu1
        CLD
        REP     MOVSB

        MOV     DH, 25
        XOR     DL, DL
        MOV     BH, 01h
        MOV     AX, 0200h
        INT     10h

        MOV     AX, 0501h
        INT     10h

        JMP     DONE

MODE2:  MOV     DI, 1000h
        LEA     SI, menu2
        CLD
        REP     MOVSB

        MOV     DH, 25
        XOR     DL, DL
        MOV     BH, 01h
        MOV     AX, 0200h
        INT     10h

        MOV     AX, 0501h
        INT     10h

        JMP     DONE

MODE3:  PUSH    BX
        PUSH    DX

        MOV     AX, 0502h
        INT     10h

        MOV     AX, 0700h
        MOV     CX, 00h
        MOV     DX, 184Fh
        MOV     BH, 07h
        INT     10h

        MOV     CX, 90
        MOV     DI, 2000h
        LEA     SI, menu3
        CLD
        REP     MOVSB

        MOV     DH, 25
        XOR     DL, DL
        MOV     BH, 02h
        MOV     AX, 0200h
        INT     10h

        CALL    DrawWalls
        CALL    DrawBlocks

        POP     DX
        POP     BX

DONE:   POP     ES
        POP     DS
        POP     SI
        POP     DI
        POP     CX
        POP     AX

        RET
DrawScreen  ENDP


;------------------------------------------------
; Draws a ball in the screen and save the
; original character and attribute
;
; Input: AL=game mode
;        BX=ball's position (row,column)
;        DI=ordinal of the ball to be drawn
; Output: BH=original character
;         BL=original attribute
;------------------------------------------------
DrawVirus  PROC FAR
        PUSH    AX
        PUSH    DX
        PUSH    ES

        MOV     DX, 01h
        
        CMP     AL, 03h
        JB      DRAW
        INC     DX

DRAW:   MOV     AX, DX
        CALL    GetOffset

        MOV     AX, 0B800h
        MOV     ES, AX

        MOV     DH, ES:[BX]
        MOV     DL, ES:[BX+1]

        MOV     AX, DI
        INC     AX
        MOV     ES:[BX], BYTE PTR 01h
        MOV     ES:[BX+1], AL

        MOV     BX, DX
        CMP     BH, 01h
        JNE     END_DV
        MOV     BH, 20h

END_DV: POP     ES
        POP     DX
        POP     AX

        RET
DrawVirus  ENDP


;------------------------------------------------
; Restore the original character and attribute
; that was in the screen when the ball was drawn
;
; Input: AL=game mode
;        BX=ball's position (row,column)
;        CH=original character
;        CL=original attribute
; Output: None
;------------------------------------------------
Restore  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DX
        PUSH    ES

        MOV     DX, 01h
        
        CMP     AL, 03h
        JB      RESTOR
        INC     DX

RESTOR: MOV     AX, DX
        CALL    GetOffset

        MOV     AX, 0B800h
        MOV     ES, AX

        MOV     ES:[BX], CH
        MOV     ES:[BX+1], CL

        POP     ES
        POP     DX
        POP     BX
        POP     AX

        RET
Restore  ENDP


;------------------------------------------------
; Draws the paddle in the screen
;
; Input: AH=paddle's position
;        AL=paddle's length
; Output: None
;------------------------------------------------
DrawPad  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI
        PUSH    SI
        PUSH    ES

        MOV     BX, 0B800h
        MOV     ES, BX

        XOR     CH, CH
        MOV     CL, AL

        MOV     BL, AH
        MOV     BH, 24
        MOV     AX, 02h
        CALL    GetOffset

        XOR     SI, SI
AGAIN:  MOV     DI, SI
        SHL     DI, 01h
        MOV     ES:[BX+DI], BYTE PTR 0DFh
        MOV     ES:[BX+DI+1], BYTE PTR 06h
        INC     SI
        CMP     SI, CX
        JB      AGAIN

        POP     ES
        POP     SI
        POP     DI
        POP     CX
        POP     BX
        POP     AX
        RET
DrawPad  ENDP


;------------------------------------------------
; Deletes the paddle from the screen
;
; Input: AH=paddle's position
;        AL=paddle's length
; Output: None
;------------------------------------------------
RestorePad  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI
        PUSH    SI
        PUSH    ES

        MOV     BX, 0B800h
        MOV     ES, BX

        XOR     CH, CH
        MOV     CL, AL

        MOV     BL, AH
        MOV     BH, 24
        MOV     AX, 02h
        CALL    GetOffset

        XOR     SI, SI
NOTYET: MOV     DI, SI
        SHL     DI, 01h
        MOV     ES:[BX+DI], BYTE PTR 20h
        MOV     ES:[BX+DI+1], BYTE PTR 07h
        INC     SI
        CMP     SI, CX
        JB      NOTYET

        POP     ES
        POP     SI
        POP     DI
        POP     CX
        POP     BX
        POP     AX

        RET
RestorePad  ENDP


_SCCODE ENDS
        END


;------------------------------------------------
