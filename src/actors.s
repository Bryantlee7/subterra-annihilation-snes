; ---------------------------------------------------------------- actors
; Enemies and interactive objects. Struct-of-arrays, X = slot*2.

F_LEFT    = $0001
F_GROUND  = $0002
F_ALERT   = $0004
F_ROBOT   = $0008
F_ARMOR   = $0010
F_FLY     = $0020
F_DYING   = $0040
F_SHOOT   = $0080       ; can be hit by weapons
F_HUMAN   = $0100
F_HOSTILE = $0200
F_STAY    = $0400       ; never despawns
F_DONE    = $0800       ; objective object already used/destroyed

PART_HEAD = 1
PART_ARM  = 2
PART_LEGS = 4
PART_TOP  = 8

EN_DEAD    = 1
EN_SPAWNED = 2
EN_DONE    = 4

AS_PATROL = 0
AS_ATTACK = 1
AS_FLEE   = 2

; ---- per-type tables (index = type*2)
;              -    GUARD SOLD DEF  CRAWL DRONE SEC  HEAVY BOSS CMDR CAPT FRND GEN  TERM ELEV
at_hp:   .word 0,   5,    7,   9,   3,    3,    10,  50,   190, 26,  1,   1,   24,  1,   1
at_hw:   .word 0,   5,    5,   5,   7,    7,    5,   13,   13,  5,   5,   5,   7,   7,   16
at_h:    .word 0,   30,   30,  30,  11,   12,   30,  30,   30,  30,  30,  30,  32,  30,  6
at_spd:  .word 0,   10,   14,  0,   12,   14,   10,  6,    8,   14,  0,   0,   0,   0,   0
at_rate: .word 0,   80,   50,  60,  0,    90,   60,  110,  70,  32,  0,   0,   0,   0,   0
at_attr: .word 0,   $2200,$2400,$2400,$2600,$2600,$2600,$2600,$2600,$2400,$2E00,$2E00,$2600,$2600,$2600
at_flag: .word 0
    .word F_SHOOT|F_HUMAN|F_HOSTILE                 ; guard
    .word F_SHOOT|F_HUMAN|F_HOSTILE                 ; soldier
    .word F_SHOOT|F_HUMAN|F_HOSTILE                 ; defender
    .word F_SHOOT|F_ROBOT|F_HOSTILE                 ; crawler
    .word F_SHOOT|F_ROBOT|F_HOSTILE|F_FLY           ; drone
    .word F_SHOOT|F_ROBOT|F_HOSTILE|F_ARMOR         ; security robot
    .word F_SHOOT|F_ROBOT|F_HOSTILE|F_ARMOR         ; heavy
    .word F_SHOOT|F_ROBOT|F_HOSTILE|F_ARMOR|F_STAY  ; boss
    .word F_SHOOT|F_HUMAN|F_HOSTILE|F_STAY          ; commander
    .word F_HUMAN                                   ; captive
    .word F_HUMAN|F_STAY                            ; friend
    .word F_SHOOT|F_ROBOT                           ; generator
    .word F_SHOOT|F_ROBOT                           ; terminal
    .word F_STAY                                    ; elevator
at_parts:.word 0,   7,    7,   7,   PART_TOP, PART_TOP, 7, PART_ARM|PART_LEGS, PART_ARM|PART_LEGS, 7, 7, 7, 0, 0, 0
at_ai:   .addr ai_none, ai_human, ai_human, ai_human, ai_crawler, ai_drone, ai_human, ai_heavy, ai_heavy, ai_human
         .addr ai_captive, ai_friend, ai_generator, ai_terminal, ai_elevator
at_draw: .addr draw_none, draw_human, draw_human, draw_human, draw_crawler, draw_drone, draw_human, draw_heavy, draw_heavy, draw_human
         .addr draw_human, draw_human, draw_generator, draw_terminal, draw_elevator
at_head: .word 0, SPR_HU_HEAD_GUARD, SPR_HU_HEAD_SOLDIER, SPR_HU_HEAD_SOLDIER, 0, 0, SPR_RB_HEAD, 0, 0, SPR_HU_HEAD_BERET, SPR_HU_HEAD_CAPTIVE, SPR_HU_HEAD_FRIEND, 0, 0, 0

; ---------------------------------------------------------------- spawning
actors_clear:
    ldx #0
@l: stz a_type,x
    inx
    inx
    cpx #MAX_ACT*2
    bcc @l
    ldx #0
@p: stz pb_type,x
    inx
    inx
    cpx #MAX_PB*2
    bcc @p
    ldx #0
@e: stz eb_type,x
    inx
    inx
    cpx #MAX_EB*2
    bcc @e
    stz spawn_rr
    rts

; Look at a few entity-list entries per frame and spawn the ones near the camera
actors_spawn_scan:
    lda #10
    sta t10
@lp:
    ldx spawn_rr
    inx
    inx
    cpx #MAX_ENT*2
    bcc :+
    ldx #0
:   stx spawn_rr
    lda en_type,x
    beq @next
    cmp #16
    bcs @next               ; pickups are handled separately
    lda en_flags,x
    and #(EN_DEAD | EN_SPAWNED)
    bne @next
    ; inside the spawn window?
    lda en_x,x
    sec
    sbc cam_x
    clc
    adc #80
    cmp #(256 + 160)
    bcs @next
    lda en_y,x
    sec
    sbc cam_y
    clc
    adc #64
    cmp #(224 + 128)
    bcs @next
    jsr actor_spawn
@next:
    dec t10
    bne @lp
    rts

; spawn entity X (index*2) into a free actor slot
actor_spawn:
    stx t11
    ldy #0
@f: lda a_type,y
    beq @found
    iny
    iny
    cpy #MAX_ACT*2
    bcc @f
    rts
@found:
    lda en_flags,x
    ora #EN_SPAWNED
    sta en_flags,x
    lda en_type,x
    sta a_type,y
    lda en_x,x
    asl
    asl
    asl
    asl
    sta a_x,y
    lda en_y,x
    asl
    asl
    asl
    asl
    sta a_y,y
    lda en_param,x
    sta a_aux,y
    txa
    sta a_ent,y
    lda en_flags,x
    sta t0
    tyx                     ; X = actor slot
    lda a_type,x
    asl
    tay
    lda at_hp,y
    sta a_hp,x
    lda at_flag,y
    sta a_flags,x
    lda at_parts,y
    sta a_parts,x
    lda at_rate,y
    sta a_cool,x
    stz a_vx,x
    stz a_vy,x
    stz a_state,x
    stz a_timer,x
    stz a_stun,x
    stz a_hurt,x
    stz a_anim,x
    stz a_aux2,x
    lda #3
    sta a_lh,x
    lda #4
    sta a_la,x
    lda #5
    sta a_ll,x
    ; already-used objective objects come back in their finished state
    lda t0
    and #EN_DONE
    beq :+
    lda a_flags,x
    ora #F_DONE
    and #.loword(~F_SHOOT)
    sta a_flags,x
:   ; random initial facing / timer
    jsr random
    and #F_LEFT
    ora a_flags,x
    sta a_flags,x
    jsr random
    and #127
    sta a_timer,x
    ; elevators remember their bottom position (a_aux = travel in tiles)
    lda a_type,x
    cmp #ET_ELEVATOR
    bne :+
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta a_aux2,x            ; bottom y px
:   rts

; free slot X; entity returns to the list (not dead)
actor_despawn:
    ldy a_ent,x
    lda en_flags,y
    and #.loword(~EN_SPAWNED)
    sta en_flags,y
    stz a_type,x
    rts

; ---------------------------------------------------------------- main update
actors_update:
    ldx #0
@loop:
    stx cur
    lda a_type,x
    bne :+
    jmp @next
:
    ; despawn when far from the camera
    lda a_flags,x
    and #F_STAY
    bne @keep
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_x
    clc
    adc #192
    cmp #(256 + 384)
    bcs @far
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_y
    clc
    adc #160
    cmp #(224 + 320)
    bcc @keep
@far:
    jsr actor_despawn
    jmp @next
@keep:
    ; off-screen enemies wait until they scroll into view
    lda a_flags,x
    and #F_STAY
    bne @awake
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_x
    clc
    adc #32
    cmp #(256 + 64)
    bcc :+
    jmp @next
:   lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_y
    clc
    adc #24
    cmp #(224 + 64)
    bcc @awake
    jmp @next
@awake:
    lda a_hurt,x
    beq :+
    dec a_hurt,x
:   ; dying (no-gore deaths blink out)
    lda a_flags,x
    and #F_DYING
    beq @alive
    dec a_timer,x
    bne :+
    stz a_type,x
:   jmp @next
@alive:
    lda a_stun,x
    beq @nostun
    dec a_stun,x
    ; stun sparks
    lda frame
    and #15
    bne :+
    jsr act_center
    jsr fx_stun
    ldx cur
:   ; stunned robots just fall
    lda a_flags,x
    and #F_FLY
    bne :+
    jsr act_move
:   jmp @next
@nostun:
    lda a_type,x
    asl
    tax
    jsr (at_ai,x)
@next:
    ldx cur
    inx
    inx
    cpx #MAX_ACT*2
    bcs :+
    jmp @loop
:   rts

; t0/t1 = actor center (px) for effects
act_center:
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sta t0
    lda a_type,x
    asl
    tay
    lda at_h,y
    lsr
    sta t1
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc t1
    sta t1
    rts

; t8/t9 = actor feet position (px)
act_pos:
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sta t8
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta t9
    rts

ai_none:
    rts

; ---------------------------------------------------------------- movement
; Apply gravity + map collision. X = slot. Sets F_GROUND, returns carry set if
; blocked horizontally.
act_move:
    ldx cur
    lda a_type,x
    asl
    tay
    lda at_hw,y
    sta t6
    lda at_h,y
    sta t7
    ; gravity
    lda a_vy,x
    clc
    adc #5
    cmp #96
    bmi :+
    lda #96
:   sta a_vy,x
    stz t5                  ; blocked flag
    ; ---- horizontal
    lda a_vx,x
    beq @y
    clc
    adc a_x,x
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t3
    lda a_vx,x
    bmi @l
    lda t3
    clc
    adc t6
    bra @e
@l: lda t3
    sec
    sbc t6
    dec a
@e: sta t4
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta t9
    sec
    sbc #4
    tay
    lda t4
    jsr solid_at
    bcs @blk
    lda t9
    sec
    sbc t7
    inc a
    inc a
    tay
    lda t4
    jsr solid_at
    bcs @blk
    ldx cur
    lda t2
    sta a_x,x
    bra @y
@blk:
    ldx cur
    stz a_vx,x
    lda #1
    sta t5
@y: ; ---- vertical
    ldx cur
    lda a_vy,x
    bmi @up
    clc
    adc a_y,x
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t3                  ; new feet px
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta t9                  ; old feet
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sta t8
    sec
    sbc t6
    inc a
    ldy t3
    jsr act_floor
    bcs @land
    lda t8
    clc
    adc t6
    dec a
    ldy t3
    jsr act_floor
    bcs @land
    ldx cur
    lda t2
    sta a_y,x
    lda a_flags,x
    and #.loword(~F_GROUND)
    sta a_flags,x
    bra @done
@land:
    ldx cur
    lda t3
    and #$FFF0
    asl
    asl
    asl
    asl
    sta a_y,x
    stz a_vy,x
    lda a_flags,x
    ora #F_GROUND
    sta a_flags,x
    bra @done
@up:
    clc
    adc a_y,x
    sta t2
    lsr
    lsr
    lsr
    lsr
    sec
    sbc t7
    tay
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    jsr solid_at
    ldx cur
    bcc :+
    stz a_vy,x
    bra @done
:   lda t2
    sta a_y,x
@done:
    lda t5
    lsr
    rts

; A=x, Y=y probe; t9 = old feet row. Carry if it supports.
act_floor:
    jsr attr_at
    lsr
    bcs @y
    asl
    and #AT_PLATFORM
    beq @n
    lda t3
    and #$FFF0
    cmp t9
    bcc @n
    sec
    rts
@n: clc
    rts
@y: sec
    rts

; Check for wall or ledge ahead in the facing direction. Carry set = turn.
act_blocked_ahead:
    ldx cur
    lda a_type,x
    asl
    tay
    lda at_hw,y
    clc
    adc #3
    sta t4
    jsr act_pos
    lda a_flags,x
    and #F_LEFT
    beq :+
    lda t4
    eor #$FFFF
    inc a
    sta t4
:   lda t8
    clc
    adc t4
    sta t4
    ; wall
    lda t9
    sec
    sbc #8
    tay
    lda t4
    jsr solid_at
    bcs @yes
    ; ledge (fall more than one tile)
    lda t9
    clc
    adc #2
    tay
    lda t4
    jsr attr_at
    and #(AT_SOLID | AT_PLATFORM | AT_LADDER)
    bne @no
    lda t9
    clc
    adc #18
    tay
    lda t4
    jsr attr_at
    and #(AT_SOLID | AT_PLATFORM)
    bne @no
@yes:
    ldx cur
    sec
    rts
@no:
    ldx cur
    clc
    rts

act_turn:
    lda a_flags,x
    eor #F_LEFT
    sta a_flags,x
    rts

; face toward the player
act_face_player:
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    cmp p_px
    lda a_flags,x
    and #.loword(~F_LEFT)
    bcc :+
    ora #F_LEFT
:   sta a_flags,x
    rts

; t0 = dx to player (player - actor), t1 = dy (player center - actor center)
act_delta:
    lda p_px
    sec
    sbc t8
    sta t0
    lda p_py
    sec
    sbc t9
    sta t1
    rts

abs_a:
    bpl :+
    eor #$FFFF
    inc a
:   rts

; Can the actor see the player? (range t10 px). Carry set if yes.
act_sees_player:
    lda p_dead
    bne @no
    jsr act_pos
    jsr act_delta
    lda t0
    jsr abs_a
    cmp t10
    bcs @no
    lda t1
    jsr abs_a
    cmp #72
    bcs @no
    ; facing toward the player (unless very close)
    lda t0
    jsr abs_a
    cmp #40
    bcc @los
    lda a_flags,x
    and #F_LEFT
    beq @fr
    lda t0
    bpl @no
    bra @los
@fr:lda t0
    bmi @no
@los:
    jsr act_los
    rts
@no:clc
    rts

; line of sight from actor eye (t8, t9-22) to player chest. carry = clear view
act_los:
    lda t0
    cmp #$8000
    ror
    cmp #$8000
    ror
    cmp #$8000
    ror
    sta t2                  ; dx/8
    lda t1
    cmp #$8000
    ror
    cmp #$8000
    ror
    cmp #$8000
    ror
    sta t3                  ; dy/8
    lda t8
    sta t4
    lda t9
    sec
    sbc #22
    sta t5
    lda #7
    sta t6
@s: lda t4
    clc
    adc t2
    sta t4
    lda t5
    clc
    adc t3
    sta t5
    ldy t5
    lda t4
    jsr solid_at
    bcs @blocked
    dec t6
    bne @s
    ldx cur
    sec
    rts
@blocked:
    ldx cur
    clc
    rts

; Does the actor's box overlap the player? carry set if so
act_touch_player:
    lda p_dead
    bne @no
    lda a_type,x
    asl
    tay
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc p_px
    jsr abs_a
    sec
    sbc at_hw,y
    cmp #6
    bcc :+
    bpl @no
:   lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta t2
    ; vertical overlap: actor [ay-h, ay) vs player [py-30, py)
    lda p_py
    sec
    sbc #28
    cmp t2
    bcs @no
    lda t2
    sec
    sbc at_h,y
    cmp p_py
    bcs @no
    sec
    rts
@no:clc
    rts

; ---------------------------------------------------------------- human AI
; guards, soldiers, defenders, commander and security robots
ai_human:
    ldx cur
    lda a_flags,x
    and #F_DONE
    beq :+
    rts
:   inc a_anim,x
    lda a_type,x
    asl
    tay
    lda at_spd,y
    sta t11                 ; walking speed
    ; no legs: crawl slowly
    lda a_parts,x
    and #PART_LEGS
    bne :+
    lda #3
    sta t11
:   lda a_state,x
    cmp #AS_ATTACK
    bne :+
    jmp @attack
:   cmp #AS_FLEE
    bne @patrol
    jmp @flee
@patrol:
    ; defenders hold their position
    lda a_type,x
    cmp #ET_DEFENDER
    bne :+
    stz a_vx,x
    bra @look
:   jsr act_blocked_ahead
    bcc :+
    jsr act_turn
:   dec a_timer,x
    bpl :+
    jsr random
    and #127
    ora #96
    sta a_timer,x
    jsr act_turn
:   lda t11
    jsr act_set_walk
@look:
    ; look for the player every 8 frames
    txa
    clc
    adc frame
    and #14
    bne @mv
    lda #170
    sta t10
    jsr act_sees_player
    bcc @mv
    lda #AS_ATTACK
    sta a_state,x
    lda #20
    sta a_cool,x
    jsr act_alert_fx
@mv:jsr act_move
    rts

@attack:
    ; lost the arm (gun)? run away
    lda a_parts,x
    and #PART_ARM
    bne :+
    lda #AS_FLEE
    sta a_state,x
    rts
:   jsr act_face_player
    jsr act_pos
    jsr act_delta
    ; too far: give up
    lda t0
    jsr abs_a
    cmp #280
    bcs @calm
    lda t1
    jsr abs_a
    cmp #120
    bcc @engage
@calm:
    stz a_state,x
    rts
@engage:
    ; movement: soldiers and commander close in, others hold
    stz a_vx,x
    lda a_type,x
    cmp #ET_SOLDIER
    beq @adv
    cmp #ET_COMMANDER
    beq @adv
    cmp #ET_SECBOT
    bne @fire
@adv:
    lda t0
    jsr abs_a
    cmp #100
    bcc @fire
    jsr act_blocked_ahead
    bcs @fire
    lda t11
    jsr act_set_walk
@fire:
    dec a_cool,x
    bpl @mv2
    lda a_type,x
    asl
    tay
    jsr random
    and #15
    clc
    adc at_rate,y
    sta a_cool,x
    ; need line of sight
    jsr act_pos
    jsr act_delta
    jsr act_los
    bcc @mv2
    jsr act_shoot
@mv2:
    jsr act_move
    rts

@flee:
    ; run away from the player
    jsr act_pos
    lda p_px
    cmp t8
    lda a_flags,x
    ora #F_LEFT
    bcs :+
    and #.loword(~F_LEFT)
:   sta a_flags,x
    jsr act_blocked_ahead
    bcs :+
    lda t11
    clc
    adc #6
    jsr act_set_walk
    bra @fm
:   stz a_vx,x
@fm:jsr act_move
    rts

; A = speed -> a_vx in the facing direction
act_set_walk:
    pha
    lda a_flags,x
    and #F_LEFT
    beq :+
    pla
    eor #$FFFF
    inc a
    sta a_vx,x
    rts
:   pla
    sta a_vx,x
    rts

act_alert_fx:
    jsr act_pos
    lda t8
    sta t0
    lda t9
    sec
    sbc #44
    sta t1
    jsr fx_alert
    ldx cur
    lda #SND_ALERT
    jsr sfx
    ldx cur
    rts

; Fire at the player from the gun arm (humans / security robots)
act_shoot:
    ldx cur
    jsr act_pos
    ; aim: forward unless the player is well above/below
    jsr act_delta
    stz t10                 ; aim index
    lda t1
    sec
    sbc #.loword(-18)       ; player center relative
    lda t1
    clc
    adc #20
    bpl :+
    ; player above
    cmp #.loword(-40)
    bcs @ad
    lda #2
    sta t10
    bra @ad
:   cmp #40
    bcc @ad
    lda #3
    sta t10
@ad:
    ; muzzle position from the arm tables
    lda t10
    asl
    tay
    lda a_type,x
    cmp #ET_SECBOT
    bne :+
    lda rb_arm_mx,y
    sta t0
    lda rb_arm_my,y
    sta t1
    bra :++
:   lda hu_arm_mx,y
    sta t0
    lda hu_arm_my,y
    sta t1
:   lda a_flags,x
    and #F_LEFT
    beq :+
    lda t0
    eor #$FFFF
    inc a
    sta t0
:   lda t0
    clc
    adc t8
    sta t0
    lda t1
    clc
    adc t9
    sta t1
    ; legless: gun is near the floor
    lda a_parts,x
    and #PART_LEGS
    bne :+
    lda t1
    clc
    adc #12
    sta t1
:   lda a_type,x
    cmp #ET_SECBOT
    bne :+
    ; headless robots spray randomly
    lda a_parts,x
    and #PART_HEAD
    bne :+
    jsr random
    and #63
    sec
    sbc #32
    clc
    adc p_py
    sta p_aim_tmp
    bra @wild
:   lda p_py
    sta p_aim_tmp
@wild:
    ; velocity toward (player x, aim y - 16)
    lda p_px
    sec
    sbc t0
    sta t2
    lda p_aim_tmp
    sec
    sbc #16
    sec
    sbc t1
    sta t3
    ; mostly-level shots stay level
    lda t10
    bne :+
    stz t3
:   lda #56
    sta t6
    jsr aim_vector
    lda #EB_BULLET
    jsr eb_spawn
    ldx cur
    lda #8
    sta a_aux2,x            ; muzzle flash timer
    lda #SND_ESHOT
    jsr sfx
    ldx cur
    rts

; ---------------------------------------------------------------- crawler
ai_crawler:
    ldx cur
    inc a_anim,x
    lda a_type,x
    asl
    tay
    lda at_spd,y
    sta t11
    ; charge when the player is close on the same level
    lda a_parts,x
    and #PART_TOP
    beq @blind
    jsr act_pos
    jsr act_delta
    lda t1
    clc
    adc #16
    jsr abs_a
    cmp #28
    bcs @walk
    lda t0
    jsr abs_a
    cmp #110
    bcs @walk
    jsr act_face_player
    lda #26
    sta t11
    bra @walk
@blind:
    ; sensor gone: wander erratically
    jsr random
    and #63
    bne @walk
    jsr act_turn
@walk:
    jsr act_blocked_ahead
    bcc :+
    jsr act_turn
:   lda t11
    jsr act_set_walk
    jsr act_move
    ldx cur
    jsr act_touch_player
    bcc :+
    lda #10
    jsr player_hurt
:   rts

; ---------------------------------------------------------------- drone
ai_drone:
    ldx cur
    inc a_anim,x
    jsr act_pos
    jsr act_delta
    lda a_parts,x
    and #PART_TOP
    bne @armed
    ; gun shot off: kamikaze dive
    lda t0
    sta t2
    lda t1
    sec
    sbc #16
    sta t3
    lda #30
    sta t6
    jsr aim_vector
    ldx cur
    lda t2
    sta a_vx,x
    lda t3
    sta a_vy,x
    jsr drone_move
    ldx cur
    jsr act_touch_player
    bcc :+
    lda #14
    jsr player_hurt
    ldx cur
    jsr actor_kill
:   rts
@armed:
    lda t0
    jsr abs_a
    cmp #200
    bcs @idle
    lda t1
    jsr abs_a
    cmp #150
    bcs @idle
    ; hover position: above the player, offset to the side
    lda t0
    bmi :+
    lda #.loword(-64)
    bra :++
:   lda #64
:   clc
    adc p_px
    sec
    sbc t8
    sta t2
    lda p_py
    sec
    sbc #72
    sec
    sbc t9
    sta t3
    ; velocity = clamp(delta, 18)
    lda t2
    jsr clamp18
    sta a_vx,x
    lda t3
    jsr clamp18
    sta a_vy,x
    jsr act_face_player
    ; shoot
    dec a_cool,x
    bpl @mv
    lda #85
    sta a_cool,x
    jsr act_pos
    lda t8
    sta t0
    lda t9
    sta t1
    lda #40
    sta t6
    lda #EB_SHOT
    jsr eb_aimed
    lda #SND_ESHOT
    jsr sfx
    ldx cur
    bra @mv
@idle:
    ; gentle bob
    lda a_anim,x
    and #32
    beq :+
    lda #4
    bra :++
:   lda #.loword(-4)
:   sta a_vy,x
    stz a_vx,x
@mv:jsr drone_move
    rts

; A (signed) -> clamped to +-18
clamp18:
    bmi @n
    cmp #18
    bcc :+
    lda #18
:   rts
@n: cmp #.loword(-18)
    bcs :+
    lda #.loword(-18)
:   rts

; flying movement: no gravity, stop at walls
drone_move:
    ldx cur
    lda a_x,x
    clc
    adc a_vx,x
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t4
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc #6
    tay
    lda t4
    jsr solid_at
    ldx cur
    bcs :+
    lda t2
    sta a_x,x
:   lda a_y,x
    clc
    adc a_vy,x
    sta t2
    lsr
    lsr
    lsr
    lsr
    sta t4
    ; probe top and bottom of the body
    sec
    sbc #12
    tay
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    jsr solid_at
    ldx cur
    bcs @n
    ldy t4
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    jsr solid_at
    ldx cur
    bcs @n
    lda t2
    sta a_y,x
@n: rts

; ---------------------------------------------------------------- heavy robot / boss
ai_heavy:
    ldx cur
    lda a_type,x
    asl
    tay
    lda at_spd,y
    sta t11
    jsr act_pos
    jsr act_delta
    stz a_vx,x
    lda t0
    jsr abs_a
    cmp #230
    bcc :+
    jmp @mv
:   lda t1
    jsr abs_a
    cmp #100
    bcc :+
    jmp @mv
:   ; boss wakes up and announces itself
    lda a_state,x
    bne :+
    lda #1
    sta a_state,x
    jsr act_alert_fx
:   jsr act_face_player
    ; walk toward the player if it still has legs
    lda a_parts,x
    and #PART_LEGS
    beq @nowalk
    lda t0
    jsr abs_a
    cmp #40
    bcc @nowalk
    jsr act_blocked_ahead
    bcs @nowalk
    inc a_anim,x
    lda t11
    jsr act_set_walk
@nowalk:
    ; cannon
    lda a_parts,x
    and #PART_ARM
    bne @lb1293_7
    jmp @mv
@lb1293_7:
    dec a_cool,x
    bmi @lb1295_6
    jmp @mv
@lb1295_6:
    lda a_type,x
    asl
    tay
    lda at_rate,y
    ; angry boss fires faster
    ldy a_hp,x
    cpy #50
    bcs :+
    lsr
    clc
    adc #10
:   sta a_cool,x
    ; muzzle
    lda a_flags,x
    and #F_LEFT
    beq :+
    lda #.loword(-HV_MUZ_X)
    bra :++
:   lda #HV_MUZ_X
:   clc
    adc t8
    sta t0
    sta t10
    lda t9
    clc
    adc #HV_MUZ_Y
    sta t1
    sta t11
    ; three-way spread: aimed, then +/- 24 px vertical
    lda #48
    sta t6
    lda #EB_PLASMA
    jsr eb_aimed
    lda t10
    sta t0
    lda t11
    sta t1
    lda p_px
    sec
    sbc t0
    sta t2
    lda #.loword(-40)
    sta t3
    lda #44
    sta t6
    jsr aim_vector
    lda #EB_PLASMA
    jsr eb_spawn
    lda t10
    sta t0
    lda t11
    sta t1
    lda p_px
    sec
    sbc t0
    sta t2
    lda #24
    sta t3
    lda #44
    sta t6
    jsr aim_vector
    lda #EB_PLASMA
    jsr eb_spawn
    lda #SND_CANNON
    jsr sfx
    ldx cur
@mv:
    jsr act_move
    ldx cur
    jsr act_touch_player
    bcc :+
    lda #15
    jsr player_hurt
:   rts

; ---------------------------------------------------------------- objects
ai_generator:
    ldx cur
    inc a_anim,x
    rts

ai_terminal:
    ldx cur
    inc a_anim,x
    rts

ai_captive:
    ldx cur
    inc a_anim,x
    jsr act_face_player
    jsr act_touch_player
    bcc @x
    ; rescued: beam out
    jsr act_center
    jsr fx_teleport
    ldx cur
    ldy a_ent,x
    lda en_flags,y
    ora #EN_DEAD
    sta en_flags,y
    stz a_type,x
    lda #msg_rescued
    jsr show_msg
    lda #SND_RESCUE
    jsr sfx
    lda #OBJ_RESCUE
    jsr obj_event
@x: rts

ai_friend:
    ldx cur
    inc a_anim,x
    jsr act_face_player
    jsr act_touch_player
    bcc @x
    lda p_win
    bne @x
    lda #OBJ_FRIEND
    jsr obj_event
@x: rts

; Elevator: rides between its bottom (a_aux2 px) and top (bottom - aux*16)
ai_elevator:
    ldx cur
    lda a_state,x
    beq @idle
    cmp #1
    beq @moving
    ; state 2: arrived, wait for the player to step off
    txa
    inc a
    inc a
    cmp p_riding
    beq @x
    stz a_state,x
@x: rts
@idle:
    txa
    inc a
    inc a
    cmp p_riding
    bne @noride
    inc a_timer,x
    lda a_timer,x
    cmp #20
    bcc @x
    stz a_timer,x
    lda #1
    sta a_state,x
    lda #SND_ELEV
    jsr sfx
    ldx cur
    ; direction: at the bottom -> go up
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    cmp a_aux2,x
    bcc :+
    lda #.loword(-16)
    sta a_vy,x
    rts
:   lda #16
    sta a_vy,x
    rts
@noride:
    stz a_timer,x
    rts
@moving:
    lda a_y,x
    clc
    adc a_vy,x
    sta a_y,x
    ; carry the player
    txa
    inc a
    inc a
    cmp p_riding
    bne :+
    lda p_y
    clc
    adc a_vy,x
    sta p_y
    lsr
    lsr
    lsr
    lsr
    sta p_py
:   ; reached an end?
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta t0
    lda a_vy,x
    bmi @goingup
    lda t0
    cmp a_aux2,x
    bcc @x2
    bra @arrive
@goingup:
    lda a_aux,x
    asl
    asl
    asl
    asl
    sta t1
    lda a_aux2,x
    sec
    sbc t1
    cmp t0
    bcc @x2
@arrive:
    lda #2
    sta a_state,x
    stz a_vy,x
@x2:rts

; Called from player_move_y while falling. t3 = new feet row.
; Carry set if the player landed on an elevator.
elevator_check:
    ldx #0
@l: lda a_type,x
    cmp #ET_ELEVATOR
    bne @n
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta t4                  ; platform top
    lda p_py
    cmp t4
    beq :+
    bcs @n
:   lda t3
    cmp t4
    bcc @n
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc p_px
    clc
    adc #16
    cmp #32
    bcs @n
    lda t4
    sta p_py
    asl
    asl
    asl
    asl
    sta p_y
    txa
    inc a
    inc a
    sta p_riding
    sec
    rts
@n: inx
    inx
    cpx #MAX_ACT*2
    bcc @l
    clc
    rts

; ---------------------------------------------------------------- hits
; Build the per-frame list of shootable hitboxes (used by bullets)
hitboxes_build:
    ldx #0
    ldy #0
@l: lda a_type,x
    beq @n
    lda a_flags,x
    and #F_SHOOT
    beq @n
    txa
    sta hb_slot,y
    phy
    lda a_type,x
    asl
    tay
    lda at_hw,y
    sta t0
    lda at_h,y
    sta t1
    ply
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    pha
    sec
    sbc t0
    sta hb_l,y
    pla
    clc
    adc t0
    sta hb_r,y
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta hb_b,y
    sec
    sbc t1
    sta hb_t,y
    iny
    iny
@n: inx
    inx
    cpx #MAX_ACT*2
    bcc @l
    sty hb_n
    rts

; Point vs actor boxes. A = x px, Y = y px. Damages the first hit actor
; (hit_dmg / hit_kind / hit_vx). Carry set if something was hit.
actor_hit_point:
    sta hp_x
    sty hp_y
    ldy #0
@l: cpy hb_n
    bcs @none
    lda hp_x
    cmp hb_l,y
    bcc @n
    beq :+
    cmp hb_r,y
    beq :+
    bcs @n
:   lda hp_y
    cmp hb_t,y
    bcc @n
    beq @n
    cmp hb_b,y
    bcs @n
    ; still alive and shootable? (an earlier bullet may have killed it)
    ldx hb_slot,y
    lda a_type,x
    beq @n
    lda a_flags,x
    and #F_SHOOT
    beq @n
    lda hp_y
    sta hit_y
    stx cur2
    jsr actor_damage
    ldx cur2
    sec
    rts
@n: iny
    iny
    bra @l
@none:
    clc
    rts

; like actor_hit_point but for the railgun: every actor once, no stop
actor_rail_point:
    sta hp_x
    sty hp_y
    ldx #0
@l: lda a_type,x
    beq @n
    lda a_flags,x
    and #F_SHOOT
    beq @n
    ; already hit?
    txa
    lsr
    tay
    lda railbit_lo,y
    and a_hitmask
    bne @n
    lda railbit_hi,y
    and a_hitmask+2
    bne @n
    jsr box_test
    bcc @n
    txa
    lsr
    tay
    lda railbit_lo,y
    ora a_hitmask
    sta a_hitmask
    lda railbit_hi,y
    ora a_hitmask+2
    sta a_hitmask+2
    lda hp_y
    sta hit_y
    stx cur2
    jsr actor_damage
    ldx cur2
@n: inx
    inx
    cpx #MAX_ACT*2
    bcc @l
    rts

railbit_lo: .word 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 0, 0, 0, 0
railbit_hi: .word 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 4, 8

; touch test only (grenades): A=x, Y=y. Carry set if a hostile is there.
actor_touch_point:
    sta hp_x
    sty hp_y
    ldx #0
@l: lda a_type,x
    beq @n
    lda a_flags,x
    and #F_HOSTILE
    beq @n
    jsr box_test
    bcc @n
    sec
    rts
@n: inx
    inx
    cpx #MAX_ACT*2
    bcc @l
    clc
    rts

; is (hp_x, hp_y) inside actor X's box? (flying drones: box above origin)
box_test:
    lda a_type,x
    asl
    tay
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc hp_x
    jsr abs_a
    cmp at_hw,y
    beq :+
    bcs @no
:   lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sta t0
    sec
    sbc hp_y
    beq @no
    bmi @no
    cmp at_h,y
    bcs @no
    sec
    rts
@no:clc
    rts

; Grenade blast at blast_x/blast_y: damage actors nearby
actors_blast:
    ldx #0
@l: lda a_type,x
    beq @n
    lda a_flags,x
    and #F_SHOOT
    beq @n
    lda a_type,x
    asl
    tay
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc blast_x
    jsr abs_a
    sec
    sbc at_hw,y
    bmi :+
    cmp #28
    bcs @n
:   lda at_h,y
    lsr
    sta t0
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc t0
    sta t1                  ; actor center y
    sec
    sbc blast_y
    jsr abs_a
    sec
    sbc t0
    bmi :+
    cmp #28
    bcs @n
:   lda #10
    sta hit_dmg
    lda #DK_BLAST
    sta hit_kind
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc blast_x
    asl
    asl
    sta hit_vx
    lda t1
    sta hit_y
    stx cur2
    jsr actor_damage
    ldx cur2
@n: inx
    inx
    cpx #MAX_ACT*2
    bcc @l
    rts

; ---------------------------------------------------------------- damage
; X = slot. hit_dmg, hit_kind, hit_y, hit_vx
actor_damage:
    stx dmg_slot
    lda a_flags,x
    and #F_DONE
    beq :+
    rts
:   lda hit_y
    sta t1
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sta t0
    lda a_type,x
    cmp #ET_TERMINAL
    bne @nt
    ; terminals only respond to EMP
    lda hit_kind
    cmp #DK_EMP
    beq :+
    jmp fx_spark
:   lda a_flags,x
    ora #F_DONE
    sta a_flags,x
    ldy a_ent,x
    lda en_flags,y
    ora #EN_DONE
    sta en_flags,y
    jsr fx_emp_burst
    lda #msg_terminal
    jsr show_msg
    lda #OBJ_EMP
    jmp obj_event
@nt:
    ; ---- EMP
    lda hit_kind
    cmp #DK_EMP
    bne @notemp
    lda a_flags,x
    and #F_ROBOT
    beq @empman
    lda a_type,x
    cmp #ET_GENERATOR
    beq @empman
    lda #300
    ldy a_type,x
    cpy #ET_BOSS
    bne :+
    lda #90
:   sta a_stun,x
    jsr fx_emp_burst
    ldx dmg_slot
    rts
@empman:
    lda #1
    sta hit_dmg
@notemp:
    ; ---- armor: bullets glance off half the time
    lda hit_kind
    bne @noarm
    lda a_flags,x
    and #F_ARMOR
    beq @noarm
    lda a_hurt+1,x          ; (unused high byte as toggle)
    eor #1
    sta a_hurt+1,x
    and #1
    bne @noarm
    jmp fx_spark
@noarm:
    ; plasma tears robots apart
    lda hit_kind
    cmp #DK_PLASMA
    bne :+
    lda a_flags,x
    and #F_ROBOT
    beq :+
    lda hit_dmg
    asl
    sta hit_dmg
:   lda #6
    sta a_hurt,x
    ; anyone hit becomes alert
    lda a_flags,x
    and #F_HOSTILE
    beq :+
    lda a_state,x
    bne :+
    lda #AS_ATTACK
    sta a_state,x
:
    ; ---- hit effect
    jsr fx_hit_actor
    ldx dmg_slot
    ; ---- locational damage
    jsr damage_zone          ; -> A = part bit hit (0 = torso)
    sta t10
    lda hit_kind
    cmp #DK_BLAST
    bne @single
    ; blasts hurt every limb
    lda #PART_LEGS
    jsr part_damage
    lda #PART_ARM
    jsr part_damage
    jsr random
    and #1
    beq @hp
    lda #PART_HEAD
    jsr part_damage
    bra @hp
@single:
    lda t10
    beq @hp
    jsr part_damage
@hp:
    ldx dmg_slot
    lda a_type,x
    beq @gone               ; killed by a part loss (head)
    lda a_hp,x
    sec
    sbc hit_dmg
    sta a_hp,x
    beq :+
    bpl @gone
:   jsr actor_kill
@gone:
    ldx dmg_slot
    rts

; Which body part did hit_y land on? -> A = part bit or 0 for torso
damage_zone:
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc hit_y               ; height above the feet
    sta t2
    lda a_type,x
    cmp #ET_CRAWLER
    beq @top
    cmp #ET_DRONE
    beq @drone
    cmp #ET_HEAVY
    beq @heavy
    cmp #ET_BOSS
    beq @heavy
    cmp #ET_GENERATOR
    bcs @torso
    ; human-like: legs below 12px, head above 24px, arm on some torso hits
    lda a_parts,x
    and #PART_LEGS
    bne :+
    ; legless bodies lie low: everything is torso/head
    lda t2
    cmp #10
    bcs @head
    bra @torso
:   lda t2
    cmp #12
    bcc @legs
    cmp #24
    bcs @head
    jsr random
    and #3
    bne @torso
    lda #PART_ARM
    rts
@head:
    lda #PART_HEAD
    rts
@legs:
    lda #PART_LEGS
    rts
@torso:
    lda #0
    rts
@top:
    lda t2
    cmp #8
    bcc @torso
    lda #PART_TOP
    rts
@drone:
    lda t2
    cmp #5
    bcs @torso
    lda #PART_TOP
    rts
@heavy:
    lda t2
    cmp #14
    bcc @legs
    jsr random
    and #1
    beq @torso
    lda #PART_ARM
    rts

; Damage one part (A = bit). Severs it when its hit points run out.
part_damage:
    ldx dmg_slot
    sta t11
    and a_parts,x
    bne :+
    rts
:   ; humans keep their limbs when gore is off
    lda a_flags,x
    and #F_HUMAN
    beq :+
    lda gore
    bne :+
    rts
:   ; railgun and blasts are strong enough to sever outright
    lda hit_kind
    cmp #DK_RAIL
    beq @sever
    cmp #DK_BLAST
    bne :+
    jsr random
    and #1
    beq @sever
:   lda t11
    cmp #PART_HEAD
    bne :+
    lda a_lh,x
    sec
    sbc hit_dmg
    sta a_lh,x
    bmi @sever
    beq @sever
    rts
:   cmp #PART_LEGS
    bne :+
    lda a_ll,x
    sec
    sbc hit_dmg
    sta a_ll,x
    bmi @sever
    beq @sever
    rts
:   lda a_la,x
    sec
    sbc hit_dmg
    sta a_la,x
    bmi @sever
    beq @sever
    rts
@sever:
    lda t11
    jsr detach_part
    ; losing the head is fatal for humans
    ldx dmg_slot
    lda t11
    cmp #PART_HEAD
    bne @x
    lda a_flags,x
    and #F_HUMAN
    beq @x
    jsr actor_kill
@x: rts

; Remove part A from actor dmg_slot and throw it as debris.
detach_part:
    ldx dmg_slot
    sta t11
    eor #$FFFF
    and a_parts,x
    sta a_parts,x
    jsr part_tile           ; -> t2 tile|attr, t3 size, t4/t5 offset
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    clc
    adc t4
    sta t0
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    clc
    adc t5
    sta t1
    lda hit_vx
    sta debris_push
    jsr fx_debris
    ldx dmg_slot
    ; blood for flesh, sparks and smoke for machines
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sta t0
    lda hit_y
    sta t1
    lda a_flags,x
    and #F_HUMAN
    beq @robot
    lda gore
    beq @x
    jsr fx_blood_burst
    bra @x
@robot:
    jsr fx_sparks_burst
    ldx dmg_slot
    lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sta t0
    lda hit_y
    sta t1
    jsr fx_smoke
@x: lda #SND_SEVER
    jsr sfx
    ldx dmg_slot
    rts

; Graphics for part t11 of actor X -> t2 (tile|attr), t3 (0/2 size), t4/t5 offset
part_tile:
    lda a_type,x
    asl
    tay
    lda at_attr,y
    sta t6
    lda a_type,x
    cmp #ET_CRAWLER
    bne :+
    lda #SPR_CR_TOP
    ldy #.loword(-4)
    lda #SPR_CR_TOP
    sta t2
    stz t3
    lda #.loword(-4)
    sta t4
    lda #.loword(-16)
    sta t5
    jmp @fin
:   cmp #ET_DRONE
    bne :+
    lda #SPR_DR_GUN
    sta t2
    stz t3
    lda #.loword(-4)
    sta t4
    lda #.loword(-4)
    sta t5
    jmp @fin
:   cmp #ET_HEAVY
    beq @hv
    cmp #ET_BOSS
    bne @hu
@hv:lda t11
    cmp #PART_ARM
    bne :+
    lda #SPR_HV_CANNON
    sta t2
    lda #HV_ARM_OX
    sta t4
    lda #HV_ARM_OY
    sta t5
    bra @big
:   lda #SPR_HV_LEGS0_L
    sta t2
    lda #.loword(-16)
    sta t4
    sta t5
    bra @big
@hu:
    ; human / security robot parts
    lda t11
    cmp #PART_HEAD
    bne :+
    lda a_type,x
    asl
    tay
    lda at_head,y
    sta t2
    stz t3
    lda #.loword(-3)
    sta t4
    lda #.loword(-32)
    sta t5
    bra @fin
:   cmp #PART_ARM
    bne :+
    lda #SPR_HU_ARM0
    ldy a_type,x
    cpy #ET_SECBOT
    bne :++
    lda #SPR_RB_ARM0
    bra :++
:   lda #SPR_HU_LEGS_STAND
    ldy a_type,x
    cpy #ET_SECBOT
    bne :+
    lda #SPR_RB_LEGS_STAND
:   sta t2
    lda #.loword(-8)
    sta t4
    lda #.loword(-16)
    sta t5
@big:
    lda #2
    sta t3
@fin:
    lda t2
    ora t6
    sta t2
    rts

; Kill actor X (dmg_slot or cur)
actor_kill:
    stx dmg_slot
    lda a_type,x
    bne :+
    rts
:   inc kills
    ldy a_ent,x
    lda en_flags,y
    ora #EN_DEAD
    sta en_flags,y
    ; objective bookkeeping
    lda a_type,x
    cmp #ET_GENERATOR
    bne :+
    jmp @generator
:   cmp #ET_BOSS
    bne :+
    lda #OBJ_BOSS
    jsr obj_event
    ldx dmg_slot
    bra @burst
:   cmp #ET_COMMANDER
    bne @burst
    lda #OBJ_KILL
    jsr obj_event
    ldx dmg_slot
@burst:
    ; loot
    jsr random
    and #7
    cmp #3
    bcs :+
    jsr act_pos
    lda t8
    sta t0
    lda t9
    sta t1
    jsr spawn_drop
    ldx dmg_slot
:   lda a_flags,x
    and #F_HUMAN
    bne @lb2225_3
    jmp @robot
@lb2225_3:
    lda gore
    bne @gory
    ; clean death: blink out
    lda a_flags,x
    ora #F_DYING
    and #.loword(~(F_SHOOT | F_HOSTILE))
    sta a_flags,x
    lda #40
    sta a_timer,x
    lda #SND_DIE_E
    jmp sfx
@gory:
    ; every remaining part flies off
    lda #PART_HEAD
    jsr kill_part
    lda #PART_ARM
    jsr kill_part
    lda #PART_LEGS
    jsr kill_part
    ldx dmg_slot
    ; torso
    lda #SPR_HU_TORSO
    ldy a_type,x
    cpy #ET_SECBOT
    bne :+
    lda #SPR_RB_TORSO
:   sta t2
    lda a_type,x
    asl
    tay
    lda at_attr,y
    ora t2
    sta t2
    lda #2
    sta t3
    jsr act_pos
    lda t8
    sta t0
    lda t9
    sec
    sbc #20
    sta t1
    lda hit_vx
    sta debris_push
    jsr fx_debris
    ldx dmg_slot
    jsr act_pos
    lda t8
    sta t0
    lda t9
    sec
    sbc #18
    sta t1
    jsr fx_blood_burst
    ldx dmg_slot
    stz a_type,x
    lda #SND_DIE_E
    jmp sfx
@robot:
    lda #PART_HEAD
    jsr kill_part
    lda #PART_ARM
    jsr kill_part
    lda #PART_LEGS
    jsr kill_part
    lda #PART_TOP
    jsr kill_part
    ldx dmg_slot
    jsr act_center
    jsr fx_explosion
    ldx dmg_slot
    lda a_type,x
    cmp #ET_HEAVY
    bcc :+
    lda #16
    sta shake
:   lda #SND_BOOM
    jsr sfx
    ldx dmg_slot
    stz a_type,x
    rts
@generator:
    lda a_flags,x
    ora #F_DONE
    and #.loword(~F_SHOOT)
    sta a_flags,x
    lda en_flags,y
    and #.loword(~EN_DEAD)
    ora #EN_DONE
    sta en_flags,y
    jsr act_center
    jsr fx_explosion
    lda #10
    sta shake
    lda #SND_BOOM
    jsr sfx
    lda #msg_generator
    jsr show_msg
    lda #OBJ_DESTROY
    jmp obj_event

kill_part:
    ldx dmg_slot
    and a_parts,x
    beq :+
    jmp detach_part
:   rts

; ---------------------------------------------------------------- drawing
actors_draw:
    ldx #0
@l: lda a_type,x
    beq @n
    stx cur
    ; dying: blink
    lda a_flags,x
    and #F_DYING
    beq :+
    lda frame
    and #2
    bne @n2
:   ; stunned: flicker
    lda a_stun,x
    beq :+
    lda frame
    and #1
    bne @n2
:   lda a_x,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_x
    sta t8
    clc
    adc #40
    cmp #(256 + 80)
    bcs @n2
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc cam_y
    sta t9
    clc
    adc #40
    cmp #(224 + 80)
    bcs @n2
    ; attributes: palette, facing, hurt flash
    lda a_type,x
    asl
    tay
    lda at_attr,y
    sta t11
    lda a_hurt,x
    beq :+
    and #2
    beq :+
    lda #$2800              ; flash with the effects palette
    sta t11
:   lda a_flags,x
    and #F_LEFT
    beq :+
    lda t11
    ora #$4000
    sta t11
:   lda a_type,x
    asl
    tax
    jsr (at_draw,x)
@n2:ldx cur
@n: inx
    inx
    cpx #MAX_ACT*2
    bcs @lb2403_2
    jmp @l
@lb2403_2:
    rts

draw_none:
    rts

; humans, security robots, captives and the friend
draw_human:
    ldx cur
    stz t10                 ; upper body drop
    ; leg frame
    lda a_type,x
    cmp #ET_SECBOT
    beq @rb
    lda a_vx,x
    beq :+
    lda a_anim,x
    lsr
    lsr
    and #6
    tay
    lda hu_walk,y
    bra @lg
:   lda #SPR_HU_LEGS_STAND
    ldy a_type,x
    cpy #ET_DEFENDER
    bne @lg
    lda #8
    sta t10
    lda #SPR_HU_LEGS_CROUCH
    bra @lg
@rb:lda a_vx,x
    beq :+
    lda a_anim,x
    lsr
    lsr
    and #6
    tay
    lda rb_walk,y
    bra @lg
:   lda #SPR_RB_LEGS_STAND
@lg:sta t7
    lda a_parts,x
    and #PART_LEGS
    bne :+
    lda #13                 ; no legs: body on the ground
    sta t10
    bra @torso
:   lda t7
    sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda #16
    jsr draw_part_x
@torso:
    ; muzzle flash
    ldx cur
    lda a_aux2,x
    beq @nofl
    dec a_aux2,x
    lda a_type,x
    cmp #ET_ELEVATOR
    bcs @nofl
    lda hu_arm_mx
    sta t0
    lda hu_arm_my
    sec
    sbc #4
    clc
    adc t10
    sta t1
    lda #SPR_FX_MUZZLE0
    ora #$0800              ; palette 4 (keep priority from t11 via draw_part)
    sta t2
    lda t0
    sec
    sbc #4
    sta t0
    lda #8
    jsr draw_part_fx
@nofl:
    ; gun arm
    ldx cur
    lda a_parts,x
    and #PART_ARM
    beq @noarm
    lda a_type,x
    cmp #ET_CAPTIVE
    bcs @noarm
    lda a_state,x
    cmp #AS_ATTACK
    bne :+
    jsr act_aim_index
    bra :++
:   lda #0
:   asl
    tay
    lda a_type,x
    cmp #ET_SECBOT
    bne :+
    lda rb_arm_ox,y
    sta t0
    lda rb_arm_oy,y
    sta t1
    lda rb_arm_tiles,y
    bra :++
:   lda hu_arm_ox,y
    sta t0
    lda hu_arm_oy,y
    sta t1
    lda hu_arm_tiles,y
:   sta t2
    lda t1
    clc
    adc t10
    sta t1
    lda #16
    jsr draw_part_x
@noarm:
    ; head
    ldx cur
    lda a_parts,x
    and #PART_HEAD
    beq @nohead
    lda a_type,x
    asl
    tay
    lda at_head,y
    sta t2
    lda #.loword(-3)
    sta t0
    lda #.loword(-32)
    clc
    adc t10
    sta t1
    lda #8
    jsr draw_part_x
@nohead:
    ; torso
    ldx cur
    lda #SPR_HU_TORSO
    ldy a_type,x
    cpy #ET_SECBOT
    bne :+
    lda #SPR_RB_TORSO
:   sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-26)
    clc
    adc t10
    sta t1
    lda #16
    jsr draw_part_x
    rts

; draw_part with t11 attr, then restore X
draw_part_x:
    jsr draw_part
    ldx cur
    rts

; effect sprite: like draw_part but keeps only the flip bit of t11
draw_part_fx:
    pha
    lda t11
    pha
    and #$4000
    ora #$2000
    sta t11
    pla
    sta t12
    pla
    jsr draw_part
    lda t12
    sta t11
    ldx cur
    rts

; aim index for drawing (0 fwd, 2 diag up, 3 diag down)
act_aim_index:
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    sec
    sbc p_py
    clc
    adc #.loword(-40)
    bmi :+
    lda #2
    rts
:   lda p_py
    sec
    sbc a_y+0,x
    lda a_y,x
    lsr
    lsr
    lsr
    lsr
    clc
    adc #40
    cmp p_py
    bcs :+
    lda #3
    rts
:   lda #0
    rts

hu_walk: .word SPR_HU_LEGS_WALK1, SPR_HU_LEGS_WALK2, SPR_HU_LEGS_WALK3, SPR_HU_LEGS_WALK4
rb_walk: .word SPR_RB_LEGS_WALK1, SPR_RB_LEGS_WALK2, SPR_RB_LEGS_WALK3, SPR_RB_LEGS_WALK4
hu_arm_tiles: .word SPR_HU_ARM0, SPR_HU_ARM1, SPR_HU_ARM2, SPR_HU_ARM3
rb_arm_tiles: .word SPR_RB_ARM0, SPR_RB_ARM1, SPR_RB_ARM2, SPR_RB_ARM3
hu_arm_ox: .word HU_ARM_OX
hu_arm_oy: .word HU_ARM_OY
hu_arm_mx: .word HU_ARM_MX
hu_arm_my: .word HU_ARM_MY
rb_arm_ox: .word RB_ARM_OX
rb_arm_oy: .word RB_ARM_OY
rb_arm_mx: .word RB_ARM_MX
rb_arm_my: .word RB_ARM_MY

draw_crawler:
    ldx cur
    lda a_anim,x
    and #4
    beq :+
    lda #SPR_CR_BODY1
    bra :++
:   lda #SPR_CR_BODY0
:   sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda a_parts,x
    and #PART_TOP
    beq :+
    lda t2
    pha
    lda #SPR_CR_TOP
    sta t2
    lda #.loword(-4)
    sta t0
    lda #.loword(-17)
    sta t1
    lda #8
    jsr draw_part_x
    pla
    sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
:   lda #16
    jmp draw_part_x

draw_drone:
    ldx cur
    lda a_parts,x
    and #PART_TOP
    beq :+
    lda #SPR_DR_GUN
    sta t2
    lda #.loword(-4)
    sta t0
    lda #.loword(-5)
    sta t1
    lda #8
    jsr draw_part_x
:   lda a_anim,x
    and #2
    beq :+
    lda #SPR_DR_BODY1
    bra :++
:   lda #SPR_DR_BODY0
:   sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda #16
    jmp draw_part_x

draw_heavy:
    ldx cur
    stz t10
    lda a_parts,x
    and #PART_ARM
    beq @noc
    lda #SPR_HV_CANNON
    sta t2
    lda #HV_ARM_OX
    sta t0
    lda #HV_ARM_OY
    sta t1
    lda #16
    jsr draw_part_x
@noc:
    lda a_parts,x
    and #PART_LEGS
    bne :+
    lda #16
    sta t10
    bra @body
:   lda a_anim,x
    and #16
    beq :+
    lda #(SPR_HV_LEGS1_L - SPR_HV_LEGS0_L)
:   clc
    adc #SPR_HV_LEGS0_L
    sta t7
    sta t2
    lda #.loword(-16)
    sta t0
    sta t1
    lda #16
    jsr draw_part_x
    lda t7
    clc
    adc #(SPR_HV_LEGS0_R - SPR_HV_LEGS0_L)
    sta t2
    stz t0
    lda #.loword(-16)
    sta t1
    lda #16
    jsr draw_part_x
@body:
    lda #SPR_HV_BODY_L
    sta t2
    lda #.loword(-16)
    sta t0
    lda #.loword(-32)
    clc
    adc t10
    sta t1
    lda #16
    jsr draw_part_x
    lda #SPR_HV_BODY_R
    sta t2
    stz t0
    lda #.loword(-32)
    clc
    adc t10
    sta t1
    lda #16
    jmp draw_part_x

draw_generator:
    ldx cur
    lda a_flags,x
    and #F_DONE
    beq :+
    lda #SPR_GEN2_TOP
    sta t2
    lda #SPR_GEN2_BOT
    bra @d
:   lda a_anim,x
    and #8
    beq :+
    lda #SPR_GEN1_TOP
    sta t2
    lda #SPR_GEN1_BOT
    bra @d
:   lda #SPR_GEN0_TOP
    sta t2
    lda #SPR_GEN0_BOT
@d: sta t7
    lda #.loword(-8)
    sta t0
    lda #.loword(-32)
    sta t1
    lda #16
    jsr draw_part_x
    lda t7
    sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda #16
    jmp draw_part_x

draw_terminal:
    ldx cur
    lda a_flags,x
    and #F_DONE
    beq :+
    lda #SPR_TERM2
    bra @d
:   lda a_anim,x
    and #16
    beq :+
    lda #SPR_TERM1
    bra @d
:   lda #SPR_TERM0
@d: sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-30)
    sta t1
    lda #16
    jsr draw_part_x
    lda #SPR_TERM_BASE
    sta t2
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda #16
    jmp draw_part_x

draw_elevator:
    ldx cur
    lda t11
    and #.loword(~$4000)
    sta t11
    lda #SPR_ELEV_L
    sta t2
    lda #.loword(-16)
    sta t0
    stz t1
    lda #8
    jsr draw_part_x
    lda #SPR_ELEV_M
    sta t2
    lda #.loword(-8)
    sta t0
    lda #8
    jsr draw_part_x
    lda #SPR_ELEV_M
    sta t2
    stz t0
    lda #8
    jsr draw_part_x
    lda #SPR_ELEV_R
    sta t2
    lda #8
    sta t0
    lda #8
    jmp draw_part_x

; ---------------------------------------------------------------- pickups
pickups_update:
    ldx #0
@l: lda en_type,x
    cmp #16
    bcs :+
    jmp @n
:   lda en_flags,x
    and #EN_DEAD
    beq :+
    jmp @n
:   stx cur
    ; on screen?
    lda en_x,x
    sec
    sbc cam_x
    sta t8
    clc
    adc #16
    cmp #(256 + 32)
    bcs @n
    lda en_y,x
    sec
    sbc cam_y
    sta t9
    clc
    adc #16
    cmp #(224 + 32)
    bcs @n
    ; touch?
    lda en_x,x
    sec
    sbc p_px
    clc
    adc #12
    cmp #24
    bcs @draw
    lda p_py
    sec
    sbc en_y,x
    clc
    adc #12
    cmp #36
    bcs @draw
    lda p_dead
    bne @draw
    jsr collect
    ldx cur
    bra @n
@draw:
    ; bob up and down
    lda frame
    clc
    adc cur
    lsr
    lsr
    lsr
    and #3
    tay
    lda bob_tbl,y
    clc
    adc t9
    sec
    sbc #16
    sta spr_y
    lda t8
    sec
    sbc #8
    sta spr_x
    lda en_type,x
    sec
    sbc #16
    asl
    tay
    lda pk_tiles,y
    sta spr_t
    lda #2
    sta spr_big
    jsr spr_add
    ldx cur
@n: inx
    inx
    cpx #MAX_ENT*2
    bcs :+
    jmp @l
:   rts

bob_tbl: .word 0, .loword(-1), .loword(-2), .loword(-1)
pk_tiles: .word SPR_PK_HEALTH|$2C00, SPR_PK_MG|$2C00, SPR_PK_PLASMA|$2C00, SPR_PK_EMP|$2C00, SPR_PK_RAIL|$2C00, SPR_PK_GRENADE|$2C00, SPR_PK_KEY|$2C00, SPR_PK_CHIP|$2C00

; collect pickup X
collect:
    lda en_flags,x
    ora #EN_DEAD
    sta en_flags,x
    lda en_type,x
    sec
    sbc #16
    asl
    tax
    jmp (collect_tbl,x)
collect_tbl: .addr c_health, c_mg, c_plasma, c_emp, c_rail, c_nade, c_key, c_chip

c_health:
    lda p_hp
    clc
    adc #35
    cmp #100
    bcc :+
    lda #100
:   sta p_hp
    lda #msg_health
    bra pk_done
c_mg:
    lda #150
    ldx #0
    ldy #500
    jsr add_ammo
    lda #msg_mg
    bra pk_done
c_plasma:
    lda #12
    ldx #4
    ldy #60
    jsr add_ammo
    lda #msg_plasma
    bra pk_done
c_emp:
    lda #3
    ldx #6
    ldy #15
    jsr add_ammo
    lda #msg_emp
    bra pk_done
c_rail:
    lda #4
    ldx #8
    ldy #20
    jsr add_ammo
    lda #msg_rail
    bra pk_done
c_nade:
    lda #4
    ldx #2
    ldy #20
    jsr add_ammo
    lda #msg_nade
    bra pk_done
c_key:
    lda #1
    sta has_key
    lda #msg_key
    bra pk_done
c_chip:
    lda #OBJ_COLLECT
    jsr obj_event
    lda #msg_chip
pk_done:
    jsr show_msg
    lda #SND_PICKUP
    jmp sfx

; A = amount, X = ammo offset, Y = max
add_ammo:
    sty t0
    clc
    adc p_ammo,x
    cmp t0
    bcc :+
    lda t0
:   sta p_ammo,x
    rts

; Drop a random pickup at t0/t1 (px). Falls to the floor.
spawn_drop:
    ; find the floor below
    lda #10
    sta t2
@f: ldy t1
    lda t0
    jsr attr_at
    and #(AT_SOLID | AT_PLATFORM)
    bne @found
    lda t1
    clc
    adc #16
    sta t1
    dec t2
    bne @f
    rts
@found:
    lda t1
    and #$FFF0
    sta t1
    jsr random
    and #15
    tay
    lda drop_kinds,y
    and #$00FF
    ldx drop_next
    sta en_type,x
    lda t0
    sta en_x,x
    lda t1
    sta en_y,x
    stz en_flags,x
    inx
    inx
    cpx #MAX_ENT*2
    bcc :+
    ldx #DROP_BASE*2
:   stx drop_next
    rts

drop_kinds: .byte ET_PK_MG, ET_PK_MG, ET_PK_MG, ET_PK_MG, ET_PK_MG, ET_PK_HEALTH, ET_PK_HEALTH, ET_PK_HEALTH
            .byte ET_PK_PLASMA, ET_PK_PLASMA, ET_PK_GRENADE, ET_PK_GRENADE, ET_PK_GRENADE, ET_PK_EMP, ET_PK_RAIL, ET_PK_HEALTH

; ---------------------------------------------------------------- objectives
; A = event kind (OBJ_*). Counts down the mission objective.
obj_event:
    cmp obj_type
    beq :+
    rts
:   lda obj_left
    beq @x
    dec obj_left
    lda obj_left
    bne @x
    ; objective complete
    lda obj_type
    cmp #OBJ_BOSS
    beq @win
    cmp #OBJ_KILL
    beq @win
    cmp #OBJ_FRIEND
    beq @friend
    jsr open_exit_doors
    lda #msg_exit_open
    jsr show_msg
    lda #SND_UNLOCK
    jsr sfx
@x: rts
@win:
    jmp mission_complete
@friend:
    lda #1
    sta p_win
    stz p_vx
    lda #msg_friend
    jsr show_msg
    jmp mission_complete
