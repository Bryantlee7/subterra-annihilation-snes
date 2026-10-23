; =====================================================================
;  UNDERGROUND LABYRINTH - a Super Nintendo action/exploration game
;  65816 assembly for ca65. Build with `make`.
; =====================================================================
.p816
.smart -
.feature c_comments

.include "snes.inc"
.include "../build/defs.inc"
.include "../build/sprites.inc"
.include "ram.s"

; profiling (AUTOTEST builds): accumulate scanlines spent in a routine
.macro PROF routine, slot
.ifdef AUTOTEST
    jsr prof_begin
    jsr routine
    lda #(slot*2)
    jsr prof_end
.else
    jsr routine
.endif
.endmacro

; game states
ST_TITLE   = 0
ST_BRIEF   = 1
ST_PLAY    = 2
ST_MAP     = 3
ST_FAILED  = 4
ST_CLEAR   = 5
ST_VICTORY = 6

; VRAM layout (word addresses)
VR_BG1CHR = $0000
VR_BG2CHR = $2000
VR_BG1MAP = $4000
VR_BG2MAP = $4400
VR_BG3MAP = $4C00
VR_BG3CHR = $5000
VR_OBJCHR = $6000

.segment "HEADER"           ; $FFC0
    .byte "SUBTERRA ANNIHILATION"    ; 21 bytes
    .byte $30               ; LoROM + FastROM
    .byte $02               ; ROM + RAM + battery
    .byte $09               ; 512KB
    .byte $01               ; 2KB SRAM
    .byte $01               ; North America
    .byte $33               ; extended header marker
    .byte $00               ; version
    .word $FFFF, $0000      ; checksum complement / checksum (patched)

.segment "VECTORS"          ; $FFE0
    ; native mode
    .word 0, 0
    .word .loword(int_rti)  ; COP
    .word .loword(int_rti)  ; BRK
    .word .loword(int_rti)  ; ABORT
    .word .loword(nmi)      ; NMI
    .word 0
    .word .loword(int_rti)  ; IRQ
    ; emulation mode
    .word 0, 0
    .word .loword(int_rti)
    .word 0
    .word .loword(int_rti)
    .word .loword(int_rti)
    .word .loword(reset)    ; RESET
    .word .loword(int_rti)

.segment "CODE"

int_rti:
    rti

; ---------------------------------------------------------------- reset
reset:
    sei
    clc
    xce                     ; native mode
    jml fast_reset + $800000 ; jump into the FastROM mirror (bank $80)
fast_reset:
    AXY16
    ldx #$1FFF
    txs
    lda #$0000
    tcd                     ; direct page = $0000
    A8
    lda #$80
    pha
    plb                     ; data bank = $80
    lda #$01
    sta MEMSEL              ; FastROM
    jsr init_hardware
    AXY16
    ; clear low RAM ($0000-$1DFF; stack untouched)
    ldx #$0000
@clr:
    stz $00,x
    inx
    inx
    cpx #$1E00
    bcc @clr
    lda #$1234
    sta rng
    lda #1
    sta gore
    sta music_on
    jsr sram_load
    jsr sound_init
    lda #$FFFF
    sta next_state
.ifdef START_MISSION
    lda #START_MISSION
    sta mission
    lda #ST_PLAY
.else
    lda #ST_TITLE
.endif
    jsr enter_state
main_loop:
    AXY16
    PROF read_joy, 9
    jsr run_state
    PROF snd_flush, 10
    jsr wait_nmi
    bra main_loop

; ---------------------------------------------------------------- init
init_hardware:
    A8
    XY16
    lda #$80
    sta INIDISP             ; forced blank
    stz NMITIMEN
    stz HDMAEN
    ; zero most PPU registers
    ldx #$2101
@ppu:
    stz $00,x               ; DP=0 -> absolute $2101.. (DB=$80 mirrors I/O)
    inx
    cpx #$2134
    bcc @ppu
    ; scroll registers are write-twice
    ldx #$210D
@scr:
    stz $00,x
    stz $00,x
    inx
    cpx #$2115
    bcc @scr
    lda #$80
    sta VMAIN
    stz CGADD
    ldx #$4200
@cpu:
    stz $00,x
    inx
    cpx #$420E
    bcc @cpu
    lda #$FF
    sta $4201
    rts

; ---------------------------------------------------------------- frame sync
; Tell NMI the frame is ready and wait for it.
wait_nmi:
    A8
    lda #1
    sta nmi_ready
    A16
    lda nmi_count
@w: cmp nmi_count
    beq @w
    inc frame
    rts

read_joy:
    A8
@w: lda HVBJOY
    and #$01
    bne @w
    A16
    lda joy
    sta joy_prev
    lda JOY1L
.ifdef AUTOTEST
    jsr autotest_input
.endif
    sta joy
    lda joy_prev
    eor #$FFFF
    and joy
    sta joy_new
    rts

; ---------------------------------------------------------------- NMI
nmi:
    jml nmi_fast + $800000  ; run from the FastROM mirror
nmi_fast:
    AXY16
    pha
    phx
    phy
    phd
    phb
    lda #$0000
    tcd
    A8
    lda #$80
    pha
    plb
    lda RDNMI
    lda nmi_ready
    bne :+
    jmp @skip
:
    ; OAM
    stz OAMADDL
    stz OAMADDH
    stz DMAP0
    lda #<OAMDATA
    sta BBAD0
    ldx #.loword(oam_buf)
    stx A1T0L
    stz A1B0
    ldx #544
    stx DAS0L
    lda #1
    sta MDMAEN
    ; BG1 tilemap
    lda bg1_dirty
    beq @nobg1
    lda #$80
    sta VMAIN
    ldx #VR_BG1MAP
    stx VMADDL
    lda #$01
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    ldx #.loword(BG1_SHADOW)
    stx A1T0L
    lda #^BG1_SHADOW
    sta A1B0
    ldx #2048
    stx DAS0L
    lda #1
    sta MDMAEN
    stz bg1_dirty
@nobg1:
    ; BG3 tilemap (HUD rows only, or everything)
    lda bg3_dirty
    beq @nobg3
    lda #$80
    sta VMAIN
    ldx #VR_BG3MAP
    stx VMADDL
    lda #$01
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    ldx #.loword(BG3_SHADOW)
    stx A1T0L
    lda #^BG3_SHADOW
    sta A1B0
    ldx #128
    lda bg3_dirty
    cmp #2
    bne :+
    ldx #2048
:   stx DAS0L
    lda #1
    sta MDMAEN
    stz bg3_dirty
@nobg3:
    ; palette
    lda pal_dirty
    beq @nopal
    stz CGADD
    stz DMAP0
    lda #<CGDATA
    sta BBAD0
    ldx #.loword(pal_buf)
    stx A1T0L
    stz A1B0
    ldx #512
    stx DAS0L
    lda #1
    sta MDMAEN
    stz pal_dirty
@nopal:
    ; queued VRAM uploads
    ldy vq_count
    beq @novq
    ldx #0
@vq:
    lda #$80
    sta VMAIN
    A16
    lda vq_dst,x
    sta VMADDL
    lda vq_src,x
    sta A1T0L
    lda vq_len,x
    sta DAS0L
    A8
    lda vq_bank,x
    sta A1B0
    lda #$01
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    lda #1
    sta MDMAEN
    inx
    inx
    dey
    bne @vq
    stz vq_count
    stz vq_count+1
@novq:
    ; scrolling
    lda scroll_x
    sta BG1HOFS
    lda scroll_x+1
    sta BG1HOFS
    lda scroll_y
    sta BG1VOFS
    lda scroll_y+1
    sta BG1VOFS
    stz BG3HOFS
    stz BG3HOFS
    lda #$FF
    sta BG3VOFS
    lda #$03
    sta BG3VOFS
    ; BG2 parallax via HDMA channel 7 (mode 3: BG2HOFS x2, BG2VOFS x2)
    lda hdma_on
    beq @nohdma
    lda #$03
    sta $4370
    lda #<BG2HOFS
    sta $4371
    A16
    lda hdma_cur
    clc
    adc #.loword(bg2_hdma)
    sta $4372
    A8
    lda #$7E
    sta $4374
    lda #$80
    sta HDMAEN
    bra @hd
@nohdma:
    stz HDMAEN
@hd:
    lda brightness
    sta INIDISP
    stz nmi_ready
@skip:
    A16
    inc nmi_count
.ifdef AUTOTEST
    jsr autotest_dump
.endif
    AXY16
    plb
    pld
    ply
    plx
    pla
    rti

; ---------------------------------------------------------------- states
; A = new state. Runs the state's init (screen is blanked by init code).
enter_state:
    AXY16
    sta game_state
    stz state_timer
    asl
    tax
    jsr (state_init_tbl,x)
    rts

run_state:
    AXY16
    inc state_timer
    lda game_state
    asl
    tax
    jsr (state_frame_tbl,x)
    AXY16
    lda next_state
    cmp #$FFFF
    beq :+
    pha
    lda #$FFFF
    sta next_state
    pla
    jsr enter_state
:   rts

state_init_tbl:
    .addr title_init, brief_init, play_init, map_init, failed_init, clear_init, victory_init
state_frame_tbl:
    .addr title_frame, brief_frame, play_frame, map_frame, failed_frame, clear_frame, victory_frame

; ---------------------------------------------------------------- helpers
; 16-bit xorshift random -> A
random:
    lda rng
    asl
    eor rng
    sta rng
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    eor rng
    sta rng
    xba
    eor rng
    sta rng
    rts

; turn the screen off: fade, then forced blank with NMI disabled
screen_off:
    AXY16
@f: A8
    lda brightness
    and #$0F
    beq @done
    dec a
    dec a
    bpl :+
    lda #0
:   sta brightness
    A16
    jsr wait_nmi
    bra @f
@done:
    A8
    lda #$80
    sta INIDISP
    sta brightness
    stz NMITIMEN
    stz HDMAEN
    A16
    rts

; re-enable NMI (screen stays dark until fade_in)
screen_nmi_on:
    A8
    lda #$80
    sta brightness
    lda #$81
    sta NMITIMEN
    A16
    rts

fade_in:
    AXY16
    jsr screen_nmi_on
    A8
    stz brightness
    A16
@f: jsr wait_nmi
    A8
    lda brightness
    clc
    adc #2
    cmp #$0F
    bcc :+
    lda #$0F
:   sta brightness
    cmp #$0F
    A16
    bne @f
    rts

.include "video.s"
.include "map.s"
.include "player.s"
.include "weapons.s"
.include "actors.s"
.include "fx.s"
.include "hud.s"
.include "screens.s"
.include "sound.s"
.ifdef AUTOTEST
.include "autotest.s"
.endif
.include "data.s"
