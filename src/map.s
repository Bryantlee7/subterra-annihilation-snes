; ---------------------------------------------------------------- map engine
; Map: 128x64 metatiles (16x16 px) at MAPBUF. BG1 uses 16x16 tiles with a
; 32x32 wrapping tilemap; a 19x17 window around the camera is kept drawn.

MAP_W_PX = 2048
MAP_H_PX = 1024

; Load map + entities for `mission` (forced blank)
map_load:
    AXY16
    lda mission
    asl
    asl
    tax                     ; 4 bytes per far pointer entry
    lda map_ptrs,x
    sta ptr
    lda map_ptrs+2,x
    sta ptr+2
    lda #.loword(MAPBUF)
    sta t0
    lda #^MAPBUF
    sta t1
    lda #8192
    sta t2
    jsr wram_copy
    ; entity list (ROM: type, param bytes, x, y words)
    lda mission
    sta t0
    asl
    clc
    adc t0                  ; mission*3
    tax
    lda mis_ents,x
    sta ptr
    lda mis_ents+2,x
    and #$00FF
    sta ptr+2
    ldy #0
    ldx #0
@ent:
    lda [ptr],y
    and #$00FF
    beq @entdone
    sta en_type,x
    iny
    lda [ptr],y
    and #$00FF
    sta en_param,x
    iny
    lda [ptr],y
    sta en_x,x
    iny
    iny
    lda [ptr],y
    sta en_y,x
    iny
    iny
    stz en_flags,x
    inx
    inx
    cpx #DROP_BASE*2
    bcc @ent
@entdone:
    ; clear drop slots
@dc:cpx #MAX_ENT*2
    bcs @dd
    stz en_type,x
    lda #1
    sta en_flags,x
    inx
    inx
    bra @dc
@dd:
    lda #DROP_BASE*2
    sta drop_next
    lda #MAX_ENT
    sta en_count
    ; explored bits
    ldx #0
@ex:stz explored,x
    inx
    inx
    cpx #64
    bcc @ex
    rts

; Camera: follow player with look-ahead, clamp to map.
camera_update:
    AXY16
    jsr camera_target
    jmp camera_ease

; target camera position -> t0, t1
camera_target:
    ; horizontal look-ahead toward facing direction
    lda p_face
    beq @r
    lda look
    cmp #.loword(-40)
    beq @lk
    dec look
    dec look
    bra @lk
@r: lda look
    cmp #40
    beq @lk
    inc look
    inc look
@lk:
    lda p_px
    clc
    adc look
    sec
    sbc #128
    bpl :+
    lda #0
:   cmp #MAP_W_PX - 256
    bcc :+
    lda #MAP_W_PX - 256
:   sta t0                  ; target x
    lda p_py
    sec
    sbc #136
    bpl :+
    lda #0
:   cmp #MAP_H_PX - 224
    bcc :+
    lda #MAP_H_PX - 224
:   sta t1                  ; target y
    ; surface missions: keep the skyline aligned (ground at most 152px down)
    lda surface_y
    beq @nos
    sec
    sbc #152
    cmp t1
    bcc @nos
    sta t1
@nos:
    rts

camera_ease:
    ; ease toward the target (1/4 of the distance, at least 1px)
    lda t0
    sec
    sbc cam_x
    jsr ease
    clc
    adc cam_x
    sta cam_x
    lda t1
    sec
    sbc cam_y
    jsr ease
    clc
    adc cam_y
    sta cam_y
    ; screen shake
    lda cam_x
    sta scroll_x
    lda cam_y
    dec a
    sta scroll_y
    lda shake
    beq @noshake
    lda shake
    beq :+
    dec shake
:   jsr random
    and #3
    sec
    sbc #1
    clc
    adc scroll_x
    sta scroll_x
    jsr random
    and #3
    sec
    sbc #1
    clc
    adc scroll_y
    sta scroll_y
@noshake:
    jsr map_stream
    jsr bg2_hdma_build
    jsr mark_explored
    rts

; A = signed distance -> signed step (distance/4, min 1 when nonzero, max 14)
ease:
    cmp #0
    beq @z
    bmi @neg
    lsr
    lsr
    bne :+
    lda #1
:   cmp #14
    bcc @z
    lda #14
@z: rts
@neg:
    eor #$FFFF
    inc a
    lsr
    lsr
    bne :+
    lda #1
:   cmp #14
    bcc :+
    lda #14
:   eor #$FFFF
    inc a
    rts

; Immediately center camera on the player and draw the whole window
camera_snap:
    AXY16
    stz look
    jsr camera_target
    lda t0
    sta cam_x
    sta scroll_x
    lda t1
    sta cam_y
    dec a
    sta scroll_y
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
    jsr bg2_hdma_build
    rts

map_draw_all:
    lda cam_ty
    dec a
    sta t3
    lda #17
    sta t4
@row:
    lda t3
    sta t1
    jsr draw_row
    inc t3
    dec t4
    bne @row
    lda #1
    sta bg1_dirty
    rts

map_stream:
    lda cam_x
    lsr
    lsr
    lsr
    lsr
    sta t9
    lda cam_y
    lsr
    lsr
    lsr
    lsr
    sta t10
@x1:lda cam_tx
    cmp t9
    beq @y
    bcs @xdec
    inc cam_tx
    lda cam_tx
    clc
    adc #17
    sta t0
    jsr draw_col
    bra @x1
@xdec:
    dec cam_tx
    lda cam_tx
    dec a
    sta t0
    jsr draw_col
    bra @x1
@y: lda cam_ty
    cmp t10
    beq @done
    bcs @ydec
    inc cam_ty
    lda cam_ty
    clc
    adc #15
    sta t1
    jsr draw_row
    bra @y
@ydec:
    dec cam_ty
    lda cam_ty
    dec a
    sta t1
    jsr draw_row
    bra @y
@done:
    rts

; draw column t0 for rows cam_ty-1 .. cam_ty+15
draw_col:
    lda cam_ty
    dec a
    sta t1
    lda #17
    sta t2
@l: jsr draw_mt
    inc t1
    dec t2
    bne @l
    lda #1
    sta bg1_dirty
    rts

; draw row t1 for columns cam_tx-1 .. cam_tx+17
draw_row:
    lda cam_tx
    dec a
    sta t0
    lda #19
    sta t2
@l: jsr draw_mt
    inc t0
    dec t2
    bne @l
    lda #1
    sta bg1_dirty
    rts

; draw metatile at (t0, t1) into the BG1 shadow. Preserves t0..t2.
draw_mt:
    lda t0
    cmp #128
    bcs @oob
    lda t1
    cmp #64
    bcs @oob
    xba
    lsr
    ora t0
    tax
    lda f:MAPBUF,x
    and #$00FF
    asl
    tax
    lda mt_entry,x
    bra @put
@oob:
    lda mt_entry + MT_BEDROCK*2
@put:
    sta t7
    lda t1
    and #31
    xba
    lsr
    lsr
    lsr
    sta t6
    lda t0
    and #31
    ora t6
    asl
    tax
    lda t7
    sta f:BG1_SHADOW,x
    rts

; ---------------------------------------------------------------- queries
; A = x px, Y = y px -> A = attribute byte. Also last_idx, last_mt.
; Out of bounds counts as solid bedrock.
attr_at:
    cmp #MAP_W_PX
    bcs @oob
    lsr
    lsr
    lsr
    lsr
    sta last_idx
    tya
    cmp #MAP_H_PX
    bcs @oob
    and #$FFF0
    asl
    asl
    asl
    ora last_idx
    sta last_idx
    tax
    lda f:MAPBUF,x
    and #$00FF
    sta last_mt
    tax
    lda mt_attr,x
    and #$00FF
    rts
@oob:
    lda #MT_BEDROCK
    sta last_mt
    lda #$FFFF
    sta last_idx
    lda #AT_SOLID
    rts

; Is the point solid (ignores platforms)? A=x, Y=y -> carry set if solid
solid_at:
    jsr attr_at
    lsr
    rts

; Set metatile A at map index X (from attr_at's last_idx) and redraw it.
set_tile_idx:
    sta t7
    A8
    sta f:MAPBUF,x
    A16
    ; tile coords
    txa
    and #127
    sta t0
    txa
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    sta t1
    ; inside the drawn window?
    lda t0
    sec
    sbc cam_tx
    inc a                   ; window cols: cam_tx-1 .. cam_tx+17 -> 0..18
    cmp #19
    bcs @out
    lda t1
    sec
    sbc cam_ty
    inc a
    cmp #17
    bcs @out
    jsr draw_mt
    lda #1
    sta bg1_dirty
@out:
    rts

; Damage terrain at pixel (A=x, Y=y). Returns carry set if something broke.
; Destructible tiles become their mt_break replacement.
break_at:
    jsr attr_at
    and #AT_DESTRUCT
    beq @no
    ldx last_mt
    lda mt_break,x
    and #$00FF
    ldx last_idx
    jsr set_tile_idx
    sec
    rts
@no:
    clc
    rts

; Explosion crater: radius ~2 tiles around pixel (blast_x, blast_y)
; Spawns rock chunks for broken tiles.
crater:
    lda blast_x
    sta t3
    lda blast_y
    sta t4
    lda #0
    sta t10                 ; chunk counter
    ldy #0
@lp:
    lda crater_dx,y
    cmp #$8000
    beq @done
    clc
    adc blast_x
    sta t8
    lda crater_dy,y
    clc
    adc blast_y
    sta t9
    phy
    ldy t9
    lda t8
    jsr break_at
    bcc @nb
    lda t10
    cmp #8
    bcs @nb
    inc t10
    lda t8
    and #$FFF0
    ora #8
    sta t0
    lda t9
    and #$FFF0
    ora #8
    sta t1
    jsr fx_rock_chunk
@nb:
    ply
    iny
    iny
    bra @lp
@done:
    rts

; offsets (px) of tiles hit by a grenade blast (roughly a disc of r=28px)
crater_dx: .word 0, .loword(-16), 16, 0, 0, .loword(-16), 16, .loword(-16), 16, .loword(-32), 32, 0, 0, .loword(-32), 32, .loword(-32), 32, .loword(-16), 16, .loword(-16), 16, $8000
crater_dy: .word 0, 0, 0, .loword(-16), 16, .loword(-16), .loword(-16), 16, 16, 0, 0, .loword(-32), 32, .loword(-16), .loword(-16), 16, 16, .loword(-32), .loword(-32), 32, 32

; Open the door containing map index X and every connected door tile of
; the same kind (flood fill over 4-neighbors, max 16 tiles).
open_door_at:
    ; small explicit stack in t-vars: use a fixed list on the CPU stack
    lda last_mt
    sta door_kind
    stz door_n
    txa
    jsr door_push
@lp:
    lda door_n
    beq @done
    dec door_n
    lda door_n
    asl
    tax
    lda door_stack,x
    tax
    lda f:MAPBUF,x
    and #$00FF
    cmp door_kind
    bne @lp
    phx
    lda #MT_DOOR_OPEN
    jsr set_tile_idx
    plx
    ; neighbors
    txa
    sec
    sbc #128
    jsr door_push
    txa
    clc
    adc #128
    jsr door_push
    txa
    dec a
    jsr door_push
    txa
    inc a
    jsr door_push
    bra @lp
@done:
    lda #SND_DOOR
    jsr sfx
    rts
door_push:
    cmp #8192
    bcs @x
    phx
    pha
    lda door_n
    cmp #24
    bcs @full
    asl
    tax
    pla
    sta door_stack,x
    inc door_n
    plx
    rts
@full:
    pla
    plx
@x: rts

; Open every exit door on the map (objective complete)
open_exit_doors:
    ldx #0
@l: lda f:MAPBUF,x
    and #$00FF
    cmp #MT_DOOR_EXIT
    bne @n
    phx
    lda #MT_DOOR_OPEN
    jsr set_tile_idx
    plx
@n: inx
    cpx #8192
    bcc @l
    lda #1
    sta exit_open
    rts

; EMP hit on map at pixel (A=x, Y=y): open EMP doors / switch off lasers
emp_tile:
    jsr attr_at
    and #AT_EMPABLE
    beq @no
    lda last_mt
    cmp #MT_DOOR_EMP
    bne @laser
    ldx last_idx
    jsr open_door_at
    sec
    rts
@laser:
    ; turn off the whole laser column, remember it for restoring
    ldx last_idx
@up:
    txa
    sec
    sbc #128
    bmi @top
    tax
    lda f:MAPBUF,x
    and #$00FF
    cmp #MT_LASER
    beq @up
    txa
    clc
    adc #128
    tax
@top:
    stx t8
    ; free gate slot
    ldy #0
@fs:lda gate_t,y
    beq @slot
    iny
    iny
    cpy #16
    bcc @fs
    ldy #0
@slot:
    lda t8
    sta gate_x,y
    lda #600
    sta gate_t,y
    ldx t8
@off:
    lda f:MAPBUF,x
    and #$00FF
    cmp #MT_LASER
    bne @done
    phx
    lda #MT_LASER_OFF
    jsr set_tile_idx
    pla
    clc
    adc #128
    tax
    bra @off
@done:
    lda #SND_EMP
    jsr sfx
    sec
    rts
@no:
    clc
    rts

; Count down EMP'd laser gates and restore them
gates_update:
    ldy #0
@l: lda gate_t,y
    beq @n
    dec a
    sta gate_t,y
    bne @n
    ldx gate_x,y
@on:
    lda f:MAPBUF,x
    and #$00FF
    cmp #MT_LASER_OFF
    bne @n
    phy
    phx
    lda #MT_LASER
    jsr set_tile_idx
    pla
    clc
    adc #128
    tax
    ply
    bra @on
@n: iny
    iny
    cpy #16
    bcc @l
    rts

; ---------------------------------------------------------------- BG2 HDMA
; Builds the parallax table: city skyline above the ground line, cave wall
; pattern below it.
bg2_hdma_build:
    lda hdma_cur
    eor #32
    tax                     ; build into the other buffer
    ; sky values
    lda cam_x
    lsr
    lsr
    sta t0                  ; sky hofs
    lda cam_x
    lsr
    sta t1                  ; cave hofs
    lda cam_y
    lsr
    and #127
    clc
    adc #160
    sta t3                  ; cave vofs
    lda surface_y
    beq @allcave
    sec
    sbc cam_y               ; ground line on screen
    bmi @allcave
    beq @allcave
    sta t4
    lda #152
    sec
    sbc t4
    bpl :+
    lda #0
:   sta t2                  ; sky vofs
    lda t4
    cmp #224
    bcs @allsky
    ; sky block (split if > 127 lines)
    cmp #128
    bcc @one
    A8
    lda #127
    jsr hd_put_sky
    A16
    lda t4
    sec
    sbc #127
@one:
    A8
    jsr hd_put_sky
    lda #1
    jsr hd_put_cave
    stz bg2_hdma,x
    A16
    bra @fin
@allsky:
    A8
    lda #1
    jsr hd_put_sky
    stz bg2_hdma,x
    A16
    bra @fin
@allcave:
    A8
    lda #1
    jsr hd_put_cave
    stz bg2_hdma,x
    A16
@fin:
    lda hdma_cur
    eor #32
    sta hdma_cur
    lda #1
    sta hdma_on
    rts
.a8
hd_put_sky:
    sta bg2_hdma,x
    lda t0
    sta bg2_hdma+1,x
    lda t0+1
    sta bg2_hdma+2,x
    lda t2
    sta bg2_hdma+3,x
    lda t2+1
    sta bg2_hdma+4,x
    inx
    inx
    inx
    inx
    inx
    rts
hd_put_cave:
    sta bg2_hdma,x
    lda t1
    sta bg2_hdma+1,x
    lda t1+1
    sta bg2_hdma+2,x
    lda t3
    sta bg2_hdma+3,x
    lda t3+1
    sta bg2_hdma+4,x
    inx
    inx
    inx
    inx
    inx
    rts
.a16

; Mark the 4x4-metatile blocks around the camera as explored (automap)
mark_explored:
    lda frame
    and #7
    bne @done
    ; block coords of screen center
    lda cam_y
    clc
    adc #112
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    sta t1                  ; by (0..15)
    lda cam_x
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    sta t0                  ; bx of left edge (0..31)
    ; mark bx..bx+4, by-1..by+1
    lda t1
    dec a
    sta t2
    lda #3
    sta t4
@row:
    lda t2
    cmp #16
    bcs @nr
    lda t0
    sta t3
    lda #5
    sta t5
@col:
    lda t3
    cmp #32
    bcs @nc
    ; bit index = by*32 + bx -> byte = by*4 + bx/8
    lda t2
    asl
    asl
    sta t6
    lda t3
    lsr
    lsr
    lsr
    clc
    adc t6
    tax
    lda t3
    and #7
    tay
    A8
    lda explored,x
    ora bitmask8,y
    sta explored,x
    A16
@nc:inc t3
    dec t5
    bne @col
@nr:inc t2
    dec t4
    bne @row
@done:
    rts

bitmask8: .byte 1, 2, 4, 8, 16, 32, 64, 128
