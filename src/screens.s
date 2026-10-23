; ---------------------------------------------------------------- game states

; common setup for text screens: blank, load gfx, clear layers
screen_setup:
    jsr screen_off
    jsr ppu_setup
    jsr gfx_load_all
    lda #0
    jsr palette_setup
    jsr palette_upload
    jsr bg3_clear
    jsr oam_begin
    jsr oam_end
    stz hdma_on
    ; BG2 static at the skyline
    A8
    stz BG2HOFS
    stz BG2HOFS
    lda #$FF
    sta BG2VOFS
    lda #$03
    sta BG2VOFS
    A16
    lda #$FFFF
    sta next_state
    rts

; upload the BG3 shadow right now (forced blank)
bg3_upload:
    lda #VR_BG3MAP
    sta t0
    lda #.loword(BG3_SHADOW)
    sta ptr
    lda #^BG3_SHADOW
    sta ptr+2
    lda #2048
    sta t1
    jsr vram_load
    stz bg3_dirty
    rts

; t-less helper: A = string, Y = position, X = palette
print_c:
    stx txt_pal
    pha
    tya
    plx
    jmp print

; ================================================================ TITLE
title_init:
    jsr screen_setup
    A8
    lda #$16                ; BG2, BG3, OBJ
    sta TM
    A16
    ; logo: rows 3..8 of the BG2 map, palette 5 (neon)
    lda #(VR_BG2MAP + 2*32)
    sta t0
    lda #.loword(gfx_logo_map)
    sta ptr
    lda #^gfx_logo_map
    sta ptr+2
    lda #(32*6*2)
    sta t1
    jsr vram_load
    stz txt_opaque
    ldx #1
    ldy #(13*32 + 4)
    lda #.loword(s_title_sub)
    jsr print_c
    stz menu_sel
    jsr title_menu
    jsr bg3_upload
    lda #MUS_TITLE
    jsr music
    jsr fade_in
    rts

title_menu:
    ; options
    lda #0
    sta txt_pal
    ldx #.loword(s_new)
    lda #(17*32 + 11)
    jsr print
    ldx #.loword(s_cont)
    lda #(19*32 + 11)
    jsr print
    lda max_mission
    inc a
    ldx #2
    ldy #(19*32 + 29)
    jsr print_num
    ldx #.loword(s_gore)
    lda #(21*32 + 11)
    jsr print
    ldx #.loword(s_on)
    lda gore
    bne :+
    ldx #.loword(s_off)
:   lda #(21*32 + 18)
    jsr print
    lda #4
    sta txt_pal
    ldx #.loword(s_credit)
    lda #(25*32 + 3)
    jsr print
    ; cursor
    ldx #0
@c: txa
    asl
    asl
    asl
    asl
    asl
    asl                     ; *64 = 2 rows
    clc
    adc #(17*32 + 9)
    tay
    lda #(128 | TXT_ATTR)   ; blank
    cpx menu_sel
    bne :+
    lda #(HUD_ARROW + 128) | TXT_ATTR | (1 << 10)
:   phx
    jsr put_tile
    plx
    inx
    cpx #3
    bcc @c
    lda #2
    sta bg3_dirty
    rts

title_frame:
    lda joy_new
    and #(JOY_DOWN | JOY_SELECT)
    beq :+
    lda menu_sel
    inc a
    cmp #3
    bcc @s
    lda #0
@s: sta menu_sel
    lda #SND_SELECT
    jsr sfx
    jsr title_menu
:   lda joy_new
    and #JOY_UP
    beq :+
    lda menu_sel
    dec a
    bpl @s2
    lda #2
@s2:sta menu_sel
    lda #SND_SELECT
    jsr sfx
    jsr title_menu
:   lda joy_new
    and #(JOY_START | JOY_A | JOY_B)
    beq @x
    lda menu_sel
    cmp #2
    bne :+
    lda gore
    eor #1
    sta gore
    jsr sram_save
    lda #SND_SELECT
    jsr sfx
    jmp title_menu
:   cmp #1
    beq @cont
    stz mission
    bra @go
@cont:
    lda max_mission
    sta mission
@go:
    lda #SND_START
    jsr sfx
    lda #ST_BRIEF
    sta next_state
@x: ; the hero stands guard on the title screen
    jsr oam_begin
    lda #40
    sta t8
    lda #186
    sta t9
    lda #PL_ATTR
    sta t11
    jsr draw_hero_static
    jsr oam_end
    rts

; hero sprite (standing, gun forward) at t8/t9 with attr t11
draw_hero_static:
    lda p_aim
    pha
    stz p_aim
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda #SPR_PL_LEGS_STAND
    sta t2
    lda #16
    jsr draw_part
    lda #.loword(-26)
    sta t1
    lda #SPR_PL_TORSO
    sta t2
    lda #16
    jsr draw_part
    lda #.loword(-3)
    sta t0
    lda #.loword(-32)
    sta t1
    lda #SPR_PL_HEAD
    sta t2
    lda #8
    jsr draw_part
    lda pl_arm_ox
    sta t0
    lda pl_arm_oy
    sta t1
    lda #SPR_PL_ARM0
    sta t2
    lda #16
    jsr draw_part
    pla
    sta p_aim
    rts

s_title_sub: .byte "A DESCENT BELOW THE CITY", 0
s_new:    .byte "NEW GAME", 0
s_cont:   .byte "CONTINUE  MISSION", 0
s_gore:   .byte "GORE:", 0
s_on:     .byte "ON ", 0
s_off:    .byte "OFF", 0
s_credit: .byte "PRESS START  -  SNES 2026", 0

; ================================================================ BRIEFING
brief_init:
    jsr screen_setup
    A8
    lda #$04                ; BG3 only
    sta TM
    A16
    lda #1
    sta txt_opaque
    lda #(1 << 10) | TXT_ATTR   ; black background everywhere
    jsr bg3_fill
    lda #1
    sta txt_pal
    ldx #.loword(s_mission)
    lda #(3*32 + 4)
    jsr print
    lda mission
    inc a
    ldx #2
    ldy #(3*32 + 12)
    jsr print_num
    lda #4
    sta txt_pal
    lda mission
    asl
    tax
    lda mis_names,x
    tax
    lda #(3*32 + 16)
    jsr print
    stz txt_pal
    lda mission
    asl
    tax
    lda mis_brief,x
    tax
    lda #(7*32 + 3)
    jsr print
    lda #2
    sta txt_pal
    ldx #.loword(s_controls)
    lda #(19*32 + 3)
    jsr print
    lda #1
    sta txt_pal
    ldx #.loword(s_press_start)
    lda #(26*32 + 9)
    jsr print
    jsr bg3_upload
    lda #MUS_BRIEF
    jsr music
    jsr fade_in
    rts

brief_frame:
    lda state_timer
    cmp #20
    bcc @x
    lda joy_new
    and #(JOY_START | JOY_A | JOY_B)
    beq @x
    lda #SND_START
    jsr sfx
    lda #ST_PLAY
    sta next_state
@x: rts

s_mission:     .byte "MISSION", 0
s_press_start: .byte "PRESS START", 0
s_controls:
    .byte "B JUMP   Y FIRE   X GRENADE", 10
    .byte "A RUN    L/R CHANGE WEAPON", 10
    .byte "UP AIM/CLIMB  DOWN CROUCH", 10
    .byte "SELECT MAP    START PAUSE", 0

; ================================================================ PLAY
play_init:
    jsr screen_off
    jsr ppu_setup
    jsr gfx_load_all
    lda #$FFFF
    sta next_state
    ; mission parameters
    lda mission
    asl
    tax
    lda mis_obj,x
    sta obj_type
    lda mis_count,x
    sta obj_left
    sta obj_total
    lda mis_timer,x
    sta timer_sec
    sta timer_on
    lda mis_surface,x
    sta surface_y
    lda mis_depth,x
    sta depth_base
    stz has_key
    stz exit_open
    stz kills
    stz mis_frames
    stz mis_secs
    stz complete_t
    stz msg_timer
    stz shake
    stz quake
    stz timer_fr
    stz paused
    ldx #0
@g: stz gate_t,x
    inx
    inx
    cpx #16
    bcc @g
    jsr map_load
    lda mission
    jsr palette_setup
    jsr palette_upload
    jsr actors_clear
    jsr pt_clear
    jsr player_reset_ammo
    jsr player_spawn
    jsr camera_snap
    ; upload BG1 now (forced blank)
    lda #VR_BG1MAP
    sta t0
    lda #.loword(BG1_SHADOW)
    sta ptr
    lda #^BG1_SHADOW
    sta ptr+2
    lda #2048
    sta t1
    jsr vram_load
    stz bg1_dirty
    jsr bg3_clear
    jsr hud_draw
    jsr bg3_upload
    jsr play_draw
    ; intro message
    lda timer_on
    beq :+
    lda #.loword(msg_hurry)
    jsr show_msg
    lda #1
    sta quake
:   lda mission
    asl
    tax
    lda mis_music,x
    jsr music
    jsr fade_in
    rts

play_frame:
    ; pause
    lda joy_new
    and #JOY_START
    beq :+
    lda complete_t
    ora p_dead
    bne :+
    lda paused
    eor #1
    sta paused
    jsr pause_text
    lda #SND_SELECT
    jsr sfx
:   lda paused
    beq :+
    rts
:   ; automap
    lda joy_new
    and #JOY_SELECT
    beq :+
    lda complete_t
    ora p_dead
    bne :+
    lda #ST_MAP
    sta next_state
    rts
:
.ifdef AUTOTEST
    jsr read_vline
    sta prof_frame0
.endif
    PROF player_update, 0
    PROF actors_spawn_scan, 1
    PROF actors_update, 2
    PROF pb_update, 3
    PROF eb_update, 4
    PROF pt_update, 5
    jsr gates_update
    jsr mission_clock
    jsr collapse_fx
    PROF camera_update, 6
    PROF play_draw, 7
    PROF hud_update, 8
.ifdef AUTOTEST
    jsr prof_frame_end
.endif
    ; mission complete countdown
    lda complete_t
    beq @x
    inc complete_t
    lda complete_t
    cmp #120
    bcc @x
    lda mission
    cmp #9
    bne :+
    lda #ST_VICTORY
    sta next_state
    rts
:   lda #ST_CLEAR
    sta next_state
@x: rts

play_draw:
    jsr oam_begin
    jsr player_draw
    jsr pb_draw
    jsr eb_draw
    jsr actors_draw
    jsr pickups_update
    jsr pt_draw
    jsr oam_end
    rts

pause_text:
    lda #1
    sta txt_opaque
    lda #1
    sta txt_pal
    lda paused
    beq @clear
    ldx #.loword(s_paused)
    lda #(12*32 + 12)
    jsr print
    bra @d
@clear:
    ldx #.loword(s_unpause)
    lda #(12*32 + 12)
    jsr print
    ; make that row transparent again
    ldx #(12*32*2)
    lda #(128 | TXT_ATTR)
@c: sta f:BG3_SHADOW,x
    inx
    inx
    cpx #(13*32*2)
    bcc @c
@d: lda #2
    sta bg3_dirty
    rts
s_paused:  .byte " PAUSED ", 0
s_unpause: .byte "        ", 0

; seconds counter, countdown for timed missions
mission_clock:
    lda complete_t
    ora p_dead
    bne @x
    inc mis_frames
    lda mis_frames
    cmp #60
    bcc @x
    stz mis_frames
    inc mis_secs
    lda timer_on
    beq @x
    lda timer_sec
    beq @x
    dec timer_sec
    lda timer_sec
    cmp #11
    bcs :+
    lda #SND_BEEP
    jsr sfx
:   lda timer_sec
    bne @x
    ; time is up: the tunnels cave in
    lda #100
    sta p_inv
    stz p_inv
    lda #200
    jsr player_hurt
@x: rts

; Collapse mission: periodic rumbles that shake the screen and drop rocks
collapse_fx:
    lda quake
    beq @x
    lda complete_t
    ora p_dead
    bne @x
    lda mis_frames
    bne :+
    lda mis_secs
    and #3
    bne :+
    lda #45
    sta shake
    lda #SND_BOOM
    jsr sfx
:   lda shake
    beq @x
    jsr random
    and #7
    bne @x
    ; a rock falls from the ceiling somewhere on screen
    jsr random
    and #255
    clc
    adc cam_x
    sta t0
    lda cam_y
    clc
    adc #24
    sta t1
    jsr fx_rock_chunk
@x: rts

mission_complete:
    lda complete_t
    bne @x
    lda #1
    sta complete_t
    sta p_win
    stz p_vx
    stz quake
    lda #.loword(msg_complete)
    jsr show_msg
    lda #MUS_CLEAR
    jsr music
@x: rts

; ================================================================ MAP VIEW
map_init:
    jsr screen_off
    lda #$FFFF
    sta next_state
    ; build the automap characters (4bpp, only planes 0-1 used)
    jsr automap_build
    stz scroll_x
    lda #$FFFF
    sta scroll_y
    stz hdma_on
    A8
    lda #$09                ; mode 1, BG3 priority, 8x8 tiles
    sta BGMODE
    lda #$15                ; BG1, BG3, OBJ
    sta TM
    stz BG1HOFS
    stz BG1HOFS
    lda #$FF
    sta BG1VOFS
    sta BG1VOFS
    A16
    lda #VR_BG1CHR
    sta t0
    lda #.loword(AUTOMAP_CHR)
    sta ptr
    lda #^AUTOMAP_CHR
    sta ptr+2
    lda #16384
    sta t1
    jsr vram_load
    ; BG1 tilemap: 32x16 chars at rows 6..21, palette 2
    ldx #0
@m: txa
    lsr
    sec
    sbc #(6*32)
    bcc @blank
    cmp #(16*32)
    bcs @blank
    ora #(2 << 10)
    bra @put
@blank:
    lda #0
@put:
    sta f:BG1_SHADOW,x
    inx
    inx
    cpx #2048
    bcc @m
    lda #VR_BG1MAP
    sta t0
    lda #.loword(BG1_SHADOW)
    sta ptr
    lda #^BG1_SHADOW
    sta ptr+2
    lda #2048
    sta t1
    jsr vram_load
    ; automap colors in BG palette 2 (CGRAM 32-35)
    lda #$0000
    sta pal_buf+64
    lda #$2D6B              ; solid: warm gray
    sta pal_buf+66
    lda #$3C84              ; open: dark blue
    sta pal_buf+68
    lda #$03FF              ; special: yellow
    sta pal_buf+70
    jsr palette_upload
    ; labels
    jsr bg3_clear
    lda #1
    sta txt_opaque
    lda #1
    sta txt_pal
    ldx #.loword(s_map)
    lda #(2*32 + 3)
    jsr print
    lda #4
    sta txt_pal
    lda mission
    asl
    tax
    lda mis_names,x
    tax
    lda #(2*32 + 13)
    jsr print
    stz txt_pal
    ldx #.loword(s_map_legend)
    lda #(24*32 + 3)
    jsr print
    jsr bg3_upload
    jsr map_markers
    lda #SND_SELECT
    jsr sfx
    jsr fade_in
    rts

map_frame:
    jsr map_markers
    lda joy_new
    and #(JOY_SELECT | JOY_START | JOY_B)
    beq @x
    ; back to the game without resetting the mission
    jsr screen_off
    lda #$FFFF
    sta next_state
    lda #ST_PLAY
    sta game_state
    jsr ppu_setup
    jsr gfx_load_all
    lda mission
    jsr palette_setup
    jsr palette_upload
    jsr bg3_clear
    jsr hud_draw
    jsr bg3_upload
    lda cam_x
    lsr
    lsr
    lsr
    lsr
    sta cam_tx
    lda cam_y
    lsr
    lsr
    lsr
    lsr
    sta cam_ty
    jsr map_draw_all
    lda #VR_BG1MAP
    sta t0
    lda #.loword(BG1_SHADOW)
    sta ptr
    lda #^BG1_SHADOW
    sta ptr+2
    lda #2048
    sta t1
    jsr vram_load
    stz bg1_dirty
    jsr play_draw
    jsr fade_in
@x: rts

s_map:        .byte "AREA MAP", 0
s_map_legend: .byte "YOU", 10, 10, "OBJECTIVES / EXIT", 0

; markers: player (blinking) + objectives, as sprites over the map
map_markers:
    jsr oam_begin
    lda frame
    and #16
    beq :+
    lda p_px
    jsr map_sx
    sta spr_x
    lda p_py
    sec
    sbc #16
    jsr map_sy
    sta spr_y
    lda #(SPR_UI_MARKER | $2C00)
    sta spr_t
    stz spr_big
    jsr spr_add
:   ; legend icons
    lda #16
    sta spr_x
    lda #(24*8)
    sta spr_y
    lda #(SPR_UI_MARKER | $2C00)
    sta spr_t
    stz spr_big
    jsr spr_add
    lda #(26*8)
    sta spr_y
    lda #(SPR_UI_TARGET | $2C00)
    sta spr_t
    jsr spr_add
    ; exit (only if explored or open)
    lda mission
    asl
    tax
    lda mis_exit_x,x
    beq @noexit
    jsr map_sx
    sta spr_x
    lda mis_exit_y,x
    jsr map_sy
    sta spr_y
    lda #(SPR_UI_TARGET | $2C00)
    sta spr_t
    jsr spr_add
@noexit:
    ; objective entities still pending
    ldx #0
@l: lda en_flags,x
    and #(EN_DEAD | EN_DONE)
    bne @n
    lda en_type,x
    cmp #ET_PK_CHIP
    beq @show
    cmp #ET_GENERATOR
    beq @show
    cmp #ET_TERMINAL
    beq @show
    cmp #ET_CAPTIVE
    beq @show
    cmp #ET_FRIEND
    beq @show
    cmp #ET_BOSS
    beq @show
    cmp #ET_COMMANDER
    bne @n
@show:
    phx
    lda en_x,x
    jsr map_sx
    sta spr_x
    lda en_y,x
    jsr map_sy
    sta spr_y
    lda #(SPR_UI_TARGET | $2C00)
    sta spr_t
    stz spr_big
    jsr spr_add
    plx
@n: inx
    inx
    cpx #MAX_ENT*2
    bcc @l
    jsr oam_end
    rts

; world px -> map screen coordinates (map is 2x2 px per 16px tile)
map_sx:
    lsr
    lsr
    lsr
    sec
    sbc #4
    rts
map_sy:
    lsr
    lsr
    lsr
    clc
    adc #(6*8 - 4)
    rts

; Build 512 chars of automap into AUTOMAP_CHR. Unexplored blocks stay blank.
automap_build:
    ; clear 16KB
    lda #0
    ldx #0
@clr:
    sta f:AUTOMAP_CHR,x
    inx
    inx
    cpx #16384
    bcc @clr
    stz t0                  ; char index (by*32 + bx)
@char:
    ; explored?
    lda t0
    lsr
    lsr
    lsr
    tax                     ; byte = index/8 (bits row-major: by*32+bx)
    lda t0
    and #7
    tay
    A8
    lda explored,x
    and bitmask8,y
    A16
    and #$00FF
    bne :+
    jmp @nextc
:   ; char data offset = t0 * 32
    lda t0
    asl
    asl
    asl
    asl
    asl
    sta t1
    ; first map cell: x = bx*4, y = by*4 -> index = y*128 + x
    lda t0
    and #31
    asl
    asl
    sta t2                  ; cell x
    lda t0
    lsr
    lsr
    lsr
    lsr
    lsr
    asl
    asl
    sta t3                  ; cell y
    stz t4                  ; row 0..3
@row:
    ; map index
    lda t3
    clc
    adc t4
    xba
    lsr                     ; *128
    clc
    adc t2
    tax
    stz t5                  ; plane 0 byte
    stz t6                  ; plane 1 byte
    lda #4
    sta t7
@cell:
    lda f:MAPBUF,x
    and #$00FF
    tay
    lda mt_attr,y
    and #$00FF
    ; classify: 1 solid, 2 open, 3 special (ladder/door/exit/hazard)
    bit #(AT_LADDER | AT_DOOR | AT_EXIT | AT_HAZARD)
    beq :+
    lda #3
    bra @cv
:   lsr
    bcc :+
    lda #1
    bra @cv
:   lda #2
@cv:
    ; shift two pixels into the plane bytes
    sta t8
    lda t5
    asl
    asl
    sta t5
    lda t6
    asl
    asl
    sta t6
    lda t8
    lsr
    bcc :+
    lda t5
    ora #3
    sta t5
:   lda t8
    and #2
    beq :+
    lda t6
    ora #3
    sta t6
:   inx
    dec t7
    bne @cell
    ; store two pixel rows (row*2, row*2+1) of planes 0/1
    lda t4
    asl
    asl
    clc
    adc t1
    tax
    A8
    lda t5
    sta f:AUTOMAP_CHR,x
    sta f:AUTOMAP_CHR+2,x
    lda t6
    sta f:AUTOMAP_CHR+1,x
    sta f:AUTOMAP_CHR+3,x
    A16
    inc t4
    lda t4
    cmp #4
    bcs :+
    jmp @row
:
@nextc:
    inc t0
    lda t0
    cmp #512
    bcs :+
    jmp @char
:
    rts

; ================================================================ FAILED
failed_init:
    jsr screen_setup
    A8
    lda #$04
    sta TM
    A16
    lda #1
    sta txt_opaque
    lda #(1 << 10) | TXT_ATTR
    jsr bg3_fill
    lda #3
    sta txt_pal
    ldx #.loword(s_failed)
    lda #(11*32 + 9)
    jsr print
    stz txt_pal
    ldx #.loword(s_retry)
    lda #(15*32 + 6)
    jsr print
    jsr bg3_upload
    lda #MUS_FAIL
    jsr music
    jsr fade_in
    rts

failed_frame:
    lda state_timer
    cmp #30
    bcc @x
    lda joy_new
    and #(JOY_START | JOY_A | JOY_B)
    beq @x
    lda #ST_PLAY
    sta next_state
@x: rts

s_failed: .byte "MISSION FAILED", 0
s_retry:  .byte "PRESS START TO RETRY", 0

; ================================================================ CLEAR
clear_init:
    jsr screen_setup
    A8
    lda #$04
    sta TM
    A16
    ; unlock the next mission
    lda mission
    inc a
    cmp max_mission
    bcc :+
    beq :+
    sta max_mission
:   lda max_mission
    cmp #10
    bcc :+
    lda #9
    sta max_mission
:   jsr sram_save
    lda #1
    sta txt_opaque
    lda #(1 << 10) | TXT_ATTR
    jsr bg3_fill
    lda #2
    sta txt_pal
    ldx #.loword(s_mission)
    lda #(8*32 + 7)
    jsr print
    lda mission
    inc a
    ldx #2
    ldy #(8*32 + 15)
    jsr print_num
    ldx #.loword(s_complete)
    lda #(8*32 + 18)
    jsr print
    stz txt_pal
    ldx #.loword(s_kills)
    lda #(12*32 + 8)
    jsr print
    lda kills
    ldx #3
    ldy #(12*32 + 21)
    jsr print_num
    ldx #.loword(s_time)
    lda #(14*32 + 8)
    jsr print
    lda mis_secs
    jsr div60
    ldy t5
    sty t3
    ldx #2
    ldy #(14*32 + 20)
    jsr print_num
    ldx #.loword(s_colon)
    lda #(14*32 + 22)
    jsr print
    lda t3
    ldx #2
    ldy #(14*32 + 23)
    jsr print_num
    ldx #.loword(s_health)
    lda #(16*32 + 8)
    jsr print
    lda p_hp
    ldx #3
    ldy #(16*32 + 21)
    jsr print_num
    lda #1
    sta txt_pal
    ldx #.loword(s_press_start)
    lda #(22*32 + 10)
    jsr print
    jsr bg3_upload
    jsr fade_in
    rts

clear_frame:
    lda state_timer
    cmp #30
    bcc @x
    lda joy_new
    and #(JOY_START | JOY_A | JOY_B)
    beq @x
    inc mission
    lda #ST_BRIEF
    sta next_state
@x: rts

s_complete: .byte "COMPLETE", 0
s_kills:    .byte "ENEMIES DOWN", 0
s_time:     .byte "TIME", 0
s_health:   .byte "ARMOR LEFT", 0

; ================================================================ VICTORY
victory_init:
    jsr screen_setup
    A8
    lda #$16                ; BG2 skyline, BG3 text, sprites
    sta TM
    A16
    lda #9
    sta max_mission
    jsr sram_save
    stz txt_opaque
    lda #1
    sta txt_pal
    ldx #.loword(s_v1)
    lda #(2*32 + 2)
    jsr print
    stz txt_pal
    ldx #.loword(s_v2)
    lda #(9*32 + 2)
    jsr print
    lda #4
    sta txt_pal
    ldx #.loword(s_v3)
    lda #(25*32 + 6)
    jsr print
    jsr bg3_upload
    lda #MUS_VICTORY
    jsr music
    jsr fade_in
    rts

victory_frame:
    ; the two heroes on the street at dawn
    jsr oam_begin
    lda #110
    sta t8
    lda #190
    sta t9
    lda #PL_ATTR
    sta t11
    jsr draw_hero_static
    ; friend, facing the player
    lda #146
    sta t8
    lda #($2E00 | $4000)
    sta t11
    lda #.loword(-8)
    sta t0
    lda #.loword(-16)
    sta t1
    lda #SPR_HU_LEGS_STAND
    sta t2
    lda #16
    jsr draw_part
    lda #.loword(-8)
    sta t0
    lda #.loword(-26)
    sta t1
    lda #SPR_HU_TORSO
    sta t2
    lda #16
    jsr draw_part
    lda #.loword(-3)
    sta t0
    lda #.loword(-32)
    sta t1
    lda #SPR_HU_HEAD_FRIEND
    sta t2
    lda #8
    jsr draw_part
    ; fireworks-ish sparks
    lda frame
    and #7
    bne :+
    jsr random
    and #127
    clc
    adc #64
    sta t0
    jsr random
    and #63
    clc
    adc #40
    sta t1
    ; (screen space particles: camera is at 0,0 here)
    stz cam_x
    stz cam_y
    jsr fx_explosion_small
:   jsr pt_update
    jsr pt_draw
    jsr oam_end
    lda state_timer
    cmp #120
    bcc @x
    lda joy_new
    and #JOY_START
    beq @x
    lda #ST_TITLE
    sta next_state
@x: rts

s_v1: .byte "MISSION ACCOMPLISHED", 0
s_v2:
    .byte "YOUR FRIEND IS FREE. TOGETHER", 10
    .byte "YOU CLIMB THE LONG SHAFT BACK", 10
    .byte "TO THE STREETS AS THE SUN", 10
    .byte "RISES OVER THE CITY.", 10, 10
    .byte "THE LABYRINTH BELOW IS SILENT", 10
    .byte "... FOR NOW.", 0
s_v3: .byte "THANKS FOR PLAYING!", 0

; ---------------------------------------------------------------- SRAM
SRAM = $700000

sram_load:
    lda f:SRAM
    cmp #$4C55              ; "UL"
    bne @fresh
    lda f:SRAM+2
    cmp #10
    bcs @fresh
    sta max_mission
    lda f:SRAM+4
    and #1
    sta gore
    rts
@fresh:
    stz max_mission
    lda #1
    sta gore
    rts

sram_save:
    lda #$4C55
    sta f:SRAM
    lda max_mission
    sta f:SRAM+2
    lda gore
    sta f:SRAM+4
    rts
