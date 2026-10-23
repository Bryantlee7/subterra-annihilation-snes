; ---------------------------------------------------------------- particles
; Effects: sparks, blood, debris (severed parts), explosions, smoke, beams.
; Spawners take t0/t1 = position (px) and may clobber t0-t3, X, Y only.

PT_SPARK   = 1
PT_BLOOD   = 2
PT_SPLAT   = 3
PT_DEBRIS  = 4
PT_ANIM    = 5      ; static animation (explosion etc.)
PT_SMOKE   = 6
PT_BEAM    = 7
PT_STATIC  = 8
PT_ROCK    = 9
PT_RISE    = 10

; find a slot -> X (round robin, overwrites the oldest when full)
pt_alloc:
    ldx pt_next
    ldy #MAX_PART
@l: lda pt_type,x
    beq @ok
    inx
    inx
    cpx #MAX_PART*2
    bcc :+
    ldx #0
:   dey
    bne @l
    ; full: reuse
    ldx pt_next
@ok:
    txa
    inc a
    inc a
    cmp #MAX_PART*2
    bcc :+
    lda #0
:   sta pt_next
    stz pt_vx,x
    stz pt_vy,x
    stz pt_big,x
    lda t0
    asl
    asl
    asl
    asl
    sta pt_x,x
    lda t1
    asl
    asl
    asl
    asl
    sta pt_y,x
    rts

fx_spark:
    jsr pt_alloc
    lda #PT_STATIC
    sta pt_type,x
    lda #6
    sta pt_life,x
    lda #(SPR_FX_SPARK0 | $2800)
    sta pt_tile,x
    rts

fx_alert:
    jsr pt_alloc
    lda #PT_STATIC
    sta pt_type,x
    lda #40
    sta pt_life,x
    lda #(SPR_UI_ALERT | $2C00)
    sta pt_tile,x
    rts

fx_stun:
    jsr pt_alloc
    lda #PT_STATIC
    sta pt_type,x
    lda #10
    sta pt_life,x
    lda #(SPR_FX_STUN | $2800)
    sta pt_tile,x
    rts

fx_beam:
    jsr pt_alloc
    lda #PT_BEAM
    sta pt_type,x
    lda #8
    sta pt_life,x
    lda p_aim
    asl
    tay
    lda beam_tiles,y
    ldy p_face
    beq :+
    eor #$4000
:   sta pt_tile,x
    rts
beam_tiles: .word SPR_FX_RAIL_H | $2800, SPR_FX_RAIL_V | $2800, SPR_FX_RAIL_D | $2800, SPR_FX_RAIL_D | $A800

fx_emp_burst:
    jsr pt_alloc
    lda #PT_STATIC
    sta pt_type,x
    lda #14
    sta pt_life,x
    lda #(SPR_FX_EMP1 | $2800)
    sta pt_tile,x
    lda #4
    sta t2
@l: jsr pt_alloc
    lda #PT_SPARK
    sta pt_type,x
    lda #12
    sta pt_life,x
    lda #(SPR_FX_STUN | $2800)
    sta pt_tile,x
    jsr random
    and #63
    sec
    sbc #32
    sta pt_vx,x
    jsr random
    and #63
    sec
    sbc #40
    sta pt_vy,x
    dec t2
    bne @l
    rts

fx_smoke:
    jsr pt_alloc
    lda #PT_SMOKE
    sta pt_type,x
    lda #40
    sta pt_life,x
    lda #(SPR_FX_SMOKE0 | $2800)
    sta pt_tile,x
    lda #.loword(-8)
    sta pt_vy,x
    rts

fx_teleport:
    lda #6
    sta t2
@l: jsr pt_alloc
    lda #PT_RISE
    sta pt_type,x
    jsr random
    and #31
    clc
    adc #20
    sta pt_life,x
    lda #(SPR_FX_EMP0 | $2800)
    sta pt_tile,x
    jsr random
    and #31
    sec
    sbc #16
    sta pt_vx,x
    lda #.loword(-24)
    sta pt_vy,x
    lda t1
    sec
    sbc #4
    sta t1
    dec t2
    bne @l
    rts

; big explosion: animated fireball + smoke + sparks
fx_explosion:
    jsr pt_alloc
    lda #PT_ANIM
    sta pt_type,x
    lda #20
    sta pt_life,x
    lda #2
    sta pt_big,x
    lda pt_x,x
    sec
    sbc #(8*16)
    sta pt_x,x
    lda pt_y,x
    sec
    sbc #(8*16)
    sta pt_y,x
    lda #(SPR_FX_EXPL0 | $2800)
    sta pt_tile,x
    jsr fx_sparks_burst
    jmp fx_smoke

fx_explosion_small:
    jsr pt_alloc
    lda #PT_STATIC
    sta pt_type,x
    lda #8
    sta pt_life,x
    lda #(SPR_FX_MUZZLE1 | $2800)
    sta pt_tile,x
    jmp fx_sparks_burst

fx_sparks_burst:
    lda #5
    sta t2
@l: jsr pt_alloc
    lda #PT_SPARK
    sta pt_type,x
    jsr random
    and #7
    clc
    adc #8
    sta pt_life,x
    lda #(SPR_FX_SPARK1 | $2800)
    sta pt_tile,x
    jsr random
    and #127
    sec
    sbc #64
    sta pt_vx,x
    jsr random
    and #63
    sec
    sbc #64
    sta pt_vy,x
    dec t2
    bne @l
    rts

; hit on actor dmg_slot at t0/t1: blood for humans, sparks for robots
fx_hit_actor:
    ldx dmg_slot
    lda a_flags,x
    and #F_HUMAN
    beq fx_hit_robot
    lda gore
    beq fx_hit_robot
    lda #3
    bra blood_n
fx_hit_robot:
    lda #2
    sta t2
    jsr fx_spark
    bra fx_sparks_some

; player got hit
fx_hit_human:
    lda gore
    beq fx_hit_robot
    lda #3
    bra blood_n

fx_blood_burst:
    lda #6
blood_n:
    sta t2
@l: jsr pt_alloc
    lda #PT_BLOOD
    sta pt_type,x
    lda #90
    sta pt_life,x
    jsr random
    and #1
    beq :+
    lda #(SPR_DB_BLOOD1 - SPR_DB_BLOOD0)
:   clc
    adc #(SPR_DB_BLOOD0 | $2A00)
    sta pt_tile,x
    jsr random
    and #63
    sec
    sbc #32
    clc
    adc debris_push
    sta pt_vx,x
    jsr random
    and #63
    sec
    sbc #72
    sta pt_vy,x
    dec t2
    bne @l
    stz debris_push
    rts

fx_sparks_some:
    lda #2
    sta t2
@l: jsr pt_alloc
    lda #PT_SPARK
    sta pt_type,x
    lda #8
    sta pt_life,x
    lda #(SPR_FX_SPARK1 | $2800)
    sta pt_tile,x
    jsr random
    and #63
    sec
    sbc #32
    sta pt_vx,x
    jsr random
    and #31
    sec
    sbc #40
    sta pt_vy,x
    dec t2
    bne @l
    rts

fx_rock_chunk:
    lda #2
    sta t2
@l: jsr pt_alloc
    lda #PT_ROCK
    sta pt_type,x
    lda #60
    sta pt_life,x
    jsr random
    and #1
    beq :+
    lda #(SPR_DB_ROCK1 - SPR_DB_ROCK0)
:   clc
    adc #(SPR_DB_ROCK0 | $2A00)
    sta pt_tile,x
    jsr random
    and #63
    sec
    sbc #32
    sta pt_vx,x
    jsr random
    and #31
    sec
    sbc #56
    sta pt_vy,x
    dec t2
    bne @l
    rts

; severed part: t2 = tile|attr, t3 = size (0/2), debris_push = x velocity hint
fx_debris:
    lda t2
    pha
    lda t3
    pha
    jsr pt_alloc
    pla
    sta pt_big,x
    pla
    sta pt_tile,x
    lda #PT_DEBRIS
    sta pt_type,x
    lda #220
    sta pt_life,x
    jsr random
    and #31
    sec
    sbc #16
    clc
    adc debris_push
    cmp #$8000
    ror
    sta pt_vx,x
    jsr random
    and #31
    sec
    sbc #72
    sta pt_vy,x
    lda pt_big,x
    beq :+
    ; big sprites are drawn from their top-left
    lda pt_x,x
    sec
    sbc #(8*16)
    sta pt_x,x
    lda pt_y,x
    sec
    sbc #(8*16)
    sta pt_y,x
:   stz debris_push
    rts

; ---------------------------------------------------------------- update
pt_update:
    ldx #0
@l: lda pt_type,x
    bne :+
    jmp @n
:   stx pt_cur
    dec pt_life,x
    bne :+
    stz pt_type,x
    jmp @n
:   cmp #PT_STATIC
    bne :+
    jmp @n
:   cmp #PT_SPLAT
    bne :+
    jmp @n
:   cmp #PT_BEAM
    bne :+
    jmp @n
:   cmp #PT_ANIM
    bne @mv
    ; advance explosion frame every 5 frames
    lda pt_life,x
    cmp #15
    beq @nf
    cmp #10
    beq @nf
    cmp #5
    beq @nf
    jmp @n
@nf:lda pt_tile,x
    clc
    adc #2
    sta pt_tile,x
    jmp @n
@mv:
    ; gravity for physical particles
    lda pt_type,x
    cmp #PT_SMOKE
    beq @nograv
    cmp #PT_RISE
    beq @nograv
    lda pt_vy,x
    clc
    adc #4
    cmp #96
    bmi :+
    lda #96
:   sta pt_vy,x
@nograv:
    lda pt_x,x
    clc
    adc pt_vx,x
    sta pt_x,x
    lda pt_y,x
    clc
    adc pt_vy,x
    sta pt_y,x
    ; map collision for blood / debris / rocks
    lda pt_type,x
    cmp #PT_BLOOD
    beq @col
    cmp #PT_DEBRIS
    beq @col
    cmp #PT_ROCK
    beq @col
    jmp @n
@col:
    lda pt_vy,x
    bpl @lb452_8
    jmp @n
@lb452_8:
    ; probe point: bottom center of the sprite
    lda pt_big,x
    beq :+
    lda #(8*16)
:   clc
    adc pt_x,x
    lsr
    lsr
    lsr
    lsr
    sta t0
    lda pt_big,x
    beq :+
    lda #(15*16)
    bra :++
:   lda #(4*16)
:   clc
    adc pt_y,x
    lsr
    lsr
    lsr
    lsr
    tay
    lda t0
    jsr attr_at
    ldx pt_cur
    and #(AT_SOLID | AT_PLATFORM)
    beq @n
    ; landed
    lda pt_type,x
    cmp #PT_BLOOD
    bne @bounce
    ; blood leaves a splat on the floor
    lda #PT_SPLAT
    sta pt_type,x
    lda #240
    sta pt_life,x
    lda #(SPR_DB_SPLAT | $2A00)
    sta pt_tile,x
    lda pt_y,x
    clc
    adc #(4*16)
    and #$FF00              ; floor top (tile aligned, 1/16 units)
    sec
    sbc #(4*16)
    sta pt_y,x
    bra @n
@bounce:
    lda pt_vy,x
    lsr
    lsr
    eor #$FFFF
    inc a
    sta pt_vy,x
    lda pt_vx,x
    cmp #$8000
    ror
    sta pt_vx,x
    ; settle
    lda pt_vy,x
    cmp #.loword(-8)
    bcc @n
    stz pt_vy,x
    stz pt_vx,x
    ; stop falling through: snap above the floor
    lda pt_y,x
    sec
    sbc #(2*16)
    sta pt_y,x
@n: inx
    inx
    cpx #MAX_PART*2
    bcs :+
    jmp @l
:   rts

pt_draw:
    ldx #0
@l: lda pt_type,x
    beq @n
    stx pt_cur
    ; old debris blinks before vanishing
    lda pt_life,x
    cmp #40
    bcs :+
    lda frame
    and #2
    bne @n2
:   lda pt_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_x
    ldy pt_big,x
    bne :+
    sec
    sbc #4
:   sta spr_x
    lda pt_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_y
    ldy pt_big,x
    bne :+
    sec
    sbc #4
:   sta spr_y
    lda pt_tile,x
    sta spr_t
    ; spinning smoke / sparks
    lda pt_type,x
    cmp #PT_SMOKE
    bne :+
    lda pt_life,x
    cmp #20
    bcs :+
    lda spr_t
    clc
    adc #(SPR_FX_SMOKE1 - SPR_FX_SMOKE0)
    sta spr_t
:   lda pt_big,x
    sta spr_big
    jsr spr_add
@n2:ldx pt_cur
@n: inx
    inx
    cpx #MAX_PART*2
    bcc @l
    rts

pt_clear:
    ldx #0
@l: stz pt_type,x
    inx
    inx
    cpx #MAX_PART*2
    bcc @l
    stz pt_next
    rts
