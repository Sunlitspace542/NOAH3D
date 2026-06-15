 LST OFF
 TR ON
 USE SPC700.MACS ;Write this in SPC700
 REL

**************************************************
*                                                *
*  SuperFamicom Music Low Level Sound Driver     *
*     By Bill Heineman and John Carmack          *
*                                                *
**************************************************

SoundList = $600
Defaults = $700
* sample data starts at 0x900

OFFCOUNT = $80

*
* Direct page equates
*

 DUM 0

oldport3 DS 1 ;Last command value
Channel DS 1 ;Current channel being mangled
HardChannel DS 1 ;Channel value #16
SoundNum DS 1 ;Which sound effect?
Pointer DS 2 ;Temp pointer
DownAddr DS 2 ;Download pointer
channelsample DS 8 ;sample to play for note on

Port0 ds 1
Port1 ds 1
Port2 ds 1
Port3 ds 1

 DEND

*
* Hardware registers
*

CONTROL = $F1
DSPRegAdr = $F2
DSPData = $F3
HPort0 = $F4
HPort1 = $F5
HPort2 = $F6
HPort3 = $F7
Timer0 = $FA
Counter0 = $FD

*
* Init all variables
*

Start CLRP ;Reset direct page to page #0
 LDXI #$FF ;Reset stack ($1FF)
 XTXS

 LDAI #0
 XTAX ;Clear index
]A STA[XI] ;Clear out my direct page
 CPXI #$F0 ;All done?
 BNE ]A ;Loop

*
* Init the DSP volume and envelope
*
 LDXI #DSPInitRegAdr-DSPInitRegVal-1
]A LDA16X DSPInitRegAdr ;Get Register
 XTAY
 LDA16X DSPInitRegVal ;Set it to this value
 CALL SetDSPYA ;Write the value
 DECX ;Count down
 BPL ]A ;Loop

 LDAI #0 ;Init my output ports (I am ready!)
 XTAY
 STYA HPort0
 STYA HPort2

*****************************************************************************
*
* Main loop
*
*****************************************************************************
MainLoop
 LDA8 HPort3
 CMP8 HPort3 ;Check if the port is stable
 BNE MainLoop ;Not stable, loop (needed?)
 CMP8 Port3 ;is the command new?
 BEQ MainLoop ;no

 LDYA HPort0 ;copy out the hardware port values
 STYA Port0
 LDYA HPort2
 STYA Port2
 XTYA  ;Port3 value in A
 STA8 HPort3 ;tell SNES command is fetched

 ANDI #15 ;command number
 ASLA
 XTAX
 XJMP[16X] CMDTABLE

CMDTABLE DA CMD_NoteOn,CMD_NoteOff,CMD_SetAddr,CMD_Download
 DA CMD_Assign,CMD_Bend,CMD_NoteOn,MainLoop
 DA MainLoop,MainLoop,MainLoop,MainLoop
 DA MainLoop,MainLoop,MainLoop,MainLoop

Bitty HEX 0102040810204080



* 5c (key off) was ff
* 6c (flg) was 2f
* 0d (efb) was 60
* 6d (esa) was >SoundList
* 7d (edl) was 2
* HEX FF081724241708FF ;Filter for echo sounds
DSPInitRegVal HEX 7F7F000000002000000000
 DB >SoundList,0,0
* HEX FF081724241708FF ;Filter for echo sounds
 HEX 7F00000000000000 ;Filter for normal sounds

DSPInitRegAdr HEX 0C1C2C3C4C5C6C0D2D3D4D
 HEX 5D6D7D
 HEX 0F1F2F3F4F5F6F7F


*
* Set a DSP register
* "Y" has register #
* "A" has value
*

SetDSPYA STY8 DSPRegAdr ;Save register
 STA8 DSPData ;Save value
 RET ;Exit

SetDSPXA STX8 DSPRegAdr ;Save register
 STA8 DSPData ;Save value
 RET ;Exit

*****************************************************************************
*
* instrument assign
*
*****************************************************************************
CMD_Assign
 LDX8 Port0 ; channel
 LDA8 Port1 ; sample for channel
 STA8X channelsample
 XJMP MainLoop


*****************************************************************************
*
* note off
*
* port
*****************************************************************************
CMD_NoteOff
*
* Shut down the voice
*
 LDX8 Port0 ; ch
 LDA16X Bitty ;Get voice to shut down
 LDYI #$5C ;Key off register
 CALL SetDSPYA ;Shut down old voice

*
* Wait for voice to shut down
*
 LDYI #OFFCOUNT
]A DECY
 BNE ]A
 XJMP MainLoop

*****************************************************************************
*
* pitch bend
*
*****************************************************************************
CMD_Bend
 LDA8 Port0 ;channel number
 ASLA
 ASLA
 ASLA
 ASLA
 XTAX
 INCX
 INCX
 LDA8 Port1 ; pitch low
 CALL SetDSPXA ; pitch low
 INCX
 LDA8 Port2 ; pitch high
 CALL SetDSPXA ; pitch high ($562 is 11k)
 XJMP MainLoop

*****************************************************************************
*
* note on
*
*****************************************************************************
CMD_NoteOn
*
* extract chanel number
*
 LDA8 Port3 ;bits 4-7 are chanel number
 ANDI #$70
 LSRA
 LSRA
 LSRA
 LSRA
 STA8 Channel
 XTAX

 LDA8X channelsample ;get instrument sample number for channel
 STA8 SoundNum ;Save sound #

*
* Shut down the voice
*
 LDA16X Bitty ;Get voice to shut down
 LDYI #$5C ;Key off register
 CALL SetDSPYA ;Shut down old voice

*
* Wait for voice to shut down
*
 LDYI #OFFCOUNT
]A DECY
 BNE ]A


*
* Start programming the new sound
*
 XTXA ;Index to hardware registers
 ASLA ;Mul by 16
 ASLA
 ASLA
 ASLA
 STA8 HardChannel ;Save channel (HardWare)
 XTAX ;Use index to DSP

*
* set the volume and frequency from the command
*
 LDA8 Port3
 ANDI #3 ; command 0 is stereo volume, 5 is mono
 BEQ stereo
 LDA8 Port2 ; full 7 bit volume
 CALL SetDSPXA ; left volume
 INCX
 CALL SetDSPXA ; right volume
 INCX
 XJMP pitch
stereo
 LDA8 Port2 ; command volume
 LSRA
 ANDI #$78
 CALL SetDSPXA ; left volume
 INCX
 LDA8 Port2 ; command volume
 ASLA
 ASLA
 ASLA
 ANDI #$78
 CALL SetDSPXA ; right volume
 INCX
pitch
 LDA8 Port0 ; pitch low
 CALL SetDSPXA ; pitch low
 INCX
 LDA8 Port1 ; pitch high
 CALL SetDSPXA ; pitch high ($562 is 11k)
 INCX
 LDA8 SoundNum
 CALL SetDSPXA ; sample number
 INCX
 LDAI #$fe
 CALL SetDSPXA ; ADSR 1
 INCX
 LDAI #$E9
 CALL SetDSPXA ; ADSR 2
 INCX
 LDAI #$0
 CALL SetDSPXA ; gain

*
* release the key off
*
 LDAI #0 ;release all key offs
 LDYI #$5C ;Key off register
 CALL SetDSPYA ;finish shutting down old voice

*
* do a key on
*
 LDX8 Channel
 LDA16X Bitty ;Get voice to start up
 LDYI #$4C ;Key on register
 CALL SetDSPYA ;Set and exit
 XJMP MainLoop

*****************************************************************************
*
* Set download address
*
*****************************************************************************
CMD_SetAddr
 LDA8 Port0
 STA8 DownAddr
 LDA8 Port1
 STA8 DownAddr+1
 XJMP MainLoop

*****************************************************************************
*
* Download three bytes
*
*****************************************************************************
CMD_Download
 LDYI #0
 LDA8 Port0
 STA[8]Y DownAddr
 INCY
 LDA8 Port1
 STA[8]Y DownAddr
 INCY
 LDA8 Port2
 STA[8]Y DownAddr

 LDA8 DownAddr ; advance pointer
 XCLC
 ADCI #3
 STA8 DownAddr
 LDA8 DownAddr+1
 ADCI #0
 STA8 DownAddr+1
 XJMP MainLoop

 SAV Driver.l
