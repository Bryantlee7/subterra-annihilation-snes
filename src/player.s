; ---------------------------------------------------------------- player
; Positions are in 1/16 pixel units; p_px/p_py are whole pixels (feet center).

P_WALK     = 20
P_RUN      = 34
P_ACC      = 3
P_GRAV     = 5
P_GRAV_LO  = 3              ; while jump is held and rising
P_JUMP     = 88
P_MAXFALL  = 100
P_CLIMB    = 18
P_HALFW    = 4              ; hitbox x: px-5 .. px+4
P_TALL     = 30
P_SHORT    = 20             ; crouched
CROUCH_DY  = 8

PL_ATTR    = $2000          ; palette 0, priority 2

player_spawn:
    AXY16
    lda mission
    asl
    tax
    lda mis_start_x,x
    sta p_px
    asl
    asl
    asl
    asl
    sta p_x
    lda mis_start_y,x
    sta p_py
    asl
    asl
    asl
    asl
    sta p_y
    stz p_vx
    stz p_vy
    stz p_face
    stz p_climb
    stz p_crouch
    stz p_aim
    stz p_dead
    stz p_deadt
    stz p_inv
    stz p_dmg
    stz p_riding
    stz p_cool
    stz p_gcool
    stz p_flash
    stz p_ground
    stz p_drop
    stz p_win
    lda #100
    sta p_hp
    rts

; full ammo reset at the start of each mission
player_reset_ammo:
    lda #300
    sta p_ammo
    lda #6
    sta p_ammo+2
    lda #20
    sta p_ammo+4
    lda #4
    sta p_ammo+6
    lda #4
    sta p_ammo+8
    stz p_weapon
    rts

player_update:
    AXY16
    lda p_dead
    beq :+
    jmp player_dying
:   lda p_win
    beq :+
    rts
:   lda p_inv
    beq :+
    dec p_inv
:   lda p_cool
    beq :+
    dec p_cool
:   lda p_gcool
    beq :+
    dec p_gcool
:   lda p_flash
    beq :+
    dec p_flash
:   lda p_drop
    beq :+
    dec p_drop
:
    ; ---- weapon cycling
    lda joy_new
    and #JOY_R
    beq @nor
    lda p_weapon
    inc a
    cmp #5
    bcc :+
    lda #0
:   sta p_weapon
    lda #SND_SELECT
    jsr sfx
@nor:
    lda joy_new
    and #JOY_L
    beq @nol
    lda p_weapon
    dec a
    bpl :+
    lda #4
:   sta p_weapon
    lda #SND_SELECT
    jsr sfx
@nol:
    ; ---- facing
    lda joy
    and #JOY_LEFT
    beq :+
    lda #1
    sta p_face
:   lda joy
    and #JOY_RIGHT
    beq :+
    stz p_face
:
    ; ---- aim direction
    stz p_aim
    lda joy
    and #JOY_UP
    beq @noup
    lda #1
    sta p_aim
    lda joy
    and #(JOY_LEFT | JOY_RIGHT)
    beq @aimd
    lda #2
    sta p_aim
    bra @aimd
@noup:
    lda p_ground
    bne @aimd
    lda p_climb
    bne @aimd
    lda joy
    and #JOY_DOWN
    beq @aimd
    lda #3
    sta p_aim
@aimd:
    lda p_climb
    beq :+
    jmp player_climb
:
    ; ---- start climbing?
    lda joy
    and #JOY_UP
    beq @noclimbup
    lda p_px
    ldy p_py
    tya
    sec
    sbc #8
    tay
    lda p_px
    jsr attr_at
    and #AT_LADDER
    beq @noclimbup
    jmp climb_start
@noclimbup:
    lda joy
    and #JOY_DOWN
    beq @nocd
    lda p_ground
    beq @nocd
    lda joy
    and #(JOY_LEFT | JOY_RIGHT)
    bne @nocd
    ldy p_py
    lda p_px
    jsr attr_at
    and #AT_LADDER
    beq @nocd
    ; step down onto the ladder
    lda p_y
    clc
    adc #32
    sta p_y
    jmp climb_start
@nocd:
    ; ---- crouch
    stz p_crouch
    lda p_ground
    beq @nocrouch
    lda joy
    and #JOY_DOWN
    beq @nocrouch
    lda #1
    sta p_crouch
@nocrouch:
    ; ---- horizontal speed
    lda #P_WALK
    sta t0
    lda joy
    and #JOY_A
    beq :+
    lda #P_RUN
    sta t0
:   lda p_crouch
    beq :+
    stz t0
:   ; target velocity
    stz t1
    lda joy
    and #JOY_RIGHT
    beq :+
    lda t0
    sta t1
:   lda joy
    and #JOY_LEFT
    beq :+
    lda t0
    eor #$FFFF
    inc a
    sta t1
:   ; aiming straight up while standing stops you
    lda p_aim
    cmp #1
    bne :+
    lda p_ground
    beq :+
    stz t1
:   lda p_vx
    cmp t1
    beq @vxok
    bmi @acc
    sec
    sbc #P_ACC
    cmp t1
    bpl @vxset
    lda t1
    bra @vxset
@acc:
    clc
    adc #P_ACC
    cmp t1
    bmi @vxset
    lda t1
@vxset:
    sta p_vx
@vxok:
    ; ---- jump / drop through platforms
    lda joy_new
    and #JOY_B
    beq @nojump
    lda p_ground
    beq @nojump
    lda joy
    and #JOY_DOWN
    beq @jump
    ; down+jump on a one-way platform drops through
    ldy p_py
    lda p_px
    jsr attr_at
    and #(AT_PLATFORM | AT_SOLID)
    cmp #AT_PLATFORM
    bne @jump
    lda #10
    sta p_drop
    lda p_y
    clc
    adc #32
    sta p_y
    bra @nojump
@jump:
    lda #.loword(-P_JUMP)
    sta p_vy
    stz p_ground
    stz p_crouch
    stz p_riding
    lda #SND_JUMP
    jsr sfx
@nojump:
    ; ---- gravity
    lda #P_GRAV
    sta t0
    lda p_vy
    bpl :+
    lda joy
    and #JOY_B
    beq :+
    lda #P_GRAV_LO
    sta t0
:   lda p_vy
    clc
    adc t0
    cmp #P_MAXFALL
    bmi :+
    lda #P_MAXFALL
:   sta p_vy
    jsr player_move_x
    jsr player_move_y
    jmp player_common

; ---------------------------------------------------------------- climbing
climb_start:
    lda #1
    sta p_climb
    stz p_vx
    stz p_vy
    stz p_crouch
    stz p_riding
    ; snap to ladder column center
    lda p_px
    and #$FFF0
    ora #8
    sta p_px
    asl
    asl
    asl
    asl
    sta p_x
    jmp player_common

player_climb:
    stz p_vx
    stz p_vy
    ; jump off
    lda joy_new
    and #JOY_B
    beq @nojump
    stz p_climb
    lda #.loword(-48)
    sta p_vy
    jmp player_common
@nojump:
    ; step off sideways onto solid ground
    lda joy
    and #(JOY_LEFT | JOY_RIGHT)
    beq @noside
    ldy p_py
    lda p_px
    jsr attr_at
    and #(AT_SOLID | AT_PLATFORM)
    beq @noside
    stz p_climb
    jmp player_common
@noside:
    lda joy
    and #JOY_UP
    beq @noup
    ; is there ladder at the feet (the tile we stand in)?
    lda p_py
    dec a
    tay
    lda p_px
    jsr attr_at
    and #AT_LADDER
    bne @goup
    ; reached the top: stand on the ladder top
    lda p_py
    and #$FFF0
    sta p_py
    asl
    asl
    asl
    asl
    sta p_y
    stz p_climb
    lda #1
    sta p_ground
    jmp player_common
@goup:
    ; head room?
    lda p_py
    sec
    sbc #(P_TALL + 1)
    tay
    lda p_px
    jsr attr_at
    and #AT_SOLID
    bne @stay
    lda p_y
    sec
    sbc #P_CLIMB
    sta p_y
    inc p_animt
    bra @stay
@noup:
    lda joy
    and #JOY_DOWN
    beq @stay
    ldy p_py
    lda p_px
    jsr attr_at
    sta t0
    and #AT_LADDER
    bne @godown
    lda t0
    and #(AT_SOLID | AT_PLATFORM)
    beq @fall
    ; at the bottom
    stz p_climb
    lda #1
    sta p_ground
    jmp player_common
@fall:
    stz p_climb
    jmp player_common
@godown:
    lda p_y
    clc
    adc #P_CLIMB
    sta p_y
    inc p_animt
@stay:
    lda p_y
    lsr
    lsr
    lsr
    lsr
    sta p_py
    jmp player_common

; ---------------------------------------------------------------- collision
player_height:
    lda p_crouch
    beq :+
    lda #P_SHORT
    rts
:   lda #P_TALL
    rts

player_move_x:
    lda p_vx
    bne :+
    rts
:   clc
    adc p_x
    sta t2                  ; new x (1/16)
    lsr
    lsr
    lsr
    lsr
    sta t3                  ; new px
    lda p_vx
    bmi @left
    lda t3
    clc
    adc #P_HALFW
    bra @edge
@left:
    lda t3
    sec
    sbc #(P_HALFW + 1)
@edge:
    sta t4                  ; probe x
    ; probe three heights
    jsr player_height
    dec a
    sta t5
    lda p_py
    dec a
    tay
    lda t4
    jsr attr_at
    lsr
    bcs @blocked
    lda p_py
    sec
    sbc #14
    tay
    lda t4
    jsr attr_at
    lsr
    bcs @blocked
    lda p_py
    sec
    sbc t5
    tay
    lda t4
    jsr attr_at
    lsr
    bcs @blocked
    lda t2
    sta p_x
    lda t3
    sta p_px
    rts
@blocked:
    ; door?
    ldx last_mt
    lda mt_attr,x
    and #AT_DOOR
    beq :+
    jsr door_touch
:   lda p_vx
    bmi @bl
    lda t4
    and #$FFF0
    sec
    sbc #(P_HALFW + 1)
    bra @set
@bl:
    lda t4
    ora #$000F
    clc
    adc #(P_HALFW + 2)
@set:
    sta p_px
    asl
    asl
    asl
    asl
    ora #8
    sta p_x
    stz p_vx
    rts

player_move_y:
    lda p_vy
    bpl @down
    ; ---- rising
    clc
    adc p_y
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t3                  ; new py
    jsr player_height
    sta t5
    lda t3
    sec
    sbc t5
    sta t4                  ; head row
    tay
    lda p_px
    sec
    sbc #P_HALFW
    jsr attr_at
    lsr
    bcs @bump
    ldy t4
    lda p_px
    clc
    adc #(P_HALFW - 1)
    jsr attr_at
    lsr
    bcs @bump
    lda t2
    sta p_y
    lda t3
    sta p_py
    stz p_ground
    rts
@bump:
    lda t4
    ora #$000F
    inc a
    clc
    adc t5
    sta p_py
    asl
    asl
    asl
    asl
    sta p_y
    stz p_vy
    rts
@down:
    ; ---- falling / standing
    clc
    adc p_y
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t3                  ; new feet row
    ; elevators
    jsr elevator_check
    bcs @landed_elev
    stz p_riding
    lda t3
    and #$FFF0
    sta t6                  ; top of the tile under the feet
    ldy t3
    lda p_px
    sec
    sbc #P_HALFW
    jsr floor_test
    bcs @land
    ldy t3
    lda p_px
    clc
    adc #(P_HALFW - 1)
    jsr floor_test
    bcs @land
    lda t2
    sta p_y
    lda t3
    sta p_py
    stz p_ground
    rts
@land:
    lda t6
    sta p_py
    asl
    asl
    asl
    asl
    sta p_y
    lda p_ground
    bne :+
    lda p_vy
    cmp #60
    bcc :+
    lda #SND_LAND
    jsr sfx
:   stz p_vy
    lda #1
    sta p_ground
    rts
@landed_elev:
    stz p_vy
    lda #1
    sta p_ground
    rts

; A=x, Y=y. Carry set if the point supports the player's feet.
; Platforms only count if the feet were above them last frame.
floor_test:
    jsr attr_at
    lsr
    bcs @yes
    asl
    and #AT_PLATFORM
    beq @no
    lda p_drop
    bne @no
    lda p_py
    cmp t6
    beq @yes
    bcc @yes
@no:
    clc
    rts
@yes:
    sec
    rts

; ---------------------------------------------------------------- after move
player_common:
    lda p_y
    lsr
    lsr
    lsr
    lsr
    sta p_py
    lda p_x
    lsr
    lsr
    lsr
    lsr
    sta p_px
    ; animation timer
    lda p_vx
    beq :+
    inc p_animt
:
    ; ---- firing
    lda joy
    and #JOY_Y
    beq @nofire
    jsr player_fire
@nofire:
    lda joy_new
    and #JOY_X
    beq @nonade
    jsr player_throw
@nonade:
    ; ---- hazards (lasers, electric floors, slime)
    lda p_haz
    beq :+
    dec p_haz
:   lda p_py
    sec
    sbc #10
    tay
    lda p_px
    jsr attr_at
    and #AT_HAZARD
    bne @haz
    ldy p_py
    lda p_px
    jsr attr_at
    and #AT_HAZARD
    beq @nohaz
    lda last_mt
    cmp #MT_ELECTRIC        ; electric floor hurts when standing on it
    bne @nohaz
@haz:
    lda p_haz
    bne @nohaz
    lda #20
    sta p_haz
    lda #8
    jsr player_hurt
@nohaz:
    ; ---- exit
    lda p_py
    sec
    sbc #8
    tay
    lda p_px
    jsr attr_at
    and #AT_EXIT
    beq @noexit
    lda obj_left
    bne @locked
    jsr mission_complete
    bra @noexit
@locked:
    lda #msg_obj_first
    jsr show_msg
@noexit:
    rts

; Touching a door tile (last_idx/last_mt set by attr_at)
door_touch:
    lda last_mt
    cmp #MT_DOOR_KEY
    bne @nk
    lda has_key
    beq @needkey
    ldx last_idx
    jsr open_door_at
    lda #msg_unlocked
    jmp show_msg
@needkey:
    lda #msg_need_key
    jmp show_msg
@nk:
    cmp #MT_DOOR_EMP
    bne @ne
    lda #msg_need_emp
    jmp show_msg
@ne:
    lda #msg_obj_first
    jmp show_msg

; A = damage
player_hurt:
    sta t0
    lda p_dead
    ora p_win
    bne @x
    lda p_inv
    bne @x
    lda p_hp
    sec
    sbc t0
    bpl :+
    lda #0
:   sta p_hp
    lda #50
    sta p_inv
    lda #4
    sta shake
    lda #SND_HURT
    jsr sfx
    ; sparks / blood at the torso
    lda p_px
    sta t0
    lda p_py
    sec
    sbc #18
    sta t1
    jsr fx_hit_human
    lda p_hp
    bne :+
    jmp player_die
:   jsr player_armor_damage
@x: rts

; Visual-only armor damage at health thresholds
player_armor_damage:
    lda p_dmg
    bne :+
    lda p_hp
    cmp #75
    bcs @x
    lda #1
    sta p_dmg
    ; shoulder plate flies off
    lda #(SPR_DB_METAL0 | $2A00)
    ldx #0
    jsr player_debris
    rts
:   cmp #1
    bne :+
    lda p_hp
    cmp #50
    bcs @x
    lda #2
    sta p_dmg
    lda #(SPR_DB_METAL1 | $2A00)
    ldx #10
    jsr player_debris
    rts
:   cmp #2
    bne @x
    lda p_hp
    cmp #25
    bcs @x
    lda #3
    sta p_dmg
    lda #(SPR_PL_BACKARM | PL_ATTR)
    ldx #6
    jsr player_debris
    lda gore
    beq @x
    lda p_px
    sta t0
    lda p_py
    sec
    sbc #20
    sta t1
    jsr fx_blood_burst
@x: rts

; spawn a small debris piece from the player. A = tile|attr, X = y offset up
player_debris:
    sta t2
    stx t3
    lda p_px
    sta t0
    lda p_py
    sec
    sbc #22
    clc
    adc t3
    sta t1
    lda #0
    sta t3                  ; small sprite
    jsr fx_debris
    rts

player_die:
    lda #1
    sta p_dead
    stz p_deadt
    lda #20
    sta shake
    lda #SND_DIE
    jsr sfx
    ; burst into pieces
    lda p_px
    sta t0
    lda p_py
    sec
    sbc #8
    sta t1
    lda #(SPR_PL_LEGS_STAND | PL_ATTR)
    sta t2
    lda #2
    sta t3
    jsr fx_debris
    lda p_py
    sec
    sbc #20
    sta t1
    lda #(SPR_PL_TORSO | PL_ATTR)
    sta t2
    jsr fx_debris
    lda #(SPR_PL_ARM0 | PL_ATTR)
    sta t2
    jsr fx_debris
    lda p_py
    sec
    sbc #30
    sta t1
    lda #(SPR_PL_HEAD | PL_ATTR)
    sta t2
    stz t3
    jsr fx_debris
    lda gore
    beq :+
    lda p_py
    sec
    sbc #16
    sta t1
    jsr fx_blood_burst
    jsr fx_blood_burst
:   lda p_py
    sec
    sbc #16
    sta t1
    jsr fx_explosion_small
    rts

player_dying:
    inc p_deadt
    lda p_deadt
    cmp #150
    bcc :+
    lda #ST_FAILED
    sta next_state
:   rts

; ---------------------------------------------------------------- drawing
player_draw:
    AXY16
    lda p_dead
    beq :+
    rts
:   lda p_inv
    and #4
    beq :+
    rts
:   lda p_px
    sec
    sbc cam_x
    sta t8                  ; screen x
    lda p_py
    sec
    sbc cam_y
    sta t9                  ; screen y
    lda p_crouch
    beq :+
    lda #CROUCH_DY
:   sta t10                 ; upper body drop
    lda p_face
    beq :+
    lda #$4000
:   ora #PL_ATTR
    sta t11                 ; attr flags
    ; ---- muzzle flash
    lda p_flash
    beq @noflash
    ldx p_aim
    txa
    asl
    tax
    lda pl_arm_mx,x
    sta t0
    lda pl_arm_my,x
    clc
    adc t10
    sec
    sbc #4
    clc
    adc t9
    sta spr_y
    lda p_face
    beq :+
    lda t0
    eor #$FFFF
    inc a
    sta t0
:   lda t0
    clc
    adc t8
    sec
    sbc #4
    sta spr_x
    lda frame
    and #1
    beq :+
    lda #(SPR_FX_MUZZLE1 - SPR_FX_MUZZLE0)
:   clc
    adc #SPR_FX_MUZZLE0
    ora #$2800              ; palette 4
    sta spr_t
    lda t11
    and #$4000
    ora spr_t
    sta spr_t
    stz spr_big
    jsr spr_add
@noflash:
    ; ---- gun arm (hidden while climbing)
    lda p_climb
    bne @noarm
    lda p_aim
    asl
    tax
    lda pl_arm_ox,x
    sta t0
    lda pl_arm_oy,x
    clc
    adc t10
    sta t1
    lda pl_arm_tiles,x
    sta t2
    lda #16
    jsr draw_part
@noarm:
    ; ---- head
    lda #.loword(-3)
    sta t0
    lda #.loword(-32)
    clc
    adc t10
    sta t1
    lda #SPR_PL_HEAD
    ldx p_dmg
    cpx #2
    bcc :+
    lda #SPR_PL_HEAD_DMG
:   sta t2
    lda #8
    jsr draw_part
    ; ---- torso
    lda #.loword(-8)
    sta t0
    lda #.loword(-26)
    clc
    adc t10
    sta t1
    lda #SPR_PL_TORSO
    ldx p_dmg
    beq :+
    lda #SPR_PL_TORSO_DMG
:   sta t2
    lda #16
    jsr draw_part
    ; ---- back arm (lost at the last damage stage)
    lda p_dmg
    cmp #3
    bcs @nobk
    lda #.loword(-8)
    sta t0
    lda #.loword(-23)
    clc
    adc t10
    sta t1
    lda #SPR_PL_BACKARM
    sta t2
    lda #8
    jsr draw_part
@nobk:
    ; ---- legs
    jsr player_leg_frame
    sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda #16
    jsr draw_part
    rts

player_leg_frame:
    lda p_climb
    beq @nc
    lda p_animt
    and #8
    beq :+
    lda #SPR_PL_LEGS_CLIMB2
    rts
:   lda #SPR_PL_LEGS_CLIMB1
    rts
@nc:lda p_ground
    bne @g
    lda #SPR_PL_LEGS_JUMP
    rts
@g: lda p_crouch
    beq :+
    lda #SPR_PL_LEGS_CROUCH
    rts
:   lda p_vx
    bne :+
    lda #SPR_PL_LEGS_STAND
    rts
:   lda p_animt
    lsr
    lsr
    lsr
    and #3
    asl
    tax
    lda pl_walk_tiles,x
    rts

pl_walk_tiles: .word SPR_PL_LEGS_WALK1, SPR_PL_LEGS_WALK2, SPR_PL_LEGS_WALK3, SPR_PL_LEGS_WALK4
pl_arm_tiles:  .word SPR_PL_ARM0, SPR_PL_ARM1, SPR_PL_ARM2, SPR_PL_ARM3
pl_arm_ox: .word PL_ARM_OX
pl_arm_oy: .word PL_ARM_OY
pl_arm_mx: .word PL_ARM_MX
pl_arm_my: .word PL_ARM_MY

; Draw one sprite part relative to an origin.
; t8/t9 = origin (screen), t0/t1 = offset (facing right), t2 = tile,
; t11 = attr (hflip bit $4000 mirrors the offset), A = size (8 or 16)
draw_part:
    sta t3
    lda t11
    and #$4000
    beq @r
    ; mirrored: x = -dx - size
    lda t0
    eor #$FFFF
    inc a
    sec
    sbc t3
    bra @x
@r: lda t0
@x: clc
    adc t8
    sta spr_x
    lda t1
    clc
    adc t9
    sta spr_y
    lda t2
    ora t11
    sta spr_t
    lda t3
    cmp #16
    beq :+
    stz spr_big
    jmp spr_add
:   lda #2
    sta spr_big
    jmp spr_add
