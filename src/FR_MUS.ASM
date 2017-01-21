
;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
;
; This module's entrusted with the background
; music. Load the music file dinamically on
; memory and programs the DMA to do memory
; transfers towards the SoundBlaster. When the
; DMA finish the transfer it causes an interrupt
; in which it gotta be reprogrammed. To do that
; we use the "double buffering" technique: while
; the DMA's transfering a buffer we update
; the other one in order to improve the music
; quality.
;
;------------------------------------------------


;------------------------------------------------
        include retardo.asm

        PUBLIC  StartPlaying
        PUBLIC  StopPlaying
        PUBLIC  UpdateBuffer
        PUBLIC  SpeakerOff


        EXTRN   Delay:FAR


;------------------------------------------------
_stack  segment stack
        db 200h dup (?)
_stack  ends

_SDATA  SEGMENT

OldDMASeg  DW  ?
OldDMAOff  DW  ?

BaseAddress  DW  220h
IRQNumber    DB  07h
DMAChannel   DB  01h

BufferSeg      DW  ?
BufferOffset1  DW  ?
BufferOffset2  DW  ?
Buffer1Size    DW  4096
Buffer2Size    DW  4096

MoreBuffer  DB  02h  DUP  (0)
Pages       DB  04h  DUP  (0)
Lengths     DW  04h  DUP  (0)
Offsets     DW  04h  DUP  (0)

CurBuffer   DB  01h
Status      DB  00h

PatternSeg    DW  0
SampleSeg     DW  32  DUP  (0)

;ModName       DB  'REBIRTH.MOD',0,'$'
ModName       DB  'PRELUDI.MOD',0,'$'

ModTitle      DB  20  DUP  (0)

SampleNames   DB  32*22 DUP (0)
SampleLengths DW  32  DUP  (0)
Volume        DW  32  DUP  (0)
LoopStart     DW  32  DUP  (0)
LoopLength    DW  32  DUP  (0)

AuxBuffer     DB  32  DUP  (0)

NumPatterns   DB  0

NumSequences  DB  0
Restart       DB  0
Sequences     DB  128  DUP  (0)

DMABuffer1    DB  4096  DUP  (80h)
DMABuffer2    DB  4096  DUP  (80h)

CurByte       DW  04h  DUP  (0)       ; Data for each of the 4 tracks
CurSeg        DW  04h  DUP  (0)
CurTrack      DW  04h  DUP  (0)
CurLeng       DW  04h  DUP  (0)
Special       DW  04h  DUP  (0)
CurLoopLeng   DW  04h  DUP  (0)
CurStartLoop  DW  04h  DUP  (0)

WaitForFreq   DW  00h
TempFreq      DW  04h  DUP  (100h)
Freq          DW  04h  DUP  (100h)

CurVolume     DB  12  DUP  (64)

CurOffset     DW  OFFSET  DMABuffer1
NotCurOffset  DW  OFFSET  DMABuffer2
CurBuffSize   DW  0

CurPattern    DW  0
CurNote       DW  0
CurSequence   DW  0

FreqWait      DW  302h
SampleRate    DB  0D3h
NewBufferSize DW  0A1Fh
Count         DW  0A5AEh

FileHandle    DW  ?

_SDATA  ENDS


;----------------------------------------------------------


_SCODE SEGMENT
        ASSUME  CS:_SCODE, DS:_SDATA


;------------------------------------------------
;
; Input: None
; Output: CF=0 successful
;         CF=1 unsuccessful
;------------------------------------------------
DSPReset  PROC  FAR

        PUSH    AX
        PUSH    CX
        PUSH    DX
        PUSH    DS

        MOV     AX, _SDATA
        MOV     DS, AX

        MOV     DX, BaseAddress         ; SB base I/O address
        ADD     DX, 06h                 ; Reset port, 2x6h

        MOV     AL, 01h
        OUT     DX, AL                  ; Write a 1 to the DSP reset port

;        MOV     AX, 01h
;        CALL    Delay                   ; Wait for a milisecond
retarat 1
        XOR     AL, AL
        OUT     DX, AL

        MOV     CX, 0FFFFh              ; Maximum 65536 tries
EMPTY:  MOV     DX, BaseAddress
        ADD     DX, 0Eh                 ; Read-Buffer Status port, 2xEh

        IN      AL, DX
        OR      AL, AL                  ; Data available?
        JNS     NEXTATTEMPT             ; Bit 7 clear, try again

        SUB     DX, 04h                 ; Read Data port, 2xAh
        IN      AL, DX
        CMP     AL, 0AAh                ; Received success code, AAh?
        JE      RESETOK

NEXTATTEMPT:
        LOOP    EMPTY                   ; Try again

        STC                             ; Sound Blaster not detected
        JMP     ENDDSPR

RESETOK:
        CLC

ENDDSPR:
        POP     DS
        POP     DX
        POP     CX
        POP     AX
        RET
DSPReset  ENDP


;------------------------------------------------
;
; Input: AL=Value to be written to the DSP
; Output: None
;------------------------------------------------
DSPWrite  PROC  FAR
        PUSH    DX
        PUSH    DS
        PUSH    AX

        MOV     AX, _SDATA
        MOV     DS, AX

        MOV     DX, BaseAddress
        ADD     DX, 0Ch                 ; Write-Buffer Status port, 2xCh

BUSY:   IN      AL, DX                  ; Read Write-Buffer Status port
        OR      AL, AL                  ; Can write to DSP?
        JS      BUSY                    ; Bit 7 set, try again

        POP     AX
        OUT     DX, AL
        POP     DS
        POP     DX

        RET
DSPWrite  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
SpeakerOn  PROC  FAR
        PUSH    AX

        MOV     AL, 0D1h
        CALL    DSPWrite

        POP     AX

        RET
SpeakerOn  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
SpeakerOff  PROC  FAR
        PUSH    AX

        MOV     AL, 0D3h
        CALL    DSPWrite

        POP     AX

        RET
SpeakerOff  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
DMAContinue  PROC  FAR
        PUSH    AX

        MOV     AL, 0D4h
        CALL    DSPWrite

        POP     AX

        RET
DMAContinue  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
DMAStop  PROC  FAR
        PUSH    AX

        MOV     AL, 0D0h
        CALL    DSPWrite

        POP     AX

        RET
DMAStop  ENDP


;------------------------------------------------
;
; Input: AH=Time Constant = 256 - 1000000 / frequency
; Output: None
;------------------------------------------------
SetTimeConstant  PROC  FAR
        PUSH    AX

        MOV     AL, 40h
        CALL    DSPWrite
        MOV     AL, AH
        CALL    DSPWrite

        POP     AX

        RET
SetTimeConstant  ENDP


;------------------------------------------------
;
; Input: AX=Segment of the memory buffer
;        DX=Offset of the memory buffer
; Output: AH=Page (bits 16-19 of the 20 bits address)
;         DX=Offset (bits 0-15 of the 20 bits address)
;         CX=Maximun length of the buffer
;------------------------------------------------
GetBufferAdd  PROC  FAR
        PUSH    BX

        MOV     CX, 04h
        MOV     BL, AH
        SHR     BL, CL

        SHL     AX, CL
        ADD     AX, DX
        ADC     BL, 00h

        MOV     AH, BL
        MOV     CX, DX
        NEG     CX

        POP     BX

        RET
GetBufferAdd  ENDP

;------------------------------------------------
;
; Input: AH=Page
;        DX=Address
;        CX=Data Length-1
; Output: None
;------------------------------------------------
TransferDMA  PROC  FAR
        PUSH    AX

        MOV     AL, 05h
        OUT     0Ah, AL         ; Mask off DMA channel 1

        XOR     AL, AL
        OUT     0Ch, AL         ; Clear the internal DMA flip/flop

        MOV     AL, 49h
        OUT     0Bh, AL         ; Set transfer mode to DAC

        MOV     AL, DL
        OUT     02h, AL         ; LSB of the memory address
        MOV     AL, DH
        OUT     02h, AL         ; MSB of the memory address

        MOV     AL, AH
        OUT     83h, AL         ; Page of the memory address

        MOV     AL, CL
        OUT     03h, AL         ; LSB of Data Length
        MOV     AL, CH
        OUT     03h, AL         ; MSB of Data Length

        MOV     AL, 01h
        OUT     0Ah, AL         ; Enable DMA channel 1

        MOV     AL, 14h         ; Write DMA Type Value to DSP
        CALL    DSPWrite

        MOV     AL, CL          ; LSB of Data Length to DSP
        CALL    DSPWrite
        MOV     AL, CH          ; MSB of Data Length to DSP
        CALL    DSPWrite

        POP     AX

        RET
TransferDMA  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
InstallMyDMA  PROC FAR
        PUSH    AX
        PUSH    CX
        PUSH    DS
        PUSH    ES

        MOV     AX, _SDATA
        MOV     DS, AX
        XOR     AX, AX
        MOV     ES, AX

        MOV     AL, IRQNumber
        ADD     AL, 08h
        SHL     AL, 01h
        SHL     AL, 01h
        MOV     BX, AX

        MOV     AX, ES:[BX]
        MOV     OldDMAOff, AX
        MOV     AX, ES:[BX+02h]
        MOV     OldDMASeg, AX

        CLI
        MOV     ES:[BX], OFFSET DMAInt
        MOV     WORD PTR ES:[BX+2], SEG DMAInt
        XOR     CX, CX
        MOV     CL, IRQNumber
        MOV     AH, 01h
        SHL     AH, CL
        NOT     AH
        IN      AL, 21h
        AND     AL, AH
        OUT     21h, AL
        STI

        MOV     AH, Pages[00h]
        MOV     CX, Lengths[00h]
        MOV     DX, Offsets[00h]
        CALL    TransferDMA

        POP     ES
        POP     DS
        POP     CX
        POP     AX

        RET
InstallMyDMA  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
RestoreDMA  PROC FAR
        PUSH    AX
        PUSH    CX
        PUSH    DS
        PUSH    ES

        MOV     AX, _SDATA
        MOV     DS, AX
        XOR     AX, AX
        MOV     ES, AX

        MOV     AL, IRQNumber
        ADD     AL, 08h
        SHL     AL, 01h
        SHL     AL, 01h
        MOV     BX, AX

        CLI
        MOV     AX, OldDMAOff
        MOV     ES:[BX], AX
        MOV     AX, OldDMASeg
        MOV     ES:[BX+02h], AX
        XOR     CX, CX
        MOV     AH, 01h
        MOV     CL, IRQNumber
        SHL     AH, CL
        IN      AL, 21h
        OR      AL, AH
        OUT     21h, AL
        STI

        POP     ES
        POP     DS
        POP     CX
        POP     AX

        RET
RestoreDMA  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
DMAInt  PROC FAR
        PUSH    AX
        PUSH    CX
        PUSH    DX
        PUSH    DS

        MOV     AX, _SDATA
        MOV     DS, AX

        MOV     DX, BaseAddress
        ADD     DX, 0Eh
        IN      AL, DX                  ; Acknowlegde interrupt

        MOV     AL, CurBuffer
        CMP     AL, 04h
        JNE     SETBF1
CHK3:   CMP     AL, 03h
        JNE     CHK2
        JMP     BUFF3
CHK2:   CMP     AL, 02h
        JNE     CHK1
        JMP     SETBF3
CHK1:   CMP     AL, 01h
        JE      BUFF1

        CALL    DMAStop
        JMP     ENDDMA

BUFF1:  MOV     Status, 03h
        CMP     MoreBuffer[00h], 00h
        JNE     SETBF2
        JMP     SETBF3

BUFF3:  MOV     Status, 04h
        CMP     MoreBuffer[01h], 00h
        JNE     SETBF4
;        JMP     SETBF1

SETBF1: MOV     AH, Pages[00h]
        MOV     CX, Lengths[00h]
        MOV     DX, Offsets[00h]
        CALL    TransferDMA
        MOV     CurBuffer, 01h
        JMP     ENDDMA

SETBF2: MOV     AH, Pages[01h]
        MOV     CX, Lengths[02h]
        MOV     DX, Offsets[02h]
        CALL    TransferDMA
        MOV     CurBuffer, 02h
        JMP     ENDDMA

SETBF3: MOV     AH, Pages[02h]
        MOV     CX, Lengths[04h]
        MOV     DX, Offsets[04h]
        CALL    TransferDMA
        MOV     CurBuffer, 03h
        JMP     ENDDMA

SETBF4: MOV     AH, Pages[03h]
        MOV     CX, Lengths[06h]
        MOV     DX, Offsets[06h]
        CALL    TransferDMA
        MOV     CurBuffer, 04h
        
ENDDMA: MOV     AL, 20h
        OUT     20h, AL

        POP     DS
        POP     DX
        POP     CX
        POP     AX

        IRET
DMAInt  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
SetDMABuffer  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DS

        MOV     AX, _SDATA
        MOV     DS, AX

        CLI
        MOV     MoreBuffer[00h], 00h
        MOV     AX, DS
        MOV     DX, BufferOffset1
        CALL    GetBufferAdd

        CMP     CX, Buffer1Size
        JAE     NOMOREBUF1

        MOV     MoreBuffer[00h], 01h
        MOV     BX, Buffer1Size
        SUB     BX, CX
        DEC     BX
        MOV     Lengths[02h], BX
        MOV     Offsets[02h], 00h
        MOV     Pages[01h], AH
        INC     Pages[01h]

NOMOREBUF1:
        MOV     CX, Buffer1Size
        DEC     CX
        MOV     Pages[00h], AH
        MOV     Lengths[00h], CX
        MOV     Offsets[00h], DX

        MOV     MoreBuffer[01h], 00h
        MOV     AX, DS
        MOV     DX, BufferOffset2
        CALL    GetBufferAdd

        CMP     CX, Buffer2Size
        JAE     NOMOREBUF2

        MOV     MoreBuffer[01h], 01h
        MOV     BX, Buffer2Size
        SUB     BX, CX
        DEC     BX
        MOV     Lengths[06h], BX
        MOV     Offsets[06h], 00h
        MOV     Pages[03h], AH
        INC     Pages[03h]

NOMOREBUF2:
        MOV     CX, Buffer2Size
        DEC     CX
        MOV     Pages[02h], AH
        MOV     Lengths[04h], CX
        MOV     Offsets[04h], DX
        STI

        POP     DS
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
SetDMABuffer  ENDP


;------------------------------------------------


;------------------------------------------------
;
;
;
;
;------------------------------------------------
LoadMOD  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    BP
        PUSH    DI
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     AX, _SDATA
        MOV     DS, AX
        MOV     ES, AX

        MOV     DX, OFFSET ModName
        MOV     AX, 3D00h
        INT     21h
        JNC     OPENOK
        JMP     END_ML

OPENOK: MOV     BX, AX
        MOV     FileHandle, AX
        MOV     DX, OFFSET ModTitle
        MOV     CX, 14h
        MOV     AX, 3F00h
        INT     21h

        XOR     BP, BP
SAMPLELOOP:
        MOV     DX, OFFSET AuxBuffer
        MOV     CX, 1Eh
        MOV     AX, 3F00h
        INT     21h

        MOV     SI, OFFSET AuxBuffer
        MOV     AX, BP
        MOV     CX, 22
        MUL     CL
        MOV     DI, AX
        ADD     DI, OFFSET SampleNames
        REP     MOVSB

        MOV     DI, BP
        SHL     DI, 01h
        ADD     DI, OFFSET SampleLengths
        LODSB
        MOV     AH, AL
        LODSB
        SHL     AX, 01h
        STOSW

        MOV     DI, BP
        SHL     DI, 01h
        ADD     DI, OFFSET Volume
        LODSB
        MOV     AH, AL
        LODSB
        STOSW

        MOV     DI, BP
        SHL     DI, 01h
        ADD     DI, OFFSET LoopStart
        LODSB
        MOV     AH, AL
        LODSB
        SHL     AX, 01h
        STOSW

        MOV     DI, BP
        SHL     DI, 01h
        ADD     DI, OFFSET LoopLength
        LODSB
        MOV     AH, AL
        LODSB
        SHL     AX, 01h
        STOSW

        INC     BP
        CMP     BP, 31
        JB      SAMPLELOOP

        MOV     DX, OFFSET NumSequences
        MOV     CX, 130
        MOV     AX, 3F00h
        INT     21h

        XOR     CX, CX
        MOV     DX, 43Ch
        MOV     AX, 4200h
        INT     21h

        MOV     SI, OFFSET Sequences
        XOR     CX, CX
FINDBIGGESTPAT:
        LODSB
        CMP     AL, NumPatterns
        JBE     NOTBIGGEST
        MOV     NumPatterns, AL
NOTBIGGEST:
        INC     CX
        CMP     CL, NumSequences
        JB      FINDBIGGESTPAT
        INC     NumPatterns

        XOR     CX, CX
        MOV     CL, NumPatterns
        MOV     AX, 64*16               ; 64 lines * 16 byte/line
        MUL     CX
        MOV     BX, AX
        MOV     CX, AX
        SHR     BX, 01h
        SHR     BX, 01h
        SHR     BX, 01h
        SHR     BX, 01h
        ADD     BX, 02h
        MOV     AX, 4800h
        INT     21h
        JC      END_ML
        MOV     PatternSeg, AX
        MOV     DS, AX
        MOV     AX, 3F00h
        MOV     BX, FileHandle
        XOR     DX, DX
        INT     21h

        XOR     BP, BP
LOADSAMPLELOOP:
        MOV     SI, BP
        SHL     SI, 01h
        MOV     AX, _SDATA
        MOV     DS, AX
        CMP     SampleLengths[SI], WORD PTR 03h
        JB      SKIPSAMPLELOAD
        MOV     BX, SampleLengths[SI]
        MOV     CX, BX
        SHR     BX, 01h
        SHR     BX, 01h
        SHR     BX, 01h
        SHR     BX, 01h
        ADD     BX, 02h
        MOV     AX, 4800h
        JC      END_ML
        MOV     SampleSeg[SI], AX
        MOV     DS, AX
        MOV     AX, 3F00h
        MOV     BX, FileHandle
        XOR     DX, DX
        INT     21h
        INC     BP
        CMP     BP, 31
        JB      LOADSAMPLELOOP
        JMP     CLOSEF
SKIPSAMPLELOAD:
        MOV     AX, 4201h
        MOV     DX, SampleLengths[SI]
        XOR     CX, CX
        INT     21h
        INC     BP
        CMP     BP, 31
        JB      LOADSAMPLELOOP

CLOSEF: MOV     AX, 3E00h
        INT     21h

        CLC

END_ML: POP     ES
        POP     DS
        POP     SI
        POP     DI
        POP     BP
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
LoadMOD  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
ReadNotes  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    BP
        PUSH    SI
        PUSH    DS

        MOV     AX, _SDATA
        MOV     DS, AX

        MOV     SI, CurPattern
        MOV     CX, 0Ah
        SHL     SI, CL
        MOV     AX, CurNote
        MOV     CX, 04h
        SHL     AX, CL
        ADD     SI, AX

        MOV     AX, PatternSeg
        MOV     DS, AX

        XOR     BP, BP
GETNOTESLOOP:
        MOV     BX, BP
        SHL     BX, 01h
        LODSB
        MOV     DH, AL
        LODSB
        MOV     DL, AL
        LODSB
        MOV     CX, 04h
        SHR     AL, CL
        MOV     CH, DH
        AND     CH, 0F0h
        OR      AL, CH
        OR      DH, 0FFh
        XOR     AH, AH
        OR      AX, AX
        JZ      DONTSAVETRACK
        MOV     CurTrack[BX], AX
DONTSAVETRACK:
        MOV     CX, DX
        CMP     CX, 05h
        JBE     DONTSAVEFREQ
        XOR     DX, DX
        MOV     AX, Count
        DIV     CX
        MOV     Freq[BX], AX
DONTSAVEFREQ:
        INC     BP
        CMP     BP, 04h
        JB      GETNOTESLOOP

        POP     DS
        POP     SI
        POP     BP
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
ReadNotes  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
UpdateTrack  PROC FAR

        OR      AH, AH
        JZ      TRACKNOCONT
        JMP     TRACKCONT
TRACKNOCONT:
        PUSH    AX
        MOV     AX, FreqWait
        MOV     WaitForFreq, AX
        POP     AX
        MOV     CX, AX
        MOV     AH, AL
        MOV     CurTrack[BX], AX
        XCHG    BX, CX
        DEC     BX
        SHL     BX, 01h
        MOV     AX, SampleSeg[BX]
        MOV     DX, SampleLengths[BX]
        MOV     SI, Volume[BX]
        XCHG    BX, CX
        MOV     CurSeg[BX], AX
        MOV     CurLeng[BX], DX
        MOV     CurByte[BX], 00h
        MOV     AX, SI
        XOR     AH, AH
        DEC     AL
        AND     AL, 3Fh
        MOV     CurVolume[BX], AL

TRACKCONT:
        MOV     DI, CurOffset
        MOV     SI, CurByte[BX]
        MOV     AX, CurSeg[BX]
        MOV     ES, AX
        XOR     DH, DH
        XOR     CX, CX
LITTLELOOP:
        MOV     AL, ES:[SI]
        MOV     AH, CurVolume[BX]
        MUL     AH
        ADD     [DI], AH

        INC     DI
        INC     CX
        CMP     CX, CurBuffSize
        JAE     CLEANUP
        MOV     AX, Freq[BX]

        DEC     WaitForFreq[BX]
        JNZ     SKIPFREQCHANGE
        PUSH    AX
        MOV     AX, FreqWait
        MOV     WaitForFreq[BX], AX
        POP     AX
SKIPFREQCHANGE:
        ADD     AX, TempFreq[BX]
        MOV     DL, AH
        XOR     DH, DH
        ADD     SI, DX
        XOR     AH, AH
        MOV     TempFreq[BX], AX

        CMP     SI, CurLeng[BX]
        JB      LITTLELOOP

        MOV     CurTrack[BX], 00h
        JMP     END_UT

CLEANUP:
        MOV     CurByte[BX], SI

END_UT:
        RET
UpdateTrack  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
UpdateBuffer  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DI
        PUSH    DS
        PUSH    ES

        MOV     AX, _SDATA
        MOV     DS, AX
        MOV     ES, AX

        CMP     Status, 03h
        JE      DOIT3
        CMP     Status, 04h
        JE      DOIT4
        JMP     END_UB

DOIT3:  MOV     CurOffset, OFFSET DMABuffer1
        MOV     NotCurOffset, OFFSET DMABuffer2
        MOV     AX, NewBufferSize
        MOV     Buffer1Size, AX
        CALL    SetDMABuffer
        MOV     AX, Buffer1Size
        MOV     CurBuffSize, AX
        JMP     UPDATENOW

DOIT4:  MOV     CurOffset, OFFSET DMABuffer2
        MOV     NoTCurOffset, OFFSET DMABuffer1
        MOV     AX, NewBufferSize
        MOV     Buffer2Size, AX
        CALL    SetDMABuffer
        MOV     AX, Buffer2Size
        MOV     CurBuffSize, AX

UPDATENOW:
        MOV     CX, AX
        MOV     DI, CurOffset
        MOV     AL, 80h
        STOSB

        MOV     Status, 00h
        MOV     BP, 04h
MAINUPDATELOOP:
        MOV     BX, BP
        DEC     BX
        SHL     BX, 01h
        MOV     AX, CurTrack[BX]
        OR      AX, AX
        JZ      NEXTTRACK
        CALL    UpdateTrack
NEXTTRACK:
        DEC     BP
        JNZ     MAINUPDATELOOP

        INC     CurNote
        CMP     CurNote, 64
        JB      NONEWPATTERN

        MOV     CurNote, 00h
        INC     CurSequence
        CMP     BL, NumSequences
        JBE     NOTENDOFSONG
        MOV     CurSequence, 00h
        XOR     BX, BX
NOTENDOFSONG:
        MOV     AL, Sequences[BX]
        XOR     AH, AH
        MOV     CurPattern, AX
NONEWPATTERN:
        CALL    ReadNotes

END_UB: POP     ES
        POP     DS
        POP     DI
        POP     CX
        POP     BX
        POP     AX

        RET
UpdateBuffer  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
StartPlaying  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    DS

        MOV     AX, _SDATA
        MOV     DS, AX

        MOV     BufferSeg, AX
        MOV     Buffer1Size, 0A1Fh
        MOV     Buffer2Size, 0A1Fh
        MOV     BufferOffset1, OFFSET DMABuffer1
        MOV     BufferOffset2, OFFSET DMABuffer2

        CALL    LoadMOD
        JC      END_SP

        CALL    DSPReset
        JC      END_SP

        CALL    SpeakerOn
        MOV     AH, SampleRate
        CALL    SetTimeConstant
        CALL    SetDMABuffer

        MOV     CurNote, 00h
        MOV     BX, CurSequence
        MOV     AL, Sequences[BX]
        XOR     AH, AH
        MOV     CurPattern, AX

        CALL    ReadNotes
        CALL    InstallMyDMA

        CLC

END_SP: POP     DS
        POP     BX
        POP     AX

        RET
StartPlaying  ENDP


;------------------------------------------------
;
;
;
;
;------------------------------------------------
StopPlaying  PROC FAR
        PUSH    AX

        CALL    DMAStop
        CALL    RestoreDMA
        CALL    SpeakerOff

        retarat 10
;        MOV     AX, 100
;        CALL    Delay

        POP     AX

        RET
StopPlaying  ENDP

start:  call    startplaying
        jc      endmain
mainloop:
        call    updatebuffer

        mov     ah, 1
        int     16h
        jz      mainloop

        mov     ah, 0
        int     16h

endmain:
        mov     ax, 4c00h
        int     21h

_SCODE  ENDS
        END start


;------------------------------------------------
