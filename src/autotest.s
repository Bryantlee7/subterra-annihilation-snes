; ---------------------------------------------------------------- autotest
; Scripted joypad input for headless testing. AUTOTEST builds include
; build/autotest_script.inc: pairs of (.word frames, .word buttons).
.include "../build/autotest_script.inc"

autotest_input:
    ; A = real joypad (ignored)
    phx
@again:
    ldx at_pos
    lda at_script,x
    beq @end
    cmp #$FFFF
    bne @nowarp
    ; WARP: [$FFFF, x] [$FFFE, y]
    lda at_script+2,x
    sta p_px
    asl
    asl
    asl
    asl
    sta p_x
    lda at_script+6,x
    sta p_py
    asl
    asl
    asl
    asl
    sta p_y
    stz p_vy
    stz p_climb
    txa
    clc
    adc #8
    sta at_pos
    stz at_count
    phy
    jsr camera_snap
    ply
    bra @again
@nowarp:
    lda at_count
    cmp at_script,x
    bcc @hold
    stz at_count
    inx
    inx
    inx
    inx
    stx at_pos
    bra @again
@hold:
    inc at_count
    lda at_script+2,x
    plx
    rts
@end:
    plx
    lda #0
    rts

autotest_dump:
    ; debug values into SRAM for inspection
    lda p_px
    sta f:$700010
    lda p_py
    sta f:$700012
    lda p_hp
    sta f:$700014
    lda game_state
    sta f:$700016
    lda cam_x
    sta f:$700018
    lda cam_y
    sta f:$70001A
    lda frame
    sta f:$70001C
    lda nmi_count
    sec
    sbc frame
    sta f:$700020           ; lag frames (+ title/load frames)
    ; per-frame trace ring: weapon<<8 | low joypad byte
    lda frame
    and #255
    asl
    tax
    lda joy
    and #$00F0
    sta at_tmp
    lda joy
    and #JOY_Y
    beq :+
    lda #1
    tsb at_tmp
:   lda p_weapon
    xba
    ora at_tmp
    sta f:$700600,x
    ; interrupted program counter (see NMI stack layout)
    tsc
    tax
    lda a:$000D,x
    sta f:$70001E
    rts

; read the current scanline -> A
read_vline:
    A8
    lda $213F               ; reset the OPHCT/OPVCT read flip-flop
    lda $2137               ; latch H/V counters
    lda $213D
    xba
    lda $213D
    and #1
    xba
    A16
    rts

prof_begin:
    jsr read_vline
    sta prof_t
    rts

; A = slot*2
prof_end:
    pha
    jsr read_vline
    sec
    sbc prof_t
    bpl :+
    clc
    adc #262
:   sta prof_t
    pla
    tax
    lda prof_sum,x
    clc
    adc prof_t
    sta prof_sum,x
    sta f:$700040,x
    rts

; per-frame total: track the maximum and count frames over 200 lines
prof_frame_end:
    jsr read_vline
    sec
    sbc prof_frame0
    bpl :+
    clc
    adc #262
:   pha
    ; histogram in 32-line buckets at $700080
    lsr
    lsr
    lsr
    lsr
    and #$FFFE
    tax
    lda f:$700080,x
    inc a
    sta f:$700080,x
    pla
    cmp prof_max
    bcc :+
    sta prof_max
    sta f:$700060
:   cmp #180
    bcc :+
    inc prof_over
    lda prof_over
    sta f:$700062
:   rts
