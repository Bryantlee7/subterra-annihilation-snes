; SNES hardware registers and helper macros

INIDISP  = $2100
OBSEL    = $2101
OAMADDL  = $2102
OAMADDH  = $2103
OAMDATA  = $2104
BGMODE   = $2105
MOSAIC   = $2106
BG1SC    = $2107
BG2SC    = $2108
BG3SC    = $2109
BG4SC    = $210A
BG12NBA  = $210B
BG34NBA  = $210C
BG1HOFS  = $210D
BG1VOFS  = $210E
BG2HOFS  = $210F
BG2VOFS  = $2110
BG3HOFS  = $2111
BG3VOFS  = $2112
VMAIN    = $2115
VMADDL   = $2116
VMADDH   = $2117
VMDATAL  = $2118
VMDATAH  = $2119
CGADD    = $2121
CGDATA   = $2122
W12SEL   = $2123
TM       = $212C
TS       = $212D
TMW      = $212E
CGWSEL   = $2130
CGADSUB  = $2131
COLDATA  = $2132
SETINI   = $2133
APUIO0   = $2140
APUIO1   = $2141
APUIO2   = $2142
APUIO3   = $2143
WMDATA   = $2180
WMADDL   = $2181
WMADDM   = $2182
WMADDH   = $2183
NMITIMEN = $4200
WRMPYA   = $4202
WRMPYB   = $4203
WRDIVL   = $4204
WRDIVB   = $4206
MDMAEN   = $420B
HDMAEN   = $420C
MEMSEL   = $420D
RDNMI    = $4210
TIMEUP   = $4211
HVBJOY   = $4212
RDDIVL   = $4214
RDMPYL   = $4216
JOY1L    = $4218
DMAP0    = $4300
BBAD0    = $4301
A1T0L    = $4302
A1B0     = $4304
DAS0L    = $4305

; joypad bits (16-bit read of $4218)
JOY_B      = $8000
JOY_Y      = $4000
JOY_SELECT = $2000
JOY_START  = $1000
JOY_UP     = $0800
JOY_DOWN   = $0400
JOY_LEFT   = $0200
JOY_RIGHT  = $0100
JOY_A      = $0080
JOY_X      = $0040
JOY_L      = $0020
JOY_R      = $0010

.macro A8
    sep #$20
    .a8
.endmacro
.macro A16
    rep #$20
    .a16
.endmacro
.macro XY8
    sep #$10
    .i8
.endmacro
.macro XY16
    rep #$10
    .i16
.endmacro
.macro AXY16
    rep #$30
    .a16
    .i16
.endmacro
.macro AXY8
    sep #$30
    .a8
    .i8
.endmacro

; DMA from a long source to a B-bus register on channel 0 (A8/XY16 assumed
; NOT required: macro sets its own sizes and leaves A16/XY16)
.macro DMA_TO bbus, src, len, mode
    A8
    lda #mode
    sta DMAP0
    lda #<bbus
    sta BBAD0
    A16
    lda #.loword(src)
    sta A1T0L
    lda #len
    sta DAS0L
    A8
    lda #^src
    sta A1B0
    lda #1
    sta MDMAEN
    A16
.endmacro
