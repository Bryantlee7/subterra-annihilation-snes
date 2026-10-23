; ---------------------------------------------------------------- data banks

.segment "RODATA"
MT_TABLES
.include "text.s"

.segment "DATA2"
gfx_bg1:     .incbin "../build/bg1.chr"
gfx_bg1_end:
gfx_bg2:     .incbin "../build/bg2.chr"
gfx_bg2_end:
gfx_bg2map:  .incbin "../build/bg2.map"
gfx_font:    .incbin "../build/font.chr"
gfx_logo_map: .incbin "../build/logo.map"

.segment "DATA3"
gfx_spr:     .incbin "../build/spr.chr"
pal_master:  .incbin "../build/palettes.bin"
pal_earth:   .incbin "../build/earth.bin"
pal_back:    .incbin "../build/back.bin"

.segment "DATA7"
spc_blob: .incbin "../build/spc.bin"
spc_blob_end:

.segment "DATA4"
map01: .incbin "../build/map01.bin"
map02: .incbin "../build/map02.bin"
map03: .incbin "../build/map03.bin"
map04: .incbin "../build/map04.bin"

.segment "DATA5"
map05: .incbin "../build/map05.bin"
map06: .incbin "../build/map06.bin"
map07: .incbin "../build/map07.bin"
map08: .incbin "../build/map08.bin"

.segment "DATA6"
map09: .incbin "../build/map09.bin"
map10: .incbin "../build/map10.bin"
.include "../build/levels_ents.inc"

.segment "RODATA"
.include "../build/levels_mis.inc"
map_ptrs: .dword map01, map02, map03, map04, map05, map06, map07, map08, map09, map10
