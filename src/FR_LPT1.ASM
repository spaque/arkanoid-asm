
;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
;
; The LPT1 module's got the LPT1 related
; procedures. Its handler make the program
; finish off.
;
;------------------------------------------------


;------------------------------------------------


        PUBLIC  LPT1

        EXTRN   gflags:BYTE


;------------------------------------------------


_PDATA  SEGMENT

oldoff  DW  ?
oldseg  DW  ?

_PDATA  ENDS


;------------------------------------------------


_PCODE  SEGMENT
        ASSUME  CS:_PCODE, DS:_PDATA


;------------------------------------------------
; LPT1 handler. When activated finish the game
;
; Input: None
; Output: None
;------------------------------------------------
LPT1  PROC FAR
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
LPT1  ENDP


_PCODE  ENDS
        END


;------------------------------------------------
