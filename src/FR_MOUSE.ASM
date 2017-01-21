
;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
;
; The mouse module just request the ball's
; initial position in the 3rd mode to let
; the program carry on
;
;------------------------------------------------


;------------------------------------------------


        PUBLIC  GetInitPos

        EXTRN   Delay:FAR


;------------------------------------------------


_MSCODE SEGMENT
        ASSUME  CS:_MSCODE

;------------------------------------------------
; Get the ball's initial position when we're
; in the third game mode. If there's no mouse
; driver returns a default position
;
; Input: None
; Output: AH=new ball's row
;         AL=new ball's column
;------------------------------------------------
GetInitPos  PROC FAR
        PUSH    BX
        PUSH    CX
        PUSH    DX

        MOV     AX, 00h
        INT     33h
        CMP     AX, 00h
        JNE     INIT
        MOV     AX, 0C26h
        JMP     DONE

INIT:   MOV     AX, 07h
        MOV     CX, 10h
        MOV     DX, 268h
        INT     33h

        MOV     AX, 08h
        MOV     CX, 50h
        MOV     DX, 0B0h
        INT     33h

        MOV     AX, 01h
        INT     33h

POLLIN: MOV     AX, 05h
        MOV     BX, 00h
        INT     33h
        CMP     BX, 02h
        JAE     UPDPOS
        CMP     BX, 01h
        JE      DEL
        JMP     POLLIN

DEL:    MOV     AX, 440
        CALL    Delay
        MOV     AX, 05h
        MOV     BX, 00h
        INT     33h
        CMP     BX, 01h
        JB      POLLIN

UPDPOS: MOV     AX, 02h
        INT     33h

        SHR     DX, 01h
        SHR     DX, 01h
        SHR     DX, 01h
        MOV     AH, DL
        SHR     CX, 01h
        SHR     CX, 01h
        SHR     CX, 01h
        MOV     AL, CL

DONE:   POP     DX
        POP     CX
        POP     BX

        RET
GetInitPos  ENDP

_MSCODE ENDS
        END


;------------------------------------------------
