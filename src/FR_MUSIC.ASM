;------------------------------------------------
;
;  Nombre:      Sergio Paque Martin
;  Titulaci¢n:  Ingenieria Informatica
;  Grupo:       2§ B
;
;------------------------------------------------
;
; This module does the background music stuff.
; It divides the buffer into two buffers if
; it's necesary for the DMAC, cause the buffers
; cannot straddle a 64KB physical page boundary.
; Loads the sample onto memory and fix the data
; making the music a little better (the music's
; just a sample that's looping).
; Handle the sharing interrupts issue.
;
;------------------------------------------------


;------------------------------------------------


        PUBLIC  InstallMyIRQ7Int
        PUBLIC  RestoreIRQ7Int
        PUBLIC  SpeakerOff
        PUBLIC  SpeakerOn

        EXTRN   Delay:FAR
        EXTRN   LPT1:FAR


;------------------------------------------------


_MDATA  SEGMENT

oldoff  DW  ?
oldseg  DW  ?

BaseAddress  DW  220h
IRQNumber    DB  07h
DMAChannel   DB  01h
SBDetected   DB  00h

FileName       DB  'SAMPLE.SAM',0
SampleLength   DW  ?

Pages   DW  02h  DUP (?)
Offsets DW  02h  DUP (?)
Lengths DW  02h  DUP (?)
NextBuf DW  0, 0
Current DW  0

_MDATA  ENDS


SAMPLE  SEGMENT

Buffer  DB  0FFFFh  DUP  (0)

SAMPLE  ENDS


TEMPSAMPLE  SEGMENT

TempBuffer  DB  0FFFFh  DUP  (0)

TEMPSAMPLE  ENDS


;------------------------------------------------


_MCODE  SEGMENT
        ASSUME  CS:_MCODE, DS:_MDATA


;------------------------------------------------
; Resets the DSP so it can be programmed
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

        MOV     AX, _MDATA
        MOV     DS, AX

        MOV     DX, BaseAddress         ; SB base I/O address
        ADD     DX, 06h                 ; Reset port, 2x6h

        MOV     AL, 01h
        OUT     DX, AL                  ; Write a 1 to the DSP reset port

        MOV     AX, 01h
        CALL    Delay                   ; Wait for a milisecond

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
; Write data to the DSP
;
; Input: AL=Value to be written to the DSP
; Output: None
;------------------------------------------------
DSPWrite  PROC  FAR
        PUSH    DX
        PUSH    DS
        PUSH    AX

        MOV     AX, _MDATA
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
; Turns on the speaker
;
; Input: None
; Output: None
;------------------------------------------------
SpeakerOn  PROC  FAR
        PUSH    AX

        MOV     AL, 0D1h
        CALL    DSPWrite

        POP     AX

        RET
SpeakerOn  ENDP


;------------------------------------------------
; Turns off the speaker
;
; Input: None
; Output: None
;------------------------------------------------
SpeakerOff  PROC  FAR
        PUSH    AX

        MOV     AL, 0D3h
        CALL    DSPWrite

        POP     AX

        RET
SpeakerOff  ENDP


;------------------------------------------------
; Resumes the DMA transfer paused by DMAStop
;
; Input: None
; Output: None
;------------------------------------------------
DMAContinue  PROC  FAR
        PUSH    AX

        MOV     AL, 0D4h
        CALL    DSPWrite

        POP     AX

        RET
DMAContinue  ENDP


;------------------------------------------------
; Set the DSP to cease sending out DMA requests
;
; Input: None
; Output: None
;------------------------------------------------
DMAStop  PROC  FAR
        PUSH    AX

        MOV     AL, 0D0h
        CALL    DSPWrite

        POP     AX

        RET
DMAStop  ENDP


;------------------------------------------------
; Set the DSP with the specified transfer rate
;
; Input: AH=Time Constant
;          =HIGH(65536 - ( 256000000 / (channels * sampling rate) ) )
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
; Writes in the specified mixer port
;
; Input: AL=Mixer register index
;        AH=Mixer register setting
; Output: None
;------------------------------------------------
SetMixer  PROC FAR
        PUSH    AX
        PUSH    DX
        PUSH    DS

        MOV     DX, _MDATA
        MOV     DS, DX

        MOV     DX, BaseAddress         ; SB Base I/O address
        ADD     DX, 04h                 ; Mixer address port
        OUT     DX, AL                  ; Select the register
        INC     DX                      ; Mixer data port

        MOV     AL, AH
        OUT     DX, AL                  ; Set the register setting

        POP     DS
        POP     DX
        POP     AX

        RET
SetMixer  ENDP


;------------------------------------------------
; Gets the suitable info to do DMA transfers
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
        ADD     DX, AX
        ADC     BL, 00h

        MOV     AH, BL
        XOR     AL, AL
        MOV     CX, DX
        NEG     CX

        POP     BX

        RET
GetBufferAdd  ENDP

;------------------------------------------------
; Programs the DMA to do the transfer with
; the parameters given
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
; Install the new IRQ7 interrupt handler and
; start the DMA transfers
;
; Input: None
; Output: None
;------------------------------------------------
InstallMyIRQ7Int  PROC FAR
        PUSH    AX
        PUSH    CX
        PUSH    DS
        PUSH    ES

        MOV     AX, _MDATA
        MOV     DS, AX
        XOR     AX, AX
        MOV     ES, AX

        MOV     AX, ES:[3Ch]
        MOV     oldoff, AX              ; Grab the original vector
        MOV     AX, ES:[3Eh]
        MOV     oldseg, AX

        CLI
        MOV     ES:[3Ch], OFFSET IRQ7Int
        MOV     WORD PTR ES:[3Eh], SEG IRQ7Int
        MOV     DX, 37Ah
        IN      AL, DX
        OR      AL, 10h
        OUT     DX, AL
        IN      AL, 21h
        AND     AL, 7Fh
        OUT     21h, AL
        STI

        CALL    StartPlaying
        JC      END_I7

        MOV     SBDetected, BYTE PTR 01h
        MOV     AX, Pages[00h]
        MOV     CX, Lengths[00h]
        MOV     DX, Offsets[00h]
        CALL    TransferDMA             ; Start the transfers

END_I7: POP     ES
        POP     DS
        POP     CX
        POP     AX

        RET
InstallMyIRQ7Int  ENDP


;------------------------------------------------
; Restore the original IRQ7 vector
;
; Input: None
; Output: None
;------------------------------------------------
RestoreIRQ7Int  PROC FAR
        PUSH    AX
        PUSH    CX
        PUSH    DS
        PUSH    ES

        MOV     AX, _MDATA
        MOV     DS, AX
        XOR     AX, AX
        MOV     ES, AX

        CMP     SBDetected, BYTE PTR 00h
        JE      RESTORE
        CALL    StopPlaying

RESTORE:
        CLI
        MOV     AX, oldoff
        MOV     ES:[3Ch], AX
        MOV     AX, oldseg
        MOV     ES:[3Eh], AX
        MOV     DX, 37Ah
        IN      AL, DX
        AND     AL, 0EFh
        OUT     DX, AL
        IN      AL, 21h
        OR      AL, 80h
        OUT     21h, AL
        STI

        POP     ES
        POP     DS
        POP     CX
        POP     AX

        RET
RestoreIRQ7Int  ENDP


;------------------------------------------------
; IRQ7 interrupt handler, it determines whether
; the interrupt is meant for the LPT1 or the DSP
; and call the appropiate handler
;
; Input: None
; Output: None
;------------------------------------------------
IRQ7Int  PROC FAR
        PUSH    AX
        PUSH    DX
        PUSH    DS

        MOV     AX, _MDATA
        MOV     DS, AX

        CMP     SBDetected, BYTE PTR 00h
        JE      PARALLEL_INT

        MOV     DX, BaseAddress         ; SB base I/O address 2x0h
        ADD     DX, 04h                 ; Mixer register address port 2x4h
        MOV     AL, 82h                 ; Index for Interrupt Status register
        OUT     DX, AL
        INC     DX                      ; Mixer data port
        IN      AL, DX                  ; Get interrupt status
        TEST    AL, 01h                 ; 8-bit DMA-mode digitized sound I/O?
        JZ      PARALLEL_INT

        CALL    DSPInt
        JMP     END_R7

PARALLEL_INT:
        CALL    LPT1

END_R7: MOV     AL, 20h
        OUT     20h, AL

        POP     DS
        POP     DX
        POP     AX

        IRET
IRQ7Int  ENDP


;------------------------------------------------
; DSP interrupt handler called when a transfer's
; finished, we gotta program the next transfer
;
; Input: None
; Output: None
;------------------------------------------------
DSPInt  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DS

        MOV     AX, _MDATA
        MOV     DS, AX

        MOV     DX, BaseAddress
        ADD     DX, 0Eh
        IN      AL, DX                  ; Acknowledge interrupt

        XOR     Current, WORD PTR 01h
        MOV     BX, Current
        SHL     BX, 01h                 ; If we got two DMA buffers
        MOV     BX, NextBuf[BX]         ; transfer the next one

        MOV     AX, Pages[BX]           ; Page's in the high byte of Pages
        MOV     CX, Lengths[BX]
        MOV     DX, Offsets[BX]
        CALL    TransferDMA

        POP     DS
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
DSPInt  ENDP


;------------------------------------------------
; Figures the DMA buffers info and saves it
;
; Input: None
; Output: None
;------------------------------------------------
SetDMABuffer  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    DS

        MOV     AX, _MDATA
        MOV     DS, AX

        MOV     AX, SEG Buffer
        XOR     DX, DX
        CALL    GetBufferAdd

        CMP     CX, SampleLength        ; if max_length's less than needed
        JB      SKIP_LENGTH_SET         ; we gotta set 2 DMA buffers

        MOV     CX, SampleLength
        JMP     NOMORE

SKIP_LENGTH_SET:
        MOV     BX, SampleLength
        SUB     BX, CX
        DEC     BX
        MOV     Lengths[02h], BX
        MOV     Pages[02h], AX               ; The second buffer a page upper
        ADD     Pages[02h], WORD PTR 100h    ; The page's in the high byte
        MOV     Offsets[02h], 00h            ; At the beginning of the buffer
        MOV     NextBuf[02h], WORD PTR 02h

NOMORE: MOV     Pages[00h], AX
        MOV     Offsets[00h], DX
        DEC     CX
        MOV     Lengths[00h], CX

        POP     DS
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
SetDMABuffer  ENDP


;------------------------------------------------
; Load the sample into memory so it can
; be played later
;
; Input: None
; Output: CF=1 if there's a file error
;         CF=0 if not
;------------------------------------------------
LoadSample  PROC FAR
        PUSH    AX
        PUSH    BX
        PUSH    CX
        PUSH    DX
        PUSH    BP
        PUSH    DI
        PUSH    SI
        PUSH    DS
        PUSH    ES

        MOV     AX, _MDATA
        MOV     DS, AX

        MOV     DX, OFFSET FileName
        MOV     AX, 3D00h
        INT     21h                     ; Open the file
        JC      END_LS                  ; If error openning exit

        MOV     BX, AX
        MOV     AX, SEG TempBuffer
        MOV     DS, AX
        XOR     DX, DX                  ; Load the sample at offset 0
        MOV     CX, 0FFFFh              ; Read in a whole segment worth
        MOV     AX, 3F00h
        INT     21h                     ; Load the sample

        MOV     CX, _MDATA
        MOV     DS, CX

        MOV     SampleLength, AX

        MOV     AX, 3E00h
        INT     21h                     ; Close the file

        XOR     SI, SI
        XOR     BP, BP
        MOV     CX, SampleLength
        SHL     SampleLength, 01h
        MOV     DI, SampleLength
        DEC     DI
        MOV     AX, SEG Buffer
        MOV     ES, AX
        MOV     AX, SEG TempBuffer
        MOV     DS, AX
FIX_LOOP:
        MOV     AL, DS:[SI]
        INC     SI
        ADD     AL, 80h                 ; fix the sample so it's playable
        MOV     ES:[BP], AL             ; on a SB and make one channel
        MOV     ES:[DI], AL             ; play forward and one in reverse
        SUB     DI, 02h
        ADD     BP, 02h
        LOOP    FIX_LOOP

        CLC

END_LS: POP     ES
        POP     DS
        POP     SI
        POP     DI
        POP     BP
        POP     DX
        POP     CX
        POP     BX
        POP     AX

        RET
LoadSample  ENDP


;------------------------------------------------
; Initializes the SB and the DMAC and load
; the sample so we can play it
;
; Input: None
; Output: CF=1 if there's an error
;         CF=0 if everything was ok
;------------------------------------------------
StartPlaying  PROC FAR
        PUSH    AX

        CALL    DSPReset
        JC      END_SP

        CALL    LoadSample
        JC      END_SP

        CALL    SetDMABuffer

        MOV     AH, 0F4h    ; 65536-(256000000/(channels*sampling rate))
        CALL    SetTimeConstant

        MOV     AX, 130Eh
        CALL    SetMixer        ; Turn stereo ON
        MOV     AX, 0FF22h
        CALL    SetMixer        ; Set master volume to R=0Fh, L=0Fh
        MOV     AX, 0FF04h
        CALL    SetMixer        ; Set VOC volume to R=0Fh, L=0Fh

        CALL    SpeakerOn

        CLC

END_SP: POP     AX

        RET
StartPlaying  ENDP


;------------------------------------------------
; Stops the music and the DMA transfers
;
; Input: None
; Output: None
;------------------------------------------------
StopPlaying  PROC FAR
        PUSH    AX

        MOV     AX, 110Eh               ; Turn stereo OFF
        CALL    SetMixer

        CALL    DMAStop
        CALL    SpeakerOff
        CALL    DSPReset

        POP     AX

        RET
StopPlaying  ENDP


_MCODE  ENDS
        END

