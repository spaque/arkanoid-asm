@echo off
echo.
echo------------------------------------------------
echo.
echo  Nombre:      Sergio Paque Martin
echo  Titulaci¢n:  Ingenieria Informatica
echo  Grupo:       2§ B
echo.
echo------------------------------------------------
echo.
echo Ensamblando: FRONTON.ASM
tasm /zi /m2 FRONTON
echo.
echo Ensamblando: FR_KEYB.ASM
tasm /zi /m2 FR_KEYB
echo.
echo Ensamblando: FR_TIMER.ASM
tasm /zi /m2 FR_TIMER
echo.
echo Ensamblando: FR_SCR.ASM
tasm /zi /m2 FR_SCR
echo.
echo Ensamblando: FR_MOUSE.ASM
tasm /zi /m2 FR_MOUSE
echo.
echo Ensamblando: FR_LPT1.ASM
tasm /zi /m2 FR_LPT1
echo.
echo Ensamblando: FR_MUSIC.ASM
tasm /zi /m2 FR_MUSIC
echo.
echo Enlazando: FRONTON.EXE
tlink /v FRONTON+FR_KEYB+FR_TIMER+FR_SCR+FR_MOUSE+FR_LPT1+FR_MUSIC
