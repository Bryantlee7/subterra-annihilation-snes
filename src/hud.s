; ---------------------------------------------------------------- HUD
; BG3 rows 0-1, opaque black strip at the top of the screen.

HUD_SEG_FULL  = 64
HUD_SEG_EMPTY = 65
HUD_SEG_HALF  = 66
HUD_ARROW     = 68
HUD_HEART     = 69
HUD_KEY       = 70
HUD_SKULL     = 71

; A = message string address
show_msg:
    sta msg_ptr
    lda #150
    sta msg_timer
    rts

hud_update:
    lda msg_timer
    beq :+
    dec msg_timer
:   lda hud_dirty
    beq hud_refresh
    jmp hud_draw

; clear n cells (t9) starting at position Y (row 0/1) with opaque spaces
hud_clear_cells:
    tya
    asl
    tax
    lda #TXT_ATTR
@c: sta f:BG3_SHADOW,x
    inx
    inx
    dec t9
    bne @c
    rts

; redraw only the parts of the HUD whose values changed
hud_refresh:
    stz t10                 ; anything drawn?
    lda #1
    sta txt_opaque
    lda p_hp
    cmp hc_hp
    beq :+
    jsr hud_hp
    inc t10
:   lda p_weapon
    asl
    tax
    lda p_ammo,x
    cmp hc_ammo
    bne @wp
    lda p_weapon
    cmp hc_wpn
    beq :+
@wp:jsr hud_weapon
    inc t10
:   lda p_ammo+2
    cmp hc_nade
    beq :+
    jsr hud_nades
    inc t10
:   lda has_key
    cmp hc_key
    beq :+
    jsr hud_key
    inc t10
:   ; row 1 signature: message, objective count, timer, depth
    jsr hud_row1_sig
    cmp hc_row1
    beq :+
    jsr hud_row1
    inc t10
:   lda t10
    beq @x
    lda bg3_dirty
    bne @x
    lda #1
    sta bg3_dirty
@x: rts

hud_row1_sig:
    lda msg_timer
    beq :+
    lda msg_ptr
    eor #$5A5A
    rts
:   lda timer_on
    beq :+
    lda timer_sec
    ora #$8000
    rts
:   lda p_py
    lsr
    lsr
    lsr
    lsr
    xba
    ora obj_left
    rts

hud_draw:
    stz hud_dirty
    lda #1
    sta txt_opaque
    ; clear both rows (opaque spaces)
    ldx #0
    lda #TXT_ATTR
@c: sta f:BG3_SHADOW,x
    inx
    inx
    cpx #128
    bcc @c
    stz txt_pal
    ldx #.loword(s_hp)
    lda #0
    jsr print
    ; mission number
    lda #4
    sta txt_pal
    ldx #.loword(s_m)
    lda #29
    jsr print
    lda mission
    inc a
    ldx #2
    ldy #30
    jsr print_num
    lda #2
    sta txt_pal
    ldx #.loword(s_g)
    lda #23
    jsr print
    jsr hud_hp
    jsr hud_weapon
    jsr hud_nades
    jsr hud_key
    jsr hud_row1
    lda bg3_dirty
    bne :+
    lda #1
    sta bg3_dirty
:   rts

hud_hp:
    lda p_hp
    sta hc_hp
    lda #(2 << 10) | TXT_ATTR
    ldy p_hp
    cpy #30
    bcs :+
    lda #(3 << 10) | TXT_ATTR
:   sta t10
    lda p_hp
    jsr div10
    sta t9                  ; full segments
    ldy #2
    ldx #0
@seg:
    cpx t9
    bcc @full
    bne @empty
    lda t5
    cmp #5
    bcc @empty
    lda #HUD_SEG_HALF
    bra @put
@full:
    lda #HUD_SEG_FULL
    bra @put
@empty:
    lda #HUD_SEG_EMPTY
@put:
    ora t10
    phx
    jsr put_tile
    plx
    iny
    inx
    cpx #10
    bcc @seg
    rts

hud_weapon:
    lda p_weapon
    sta hc_wpn
    asl
    tax
    lda p_ammo,x
    sta hc_ammo
    lda #1
    sta txt_pal
    lda p_weapon
    asl
    tax
    lda wpn_names,x
    tax
    lda #13
    jsr print
    stz txt_pal
    lda p_weapon
    asl
    tax
    lda p_ammo,x
    ldx #3
    ldy #18
    jsr print_num
    ; MG out of ammo shows a sidearm marker instead
    lda p_weapon
    bne :+
    lda p_ammo
    bne :+
    ldx #.loword(s_inf)
    lda #18
    jsr print
:   rts

hud_nades:
    lda p_ammo+2
    sta hc_nade
    stz txt_pal
    lda p_ammo+2
    ldx #2
    ldy #24
    jmp print_num

hud_key:
    lda has_key
    sta hc_key
    ldy #27
    lda #TXT_ATTR
    ldx has_key
    beq :+
    lda #HUD_KEY | (4 << 10) | TXT_ATTR
:   jmp put_tile

hud_row1:
    jsr hud_row1_sig
    sta hc_row1
    lda #32
    sta t9
    ldy #32
    jsr hud_clear_cells
    lda msg_timer
    beq @status
    lda #1
    sta txt_pal
    ldx msg_ptr
    lda #33
    jmp print
@status:
    lda #4
    sta txt_pal
    lda obj_left
    bne @obj
    lda obj_type
    cmp #OBJ_TIMED
    beq @obj
    cmp #OBJ_EXIT
    beq @obj
    ldx #.loword(s_go_exit)
    lda #32
    jsr print
    bra @depth
@obj:
    lda obj_type
    asl
    tax
    lda obj_names,x
    tax
    lda #32
    jsr print
    ; counter: done/total (only for multi-part objectives)
    lda obj_total
    cmp #2
    bcc @depth
    stz txt_pal
    lda obj_total
    sec
    sbc obj_left
    ldx #1
    ldy #53
    jsr print_num
    ldx #.loword(s_slash)
    lda #54
    jsr print
    lda obj_total
    ldx #1
    ldy #55
    jsr print_num
@depth:
    lda timer_on
    beq @nodepth_timer
    ; countdown m:ss
    lda #3
    sta txt_pal
    ldx #.loword(s_t)
    lda #58
    jsr print
    lda timer_sec
    jsr div60
    ldy t5
    sty t3
    ldx #1
    ldy #59
    jsr print_num
    ldx #.loword(s_colon)
    lda #60
    jsr print
    lda t3
    ldx #2
    ldy #61
    jmp print_num
@nodepth_timer:
    ; depth in meters
    stz txt_pal
    lda p_py
    lsr
    lsr
    lsr
    lsr
    clc
    adc depth_base
    ldx #4
    ldy #58
    jsr print_num
    ldx #.loword(s_meters)
    lda #62
    jmp print

; A / 60 -> A, remainder in t5
div60:
    sta WRDIVL
    A8
    lda #60
    sta WRDIVB
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    sta t5
    lda RDDIVL
    rts

s_hp:      .byte "HP", 0
s_inf:     .byte "--", 0
s_g:       .byte "G", 0
s_m:       .byte "M", 0
s_slash:   .byte "/", 0
s_t:       .byte "T", 0
s_colon:   .byte ":", 0
s_meters:  .byte "M", 0
s_go_exit: .byte "GO TO THE EXIT LIFT", 0

wpn_names: .addr w_mg, w_gr, w_pl, w_emp, w_rail
w_mg:   .byte "MGUN", 0
w_gr:   .byte "GREN", 0
w_pl:   .byte "PLSM", 0
w_emp:  .byte "EMP ", 0
w_rail: .byte "RAIL", 0

obj_names: .addr o_exit, o_collect, o_destroy, o_boss, o_emp, o_rescue, o_timed, o_kill, o_friend
o_exit:    .byte "FIND THE EXIT LIFT", 0
o_collect: .byte "DATA CHIPS", 0
o_destroy: .byte "GENERATORS DOWN", 0
o_boss:    .byte "DESTROY THE SENTINEL", 0
o_emp:     .byte "TERMINALS OFF", 0
o_rescue:  .byte "CAPTIVES FREED", 0
o_timed:   .byte "ESCAPE THE COLLAPSE", 0
o_kill:    .byte "KILL THE COMMANDER", 0
o_friend:  .byte "FIND YOUR FRIEND", 0

; messages
msg_obj_first: .byte "COMPLETE THE OBJECTIVE FIRST", 0
msg_need_key:  .byte "LOCKED: NEEDS A KEYCARD", 0
msg_need_emp:  .byte "SECURITY DOOR: USE EMP", 0
msg_unlocked:  .byte "KEYCARD ACCEPTED", 0
msg_no_ammo:   .byte "OUT OF AMMO", 0
msg_health:    .byte "MEDKIT +35", 0
msg_mg:        .byte "MACHINE GUN AMMO", 0
msg_plasma:    .byte "PLASMA CELLS", 0
msg_emp:       .byte "EMP CHARGES", 0
msg_rail:      .byte "RAILGUN SLUGS", 0
msg_nade:      .byte "GRENADES", 0
msg_key:       .byte "GOT A KEYCARD!", 0
msg_chip:      .byte "DATA CHIP RECOVERED", 0
msg_exit_open: .byte "EXIT LIFT UNLOCKED!", 0
msg_rescued:   .byte "CAPTIVE RESCUED!", 0
msg_generator: .byte "GENERATOR DESTROYED", 0
msg_terminal:  .byte "TERMINAL DISABLED", 0
msg_friend:    .byte "YOU FOUND YOUR FRIEND!", 0
msg_complete:  .byte "MISSION COMPLETE!", 0
msg_hurry:     .byte "THE TUNNELS ARE COLLAPSING!", 0
