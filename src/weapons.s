; ---------------------------------------------------------------- weapons
; Weapon ids: 0 machine gun, 1 grenades, 2 plasma rifle, 3 EMP, 4 railgun

PB_MG      = 1
PB_PLASMA  = 2
PB_EMP     = 3
PB_GRENADE = 4

EB_BULLET  = 1
EB_PLASMA  = 2
EB_SHOT    = 3

; damage kinds passed to actor_damage (t-var dmg_kind)
DK_BULLET  = 0
DK_PLASMA  = 1
DK_EMP     = 2
DK_BLAST   = 3
DK_RAIL    = 4

; velocity tables per aim (fwd, up, diag up, diag down), facing right
mg_vx:     .word 128, 0, 92, 92
mg_vy:     .word 0, .loword(-128), .loword(-92), 92
pl_vx:     .word 88, 0, 62, 62
pl_vy:     .word 0, .loword(-88), .loword(-62), 62
emp_vx:    .word 64, 0, 46, 46
emp_vy:    .word 0, .loword(-64), .loword(-46), 46
nade_vx:   .word 44, 10, 38, 50
nade_vy:   .word .loword(-52), .loword(-84), .loword(-70), .loword(-20)
rail_dx:   .word 8, 0, 6, 6
rail_dy:   .word 0, .loword(-8), .loword(-6), 6

; muzzle world position -> t0 (x px), t1 (y px)
player_muzzle:
    lda p_aim
    asl
    tax
    lda pl_arm_mx,x
    ldy p_face
    beq :+
    eor #$FFFF
    inc a
:   clc
    adc p_px
    sta t0
    lda pl_arm_my,x
    clc
    adc p_py
    ldy p_crouch
    beq :+
    clc
    adc #CROUCH_DY
:   sta t1
    rts

; velocity from table at X-relative pointer: A=vx (facing applied), t3=vy
; usage: ldx aim*2, then lda tbl_vx,x / tbl_vy,x manually (see callers)

player_fire:
    lda p_cool
    beq :+
    rts
:   lda p_climb
    beq :+
    lda p_aim           ; on ladders only sideways fire
    beq :+
    rts
:   lda p_weapon
    asl
    tax
    jmp (fire_tbl,x)
fire_tbl: .addr fire_mg, fire_nade, fire_plasma, fire_emp, fire_rail

fire_mg:
    lda p_ammo
    beq @empty
    dec p_ammo
    lda #5
    sta p_cool
    bra @go
@empty:
    lda #14             ; sidearm: slower but never runs dry
    sta p_cool
@go:
    jsr pb_alloc
    bcc @x
    lda #PB_MG
    sta pb_type,x
    lda #26
    sta pb_life,x
    lda #.loword(mg_vx)
    sta t4
    lda #.loword(mg_vy)
    sta t5
    jsr pb_launch
    ; a little spread
    jsr random
    and #15
    sec
    sbc #8
    ldy p_aim
    cpy #1
    beq @vert
    clc
    adc pb_vy,x
    sta pb_vy,x
    bra @snd
@vert:
    clc
    adc pb_vx,x
    sta pb_vx,x
@snd:
    lda #SND_SHOT
    jsr sfx
@x: rts

; generic: X = projectile slot; tables in t4 (vx table ptr) t5 (vy table ptr)
pb_launch:
    phx
    jsr player_muzzle
    plx
    lda t0
    asl
    asl
    asl
    asl
    sta pb_x,x
    lda t1
    asl
    asl
    asl
    asl
    sta pb_y,x
    lda p_aim
    asl
    tay
    lda (t4),y
    pha
    lda (t5),y
    sta pb_vy,x
    pla
    ldy p_face
    beq :+
    eor #$FFFF
    inc a
:   sta pb_vx,x
    lda #3
    sta p_flash
    rts

pb_alloc:
    ldx #0
@l: lda pb_type,x
    beq @found
    inx
    inx
    cpx #MAX_PB*2
    bcc @l
    clc
    rts
@found:
    sec
    rts

fire_nade:
    jmp player_throw

fire_plasma:
    lda p_ammo+4
    bne :+
    jmp dry_fire
:   dec p_ammo+4
    lda #18
    sta p_cool
    jsr pb_alloc
    bcc @x
    lda #PB_PLASMA
    sta pb_type,x
    lda #60
    sta pb_life,x
    lda #.loword(pl_vx)
    sta t4
    lda #.loword(pl_vy)
    sta t5
    jsr pb_launch
    lda #SND_PLASMA
    jsr sfx
@x: rts

fire_emp:
    lda p_ammo+6
    bne :+
    jmp dry_fire
:   dec p_ammo+6
    lda #30
    sta p_cool
    jsr pb_alloc
    bcc @x
    lda #PB_EMP
    sta pb_type,x
    lda #70
    sta pb_life,x
    lda #.loword(emp_vx)
    sta t4
    lda #.loword(emp_vy)
    sta t5
    jsr pb_launch
    lda #SND_EMPFIRE
    jsr sfx
@x: rts

fire_rail:
    lda p_ammo+8
    bne :+
    jmp dry_fire
:   dec p_ammo+8
    lda #45
    sta p_cool
    lda #SND_RAIL
    jsr sfx
    lda #4
    sta p_flash
    lda #3
    sta shake
    jmp rail_trace

dry_fire:
    lda #20
    sta p_cool
    lda #SND_CLICK
    jsr sfx
    lda #msg_no_ammo
    jsr show_msg
    rts

player_throw:
    lda p_gcool
    bne @x
    lda p_ammo+2
    beq @dry
    jsr pb_alloc
    bcc @x
    dec p_ammo+2
    lda #24
    sta p_gcool
    lda #PB_GRENADE
    sta pb_type,x
    lda #80
    sta pb_life,x
    lda #.loword(nade_vx)
    sta t4
    lda #.loword(nade_vy)
    sta t5
    jsr pb_launch
    stz p_flash
    ; add some of the player's own momentum
    lda p_vx
    cmp #$8000
    ror
    clc
    adc pb_vx,x
    sta pb_vx,x
    lda #SND_THROW
    jsr sfx
@x: rts
@dry:
    lda p_gcool
    bne @x
    lda #20
    sta p_gcool
    lda #SND_CLICK
    jsr sfx
    rts

; ---------------------------------------------------------------- update
pb_update:
    jsr hitboxes_build
    ldx #0
@loop:
    stx cur
    lda pb_type,x
    bne :+
    jmp @next
:
    dec pb_life,x
    bne :+
    lda pb_type,x
    cmp #PB_GRENADE
    bne @kill
    jmp @explode
@kill:
    stz pb_type,x
    jmp @next
:   lda pb_type,x
    cmp #PB_GRENADE
    bne :+
    jmp @grenade
:   ; ---- straight shots
    lda pb_x,x
    clc
    adc pb_vx,x
    sta pb_x,x
    lsr
    lsr
    lsr
    lsr
    sta t8
    lda pb_y,x
    clc
    adc pb_vy,x
    sta pb_y,x
    lsr
    lsr
    lsr
    lsr
    sta t9
    ; off the map?
    lda t8
    cmp #MAP_W_PX
    bcs @kill2
    lda t9
    cmp #MAP_H_PX
    bcs @kill2
    ; EMP vs lasers (non-solid but EMP-able)
    lda pb_type,x
    cmp #PB_EMP
    bne @nolaser
    ldy t9
    lda t8
    jsr emp_tile
    bcc @nolaser
    ldx cur
    lda t8
    sta t0
    lda t9
    sta t1
    jsr fx_emp_burst
    ldx cur
    bra @kill2
@nolaser:
    ldy t9
    lda t8
    jsr attr_at
    lsr
    bcc @air
    ; hit a wall
    ldx cur
    lda t8
    sta t0
    lda t9
    sta t1
    lda pb_type,x
    cmp #PB_PLASMA
    bne :+
    ldy t9
    lda t8
    jsr break_at
    jsr fx_explosion_small
    lda #SND_HIT
    jsr sfx
    bra @kill2
:   cmp #PB_EMP
    bne :+
    jsr fx_emp_burst
    bra @kill2
:   jsr fx_spark
@kill2:
    ldx cur
    stz pb_type,x
    jmp @next
@air:
    ; actors
    ldx cur
    lda pb_type,x
    asl
    tay
    lda pb_dmg_tbl,y
    sta hit_dmg
    lda pb_kind_tbl,y
    sta hit_kind
    lda pb_vx,x
    sta hit_vx
    ldy t9
    lda t8
    jsr actor_hit_point
    bcs @lb393_1
    jmp @next
@lb393_1:
    ldx cur
    stz pb_type,x
    jmp @next

@grenade:
    ; gravity
    lda pb_vy,x
    clc
    adc #4
    cmp #100
    bmi :+
    lda #100
:   sta pb_vy,x
    ; x move with bounce
    lda pb_x,x
    clc
    adc pb_vx,x
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t8
    lda pb_y,x
    lsr
    lsr
    lsr
    lsr
    sta t9
    ldy t9
    lda t8
    jsr solid_at
    ldx cur
    bcc @gx
    lda pb_vx,x
    eor #$FFFF
    inc a
    cmp #$8000
    ror
    sta pb_vx,x
    lda #SND_BOUNCE
    jsr sfx
    ldx cur
    bra @gy
@gx:
    lda t2
    sta pb_x,x
@gy:
    lda pb_y,x
    clc
    adc pb_vy,x
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t9
    lda pb_x,x
    lsr
    lsr
    lsr
    lsr
    sta t8
    ldy t9
    lda t8
    jsr attr_at
    ldx cur
    and #(AT_SOLID | AT_PLATFORM)
    beq @gyok
    lda pb_vy,x
    bmi @gceil
    ; bounce off the floor
    cmp #24
    bcs :+
    stz pb_vy,x
    ; friction
    lda pb_vx,x
    cmp #$8000
    ror
    sta pb_vx,x
    bra @gdone
:   lsr
    eor #$FFFF
    inc a
    sta pb_vy,x
    lda pb_vx,x
    cmp #$8000
    ror
    sta pb_vx,x
    lda #SND_BOUNCE
    jsr sfx
    ldx cur
    bra @gdone
@gceil:
    stz pb_vy,x
    bra @gdone
@gyok:
    lda t2
    sta pb_y,x
@gdone:
    ; touching an enemy blows it up early
    lda pb_x,x
    lsr
    lsr
    lsr
    lsr
    sta t8
    lda pb_y,x
    lsr
    lsr
    lsr
    lsr
    sta t9
    stz hit_dmg
    ldy t9
    lda t8
    jsr actor_touch_point
    bcc @next
@explode:
    ldx cur
    stz pb_type,x
    lda pb_x,x
    lsr
    lsr
    lsr
    lsr
    sta t3
    lda pb_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc #4
    sta t4
    jsr explode
@next:
    ldx cur
    inx
    inx
    cpx #MAX_PB*2
    bcs :+
    jmp @loop
:   rts

pb_dmg_tbl:  .word 0, 1, 5, 1, 0
pb_kind_tbl: .word 0, DK_BULLET, DK_PLASMA, DK_EMP, DK_BLAST

; Grenade explosion at t3/t4 (px)
explode:
    lda t3
    sta t0
    lda t4
    sta t1
    jsr fx_explosion
    lda #12
    sta shake
    lda #SND_BOOM
    jsr sfx
    ; damage everything within ~36px
    lda t3
    sta blast_x
    lda t4
    sta blast_y
    jsr actors_blast
    ; carve the terrain (crater reads blast_x / blast_y)
    jsr crater
    rts

; ---------------------------------------------------------------- railgun
; Hitscan beam from the muzzle; pierces enemies and up to 2 soft tiles.
rail_trace:
    jsr player_muzzle
    lda t0
    sta rail_x
    lda t1
    sta rail_y
    lda p_aim
    asl
    tax
    lda rail_dy,x
    sta rail_dy_v
    lda rail_dx,x
    ldy p_face
    beq :+
    eor #$FFFF
    inc a
:   sta rail_dx_v
    stz a_hitmask
    stz a_hitmask+2
    lda #2
    sta rail_soft           ; soft tiles it can punch through
    lda #44
    sta rail_steps          ; steps (8px each)
@step:
    lda rail_x
    clc
    adc rail_dx_v
    sta rail_x
    lda rail_y
    clc
    adc rail_dy_v
    sta rail_y
    ; wall?
    ldy rail_y
    lda rail_x
    jsr attr_at
    lsr
    bcc @open
    lsr
    bcc @stop               ; not destructible
    lda rail_soft
    beq @stop
    dec rail_soft
    ldy rail_y
    lda rail_x
    jsr break_at
    ldy rail_y
    lda rail_x
    jsr break_at
    lda rail_x
    sta t0
    lda rail_y
    sta t1
    jsr fx_rock_chunk
@open:
    ; beam segment every other step
    lda rail_steps
    and #1
    bne :+
    lda rail_x
    sta t0
    lda rail_y
    sta t1
    jsr fx_beam
:   lda #12
    sta hit_dmg
    lda #DK_RAIL
    sta hit_kind
    lda rail_dx_v
    sta hit_vx
    ldy rail_y
    lda rail_x
    jsr actor_rail_point
    dec rail_steps
    bne @step
@stop:
    lda rail_x
    sta t0
    lda rail_y
    sta t1
    jsr fx_spark
    rts

; ---------------------------------------------------------------- drawing
pb_draw:
    ldx #0
@l: lda pb_type,x
    beq @n
    stx cur
    lda pb_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_x
    sec
    sbc #4
    sta spr_x
    lda pb_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_y
    sec
    sbc #4
    sta spr_y
    stz spr_big
    lda pb_type,x
    asl
    tay
    lda frame
    and #4
    beq :+
    lda pb_tile2,y
    bra :++
:   lda pb_tile1,y
:   sta spr_t
    jsr spr_add
    ldx cur
@n: inx
    inx
    cpx #MAX_PB*2
    bcc @l
    rts

pb_tile1: .word 0, SPR_FX_BULLET | $2800, SPR_FX_PLASMA0 | $2800, SPR_FX_EMP0 | $2800, SPR_FX_GRENADE0 | $2A00
pb_tile2: .word 0, SPR_FX_BULLET | $2800, SPR_FX_PLASMA1 | $2800, SPR_FX_EMP1 | $2800, SPR_FX_GRENADE1 | $2A00

; ---------------------------------------------------------------- enemy shots
; Spawn: t0/t1 = position px, t2/t3 = velocity (1/16), A = type
eb_spawn:
    sta t4
    ldx #0
@l: lda eb_type,x
    beq @f
    inx
    inx
    cpx #MAX_EB*2
    bcc @l
    rts
@f: lda t4
    sta eb_type,x
    lda t0
    asl
    asl
    asl
    asl
    sta eb_x,x
    lda t1
    asl
    asl
    asl
    asl
    sta eb_y,x
    lda t2
    sta eb_vx,x
    lda t3
    sta eb_vy,x
    lda #120
    sta eb_life,x
    rts

eb_update:
    ldx #0
@l: stx cur
    lda eb_type,x
    bne :+
    jmp @n
:
    dec eb_life,x
    beq @kill
    lda eb_x,x
    clc
    adc eb_vx,x
    sta eb_x,x
    lsr
    lsr
    lsr
    lsr
    sta t8
    lda eb_y,x
    clc
    adc eb_vy,x
    sta eb_y,x
    lsr
    lsr
    lsr
    lsr
    sta t9
    ldy t9
    lda t8
    jsr solid_at
    bcc @air
    lda t8
    sta t0
    lda t9
    sta t1
    jsr fx_spark
    bra @kill
@air:
    ; hit the player? box px-5..px+4, py-h..py-1
    lda p_dead
    bne @n
    lda t8
    sec
    sbc p_px
    clc
    adc #6
    cmp #12
    bcs @n
    jsr player_height
    sta t2
    lda p_py
    sec
    sbc t9
    beq @n
    bmi @n
    cmp t2
    bcs @n
    ldx cur
    lda eb_type,x
    asl
    tay
    lda eb_dmg_tbl,y
    jsr player_hurt
@kill:
    ldx cur
    stz eb_type,x
@n: ldx cur
    inx
    inx
    cpx #MAX_EB*2
    bcs :+
    jmp @l
:   rts

eb_dmg_tbl: .word 0, 8, 14, 6

eb_draw:
    ldx #0
@l: lda eb_type,x
    beq @n
    stx cur
    lda eb_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_x
    sec
    sbc #4
    sta spr_x
    lda eb_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_y
    sec
    sbc #4
    sta spr_y
    stz spr_big
    lda eb_type,x
    asl
    tay
    lda eb_tile,y
    sta spr_t
    jsr spr_add
    ldx cur
@n: inx
    inx
    cpx #MAX_EB*2
    bcc @l
    rts

eb_tile: .word 0, SPR_FX_EBULLET | $2800, SPR_FX_EPLASMA | $2800, SPR_FX_EBULLET | $2800

; Fire an enemy shot from (t0,t1) toward the player. A = type, t6 = speed
; (1/16 px per frame). Uses an 8-direction-ish approximation.
eb_aimed:
    pha
    lda p_px
    sec
    sbc t0
    sta t2                  ; dx
    lda p_py
    sec
    sbc #16
    sec
    sbc t1
    sta t3                  ; dy
    jsr aim_vector          ; -> t2, t3 scaled to t6
    pla
    jmp eb_spawn

; t2 = dx, t3 = dy (pixels) -> t2/t3 = velocity of magnitude ~t6
; Picks among 16 directions by comparing |dx| and |dy|.
aim_vector:
    lda t2
    bpl :+
    eor #$FFFF
    inc a
:   sta t4                  ; |dx|
    lda t3
    bpl :+
    eor #$FFFF
    inc a
:   sta t5                  ; |dy|
    ; ratio classes: dy*4 < dx -> (1,0); dy*2 < dx -> (0.92,0.38);
    ; dy < dx*2 -> (0.71,0.71) region split; else mostly vertical
    lda t5
    asl
    asl
    cmp t4
    bcs :+
    ldx #0
    bra @have
:   lda t5
    asl
    cmp t4
    bcs :+
    ldx #2
    bra @have
:   lda t4
    asl
    asl
    cmp t5
    bcs :+
    ldx #8
    bra @have
:   lda t4
    asl
    cmp t5
    bcs :+
    ldx #6
    bra @have
:   ldx #4
@have:
    ; components as fractions of 256
    lda dir_cx,x
    sta t4
    lda dir_cy,x
    sta t5
    ; scale by speed: comp * speed / 256
    lda t6
    A8
    sta WRMPYA
    lda t4
    sta WRMPYB
    A16
    nop
    nop
    nop
    nop
    lda RDMPYL
    xba
    and #$00FF
    ldy t2
    bpl :+
    eor #$FFFF
    inc a
:   sta t2
    lda t6
    A8
    sta WRMPYA
    lda t5
    sta WRMPYB
    A16
    nop
    nop
    nop
    nop
    lda RDMPYL
    xba
    and #$00FF
    ldy t3
    bpl :+
    eor #$FFFF
    inc a
:   sta t3
    rts

dir_cx: .word 255, 236, 181, 98, 0
dir_cy: .word 0, 98, 181, 236, 255
