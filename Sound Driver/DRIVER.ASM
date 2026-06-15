; Asar 1.91
norom
arch spc700 ;Write this in SPC700
org $0000
base $0200

;**************************************************
;*                                                *
;*  Super Famicom Music Low Level Sound Driver    *
;*     By Rebecca Heineman and John Carmack       *
;*                                                *
;**************************************************

!SoundList = $0600
!Defaults = $0700
; sample data starts at $0900

!OFFCOUNT = $80

;
; Direct page equates
;

!oldport3 = $00 ;Last command value
!Channel = $01 ;Current channel being mangled
!HardChannel = $02 ;Channel value #16
!SoundNum = $03 ;Which sound effect?
!Pointer = $04 ;Temp pointer
!DownAddr = $06 ;Download pointer
!channelsample = $08 ;sample to play for note on

!Port0 = $10
!Port1 = $11
!Port2 = $12
!Port3 = $13

;
; Hardware registers
;

!CONTROL = $F1
!DSPRegAdr = $F2
!DSPData = $F3
!HPort0 = $F4
!HPort1 = $F5
!HPort2 = $F6
!HPort3 = $F7
!Timer0 = $FA
!Counter0 = $FD

;
; Init all variables
;

Start:
	clrp ;Reset direct page to page #0
	mov	x,#$ff ;Reset stack ($1FF)
	mov	sp,x

	mov	a,#$00
	mov	x,a ;Clear index
-
	mov	(x+),a ;Clear out my direct page
	cmp	x,#$f0 ;All done?
	bne	- ;Loop

;
; Init the DSP volume and envelope
;
	mov	x,#DSPInitRegAdr-DSPInitRegVal-1
-
	mov	a,DSPInitRegAdr+x ;Get Register
	mov	y,a
	mov	a,DSPInitRegVal+x ;Set it to this value
	call	SetDSPYA ;Write the value
	dec	x ;Count down
	bpl	- ;Loop

	mov	a,#$00 ;Init my output ports (I am ready!)
	mov	y,a
	movw	!HPort0,ya
	movw	!HPort2,ya

;*****************************************************************************
;*
;* Main loop
;*
;*****************************************************************************
MainLoop:
	mov	a,!HPort3
	cmp	a,!HPort3 ;Check if the port is stable
	bne	MainLoop ;Not stable, loop (needed?)
	cmp	a,!Port3 ;is the command new?
	beq	MainLoop ;no

	movw	ya,!HPort0 ;copy out the hardware port values
	movw	!Port0,ya
	movw	ya,!HPort2
	movw	!Port2,ya
	mov	a,y  ;Port3 value in A
	mov	!HPort3,a ;tell SNES command is fetched

	and	a,#15 ;command number
	asl	a
	mov	x,a
	jmp	(CMDTABLE+x)

CMDTABLE:
	dw CMD_NoteOn,CMD_NoteOff,CMD_SetAddr,CMD_Download
	dw CMD_Assign,CMD_Bend,CMD_NoteOn,MainLoop
	dw MainLoop,MainLoop,MainLoop,MainLoop
	dw MainLoop,MainLoop,MainLoop,MainLoop

Bitty:
	db $01,$02,$04,$08,$10,$20,$40,$80



; 5c (key off) was ff
; 6c (flg) was 2f
; 0d (efb) was 60
; 6d (esa) was >SoundList
; 7d (edl) was 2
;	db $FF,$08,$17,$24,$24,$17,$08,$FF ;Filter for echo sounds
DSPInitRegVal:
	db $7F,$7F,$00,$00,$00,$00,$20,$00,$00,$00,$00
	db (!SoundList>>8),$00,$00
;	db $FF,$08,$17,$24,$24,$17,$08,$FF ;Filter for echo sounds
	db $7F,$00,$00,$00,$00,$00,$00,$00 ;Filter for normal sounds

DSPInitRegAdr:
	db $0C,$1C,$2C,$3C,$4C,$5C,$6C,$0D,$2D,$3D,$4D
	db $5D,$6D,$7D
	db $0F,$1F,$2F,$3F,$4F,$5F,$6F,$7F


;
; Set a DSP register
; "Y" has register #
; "A" has value
;

SetDSPYA:
	mov	!DSPRegAdr,y ;Save register
	mov	!DSPData,a ;Save value
	ret ;Exit

SetDSPXA:
	mov	!DSPRegAdr,x ;Save register
	mov	!DSPData,a ;Save value
	ret ;Exit

;*****************************************************************************
;*
;* instrument assign
;*
;*****************************************************************************
CMD_Assign:
	mov	x,!Port0 ; channel
	mov	a,!Port1 ; sample for channel
	mov	!channelsample+x,a
	jmp	MainLoop

;*****************************************************************************
;*
;* note off
;*
;* port
;*****************************************************************************
CMD_NoteOff:
;*
;* Shut down the voice
;*
	mov	x,!Port0 ; ch
	mov	a,Bitty+x ;Get voice to shut down
	mov	y,#$5c ;Key off register
	call	SetDSPYA ;Shut down old voice

;*
;* Wait for voice to shut down
;*
	mov	y,#!OFFCOUNT
-
	dec	y
	bne -
	jmp	MainLoop

;*****************************************************************************
;*
;* pitch bend
;*
;*****************************************************************************
CMD_Bend:
	mov	a,!Port0 ;channel number
	asl	a
	asl	a
	asl	a
	asl	a
	mov	x,a
	inc	x
	inc	x
	mov	a,!Port1 ; pitch low
	call	SetDSPXA ; pitch low
	inc	x
	mov	a,!Port2 ; pitch high
	call	SetDSPXA ; pitch high ($562 is 11k)
	jmp	MainLoop

;*****************************************************************************
;*
;* note on
;*
;*****************************************************************************
CMD_NoteOn:
;
; extract channel number
;
	mov	a,!Port3 ;bits 4-7 are channel number
	and	a,#$70
	lsr	a
	lsr	a
	lsr	a
	lsr	a
	mov !Channel,a
	mov	x,a

	mov	a,!channelsample+x ;get instrument sample number for channel
	mov	!SoundNum,a ;Save sound #

;
; Shut down the voice
;
	mov	a,Bitty+x ;Get voice to shut down
	mov	y,#$5c ;Key off register
	call	SetDSPYA ;Shut down old voice

;
; Wait for voice to shut down
;
	mov	y,#!OFFCOUNT
-
	dec	y
	bne	-


;
; Start programming the new sound
;
	mov	a,x ;Index to hardware registers
	asl	a ;Mul by 16
	asl	a
	asl	a
	asl	a
	mov	!HardChannel,a ;Save channel (HardWare)
	mov	x,a ;Use index to DSP

;
; set the volume and frequency from the command
;
	mov	a,!Port3
	and	a,#$03 ; command 0 is stereo volume, 5 is mono
	beq	stereo
	mov	a,!Port2 ; full 7 bit volume
	call	SetDSPXA ; left volume
	inc	x
	call	SetDSPXA ; right volume
	inc	x
	jmp	pitch
stereo:
	mov	a,!Port2 ; command volume
	lsr	a
	and	a,#$78
	call	SetDSPXA ; left volume
	inc	x
	mov	a,!Port2 ; command volume
	asl	a
	asl	a
	asl	a
	and	a,#$78
	call	SetDSPXA ; right volume
	inc	x
pitch:
	mov	a,!Port0 ; pitch low
	call	SetDSPXA ; pitch low
	inc	x
	mov	a,!Port1 ; pitch high
	call	SetDSPXA ; pitch high ($562 is 11k)
	inc	x
	mov	a,!SoundNum
	call	SetDSPXA ; sample number
	inc	x
	mov	a,#$fe
	call	SetDSPXA ; ADSR 1
	inc	x
	mov	a,#$e9
	call	SetDSPXA ; ADSR 2
	inc	x
	mov	a,#$00
	call	SetDSPXA ; gain

;
; release the key off
;
	mov	a,#$00 ;release all key offs
	mov	y,#$5c ;Key off register
	call	SetDSPYA ;finish shutting down old voice

;
; do a key on
;
	mov	x,!Channel
	mov	a,Bitty+x ;Get voice to start up
	mov	y,#$4c ;Key on register
	call	SetDSPYA ;Set and exit
	jmp	MainLoop

;*****************************************************************************
;*
;* Set download address
;*
;*****************************************************************************
CMD_SetAddr:
	mov	a,!Port0
	mov	!DownAddr,a
	mov	a,!Port1
	mov	!DownAddr+1,a
	jmp	MainLoop

;*****************************************************************************
;*
;* Download three bytes
;*
;*****************************************************************************
CMD_Download:
	mov	y,#$00
	mov	a,!Port0
	mov	(!DownAddr)+y,a
	inc	y
	mov	a,!Port1
	mov	(!DownAddr)+y,a
	inc	y
	mov	a,!Port2
	mov	(!DownAddr)+y,a

	mov	a,!DownAddr ; advance pointer
	clrc
	adc	a,#$03
	mov	!DownAddr,a
	mov	a,!DownAddr+1
	adc	a,#$00
	mov	!DownAddr+1,a
	jmp	MainLoop

;End