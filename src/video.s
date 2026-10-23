; ---------------------------------------------------------------- video helpers
; All routines: call with AXY16, return AXY16.

; Upload to VRAM during forced blank.
; t0 = VRAM word address, ptr = long source, t1 = byte length
vram_load:
    A8
    lda #$80
    sta VMAIN
    A16
    lda t0
    sta VMADDL
    lda ptr
    sta A1T0L
    lda t1
    sta DAS0L
    A8
    lda ptr+2
    sta A1B0
    lda #$01
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    lda #1
    sta MDMAEN
    A16
    rts

; Fill all of VRAM with zero (forced blank)
vram_clear:
    A8
    lda #$80
    sta VMAIN
    A16
    stz VMADDL
    stz t0
    A8
    lda #$09                ; fixed source, 2 registers
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    A16
    lda #.loword(zero_word)
    sta A1T0L
    stz DAS0L               ; 0 = 64KB
    A8
    lda #^zero_word
    sta A1B0
    lda #1
    sta MDMAEN
    A16
    rts

zero_word: .word 0

; Copy WRAM block via DMA to WRAM port. ptr = long source (ROM),
; t0/t1 = destination address low word / bank, t2 = length
wram_copy:
    A8
    lda t0
    sta WMADDL
    lda t0+1
    sta WMADDM
    lda t1
    sta WMADDH
    stz DMAP0
    lda #<WMDATA
    sta BBAD0
    A16
    lda ptr
    sta A1T0L
    lda t2
    sta DAS0L
    A8
    lda ptr+2
    sta A1B0
    lda #1
    sta MDMAEN
    A16
    rts

; Copy the master palette (ROM) into pal_buf, apply region palettes.
; A = mission index
palette_setup:
    AXY16
    pha
    ldx #0
@c: lda f:pal_master,x
    sta pal_buf,x
    inx
    inx
    cpx #512
    bcc @c
    pla
    asl
    tax
    ; earth palette -> BG palette 2 (bytes 64..95)
    lda mis_earth,x
    asl
    asl
    asl
    asl
    asl
    tay
    ldx #0
@e: tya
    phx
    tax
    lda f:pal_earth,x
    plx
    sta pal_buf+64,x
    iny
    iny
    inx
    inx
    cpx #32
    bcc @e
    lda mission
    asl
    tax
    lda mis_back,x
    asl
    asl
    asl
    asl
    asl
    tay
    ldx #0
@b: tya
    phx
    tax
    lda f:pal_back,x
    plx
    sta pal_buf+224,x
    iny
    iny
    inx
    inx
    cpx #32
    bcc @b
    lda #1
    sta pal_dirty
    rts

; Write pal_buf straight to CGRAM (forced blank)
palette_upload:
    A8
    stz CGADD
    stz DMAP0
    lda #<CGDATA
    sta BBAD0
    A16
    lda #.loword(pal_buf)
    sta A1T0L
    lda #512
    sta DAS0L
    A8
    stz A1B0
    lda #1
    sta MDMAEN
    A16
    stz pal_dirty
    rts

; Set up PPU registers for the standard layout
ppu_setup:
    A8
    lda #$19                ; mode 1, BG3 priority, BG1 16x16 tiles
    sta BGMODE
    lda #(VR_BG1MAP >> 8)
    sta BG1SC
    lda #((VR_BG2MAP >> 8) | 2)   ; 32x64
    sta BG2SC
    lda #(VR_BG3MAP >> 8)
    sta BG3SC
    lda #$20                ; BG1 chars $0000, BG2 chars $2000
    sta BG12NBA
    lda #$05                ; BG3 chars $5000
    sta BG34NBA
    lda #$03                ; OBJ chars $6000, 8x8 + 16x16
    sta OBSEL
    lda #$17                ; BG1 BG2 BG3 OBJ on main screen
    sta TM
    stz TS
    stz CGWSEL
    stz CGADSUB
    stz SETINI
    A16
    rts

; Load all static graphics (forced blank)
gfx_load_all:
    AXY16
    jsr vram_clear
    lda #VR_BG1CHR
    sta t0
    lda #.loword(gfx_bg1)
    sta ptr
    lda #^gfx_bg1
    sta ptr+2
    lda #gfx_bg1_end - gfx_bg1
    sta t1
    jsr vram_load
    lda #VR_BG2CHR
    sta t0
    lda #.loword(gfx_bg2)
    sta ptr
    lda #^gfx_bg2
    sta ptr+2
    lda #gfx_bg2_end - gfx_bg2
    sta t1
    jsr vram_load
    lda #VR_BG2MAP
    sta t0
    lda #.loword(gfx_bg2map)
    sta ptr
    lda #^gfx_bg2map
    sta ptr+2
    lda #4096
    sta t1
    jsr vram_load
    jsr font_load
    lda #VR_OBJCHR
    sta t0
    lda #.loword(gfx_spr)
    sta ptr
    lda #^gfx_spr
    sta ptr+2
    lda #16384
    sta t1
    jsr vram_load
    rts

font_load:
    lda #VR_BG3CHR
    sta t0
    lda #.loword(gfx_font)
    sta ptr
    lda #^gfx_font
    sta ptr+2
    lda #4096
    sta t1
    jsr vram_load
    rts

; ---------------------------------------------------------------- OAM
oam_begin:
    stz oam_i
    rts

; Add one sprite. spr_x/spr_y = screen position (signed), spr_t = tile|attr<<8,
; spr_big = 0 (8x8) or 2 (16x16). Clobbers A, X.
spr_add:
    lda spr_x
    clc
    adc #16
    cmp #272
    bcs @skip
    lda spr_y
    clc
    adc #16
    cmp #240
    bcs @skip
    ldx oam_i
    cpx #512
    bcs @skip
    A8
    lda spr_x
    sta oam_buf,x
    lda spr_y
    dec a
    sta oam_buf+1,x
    A16
    lda spr_t
    sta oam_buf+2,x
    txa
    lsr
    lsr
    tax
    A8
    lda spr_x+1
    and #1
    ora spr_big
    sta oam_hi_tmp,x
    A16
    lda oam_i
    clc
    adc #4
    sta oam_i
@skip:
    rts

; Hide unused sprites and pack the high table
oam_end:
    ldx oam_i
@hide:
    cpx #512
    bcs @pack
    A8
    lda #$F0
    sta oam_buf+1,x
    A16
    txa
    lsr
    lsr
    tay
    A8
    lda #0
    sta oam_hi_tmp,y
    A16
    inx
    inx
    inx
    inx
    bra @hide
@pack:
    A8
    ldx #0
    ldy #0
@p: lda oam_hi_tmp+3,x
    asl
    asl
    ora oam_hi_tmp+2,x
    asl
    asl
    ora oam_hi_tmp+1,x
    asl
    asl
    ora oam_hi_tmp,x
    sta oam_buf+512,y
    iny
    inx
    inx
    inx
    inx
    cpx #128
    bcc @p
    A16
    rts

; ---------------------------------------------------------------- BG3 text
TXT_ATTR = $2000            ; priority bit (BG3 above everything)

; Fill the BG3 shadow with tile A (16-bit entry)
bg3_fill:
    ldx #0
@f: sta f:BG3_SHADOW,x
    inx
    inx
    cpx #2048
    bcc @f
    rts

; Clear BG3 to transparent
bg3_clear:
    lda #128 | TXT_ATTR
    jsr bg3_fill
    lda #2
    sta bg3_dirty
    rts

; Print zero-terminated string (bank $80) at X=string, A=row*32+col,
; text_pal = palette (0-7), text_opaque = 0 transparent / 1 black background.
; '\n' (10) starts a new line at the starting column.
print:
    sta t8                  ; current position
    sta t9                  ; line start
    stx t10
    lda txt_pal
    xba
    asl
    asl
    and #$1C00
    ora #TXT_ATTR
    sta t11
    lda txt_opaque
    bne :+
    lda t11
    ora #128
    sta t11
:
@loop:
    ldx t10
    lda a:0,x
    and #$00FF
    beq @done
    inc t10
    cmp #10
    bne @ch
    lda t9
    clc
    adc #32
    sta t9
    sta t8
    bra @loop
@ch:
    sec
    sbc #32
    ora t11
    pha
    lda t8
    asl
    tax
    pla
    sta f:BG3_SHADOW,x
    inc t8
    bra @loop
@done:
    rts

; Print a number. A = value, X = digits (1-5), Y = position. Leading zeros.
print_num:
    sta t6
    stx t7
    sty t8
    lda txt_pal
    xba
    asl
    asl
    and #$1C00
    ora #TXT_ATTR
    sta t11
    lda txt_opaque
    bne :+
    lda t11
    ora #128
    sta t11
:
    ; position of last digit
    lda t8
    clc
    adc t7
    dec a
    asl
    tax
@d: lda t6
    jsr div10               ; A = quotient, t5 = remainder
    sta t6
    lda t5
    clc
    adc #('0' - 32)
    ora t11
    sta f:BG3_SHADOW,x
    dex
    dex
    dec t7
    bne @d
    rts

; A = A / 10, t5 = A % 10  (16-bit, via hardware divider)
div10:
    sta WRDIVL
    A8
    lda #10
    sta WRDIVB
    nop                     ; 16 cycles for the divider
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

; Put a single tile entry: A = entry, Y = position
put_tile:
    pha
    tya
    asl
    tax
    pla
    sta f:BG3_SHADOW,x
    rts
