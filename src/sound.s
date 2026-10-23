; ---------------------------------------------------------------- sound
; Sound effect / music ids (driver in sound_driver.s once it exists)
SND_SHOT    = 1
SND_PLASMA  = 2
SND_EMPFIRE = 3
SND_RAIL    = 4
SND_THROW   = 5
SND_BOOM    = 6
SND_HIT     = 7
SND_HURT    = 8
SND_DIE     = 9
SND_DIE_E   = 10
SND_JUMP    = 11
SND_LAND    = 12
SND_PICKUP  = 13
SND_SELECT  = 14
SND_START   = 15
SND_DOOR    = 16
SND_EMP     = 17
SND_CLICK   = 18
SND_BOUNCE  = 19
SND_ESHOT   = 20
SND_CANNON  = 21
SND_ALERT   = 22
SND_SEVER   = 23
SND_RESCUE  = 24
SND_UNLOCK  = 25
SND_ELEV    = 26
SND_BEEP    = 27

MUS_TITLE   = 1
MUS_BRIEF   = 2
MUS_CITY    = 3
MUS_CAVE    = 4
MUS_TECH    = 5
MUS_BOSS    = 6
MUS_CHASE   = 7
MUS_CLEAR   = 8
MUS_FAIL    = 9
MUS_VICTORY = 10

; Upload the SPC700 driver through the IPL boot ROM protocol.
sound_init:
    A8
    XY16
@w0:lda APUIO0
    cmp #$AA
    bne @w0
    lda APUIO1
    cmp #$BB
    bne @w0
    lda #<SPC_ORG
    sta APUIO2
    lda #>SPC_ORG
    sta APUIO3
    lda #$01
    sta APUIO1
    lda #$CC
    sta APUIO0
@w1:cmp APUIO0
    bne @w1
    ldx #0
@byte:
    lda f:spc_blob,x
    sta APUIO1
    txa
    sta APUIO0
@w2:cmp APUIO0
    bne @w2
    inx
    cpx #(spc_blob_end - spc_blob)
    bcc @byte
    ; start the driver
    lda #<SPC_ORG
    sta APUIO2
    lda #>SPC_ORG
    sta APUIO3
    stz APUIO1
    txa
    clc
    adc #2
    bne :+
    inc a
:   sta APUIO0
@w3:cmp APUIO0
    bne @w3
    ; wait for the driver's ready signal (bounded)
    ldx #0
@w4:lda APUIO0
    cmp #$55
    beq @ready
    dex
    bne @w4
@ready:
    stz snd_seq
    A16
    stz snd_n
    rts

SPC_ORG = $0200

; A = sound effect id (queued, sent once per frame)
sfx:
    phx
    ldx snd_n
    cpx #8
    bcs @x
    ; skip duplicates queued this frame
    ldx #0
@d: cpx snd_n
    bcs @add
    cmp snd_queue,x
    beq @x
    inx
    inx
    bra @d
@add:
    sta snd_queue,x
    inx
    inx
    stx snd_n
@x: plx
    rts

; A = song id (0 = stop)
music:
    ora #$80
    jmp sfx

; send queued commands to the SPC (main loop, once per frame)
snd_flush:
    ldx #0
@l: cpx snd_n
    bcs @done
    A8
    lda snd_queue,x
    sta APUIO1
    lda snd_seq
    inc a
    bne :+
    inc a
:   sta snd_seq
    sta APUIO0
    ; wait for the echo
    ldy #4000
@w: cmp APUIO0
    beq @ok
    dey
    bne @w
@ok:A16
    inx
    inx
    bra @l
@done:
    stz snd_n
    rts
