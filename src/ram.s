; ---------------------------------------------------------------- RAM layout

MAX_ACT   = 20          ; active actors (enemies, objects)
MAX_PB    = 12          ; player projectiles
MAX_EB    = 14          ; enemy projectiles
MAX_PART  = 32          ; particles / debris
MAX_ENT   = 120         ; entity list (100 from ROM + 20 drop slots)
DROP_BASE = 100

MAPBUF     = $7F0000    ; 128x64 metatile map (8KB)
BG1_SHADOW = $7E2000    ; 32x32 BG1 tilemap shadow (2KB)
BG3_SHADOW = $7E2800    ; 32x32 BG3 tilemap shadow (2KB)
AUTOMAP_CHR = $7E3000   ; 8KB automap character buffer

.segment "ZEROPAGE"
t0:  .res 2
t1:  .res 2
t2:  .res 2
t3:  .res 2
t4:  .res 2
t5:  .res 2
t6:  .res 2
t7:  .res 2
t8:  .res 2
t9:  .res 2
t10: .res 2
t11: .res 2
ptr: .res 3             ; long pointer
ptr2: .res 3
nmi_count:  .res 2
frame:      .res 2
joy:        .res 2
joy_prev:   .res 2
joy_new:    .res 2
nmi_ready:  .res 1
brightness: .res 1
rng:        .res 2
cur:        .res 2      ; current slot index * 2
oam_i:      .res 2      ; next free OAM byte offset
spr_x:      .res 2      ; spr_add inputs
spr_y:      .res 2
spr_t:      .res 2      ; tile | attr<<8
spr_big:    .res 2
t12:        .res 2
cur2:       .res 2
pt_cur:     .res 2
dmg_slot:   .res 2

.segment "BSS"
oam_buf:    .res 544
oam_hi_tmp: .res 128    ; per-sprite hi bits before packing
bg1_dirty:  .res 2
bg3_dirty:  .res 2      ; 0 none, 1 HUD rows, 2 full
pal_dirty:  .res 2
pal_buf:    .res 512
scroll_x:   .res 2      ; final scroll values for NMI
scroll_y:   .res 2
bg2_hdma:   .res 64     ; two HDMA tables (32 bytes each)
hdma_cur:   .res 2      ; offset of table to show
hdma_on:    .res 2
game_state: .res 2
state_timer: .res 2
next_state: .res 2
gore:       .res 2      ; 1 = blood and severed limbs
music_on:   .res 2

; VRAM upload queue (for occasional uploads during play)
vq_count:   .res 2
vq_dst:     .res 2*8
vq_src:     .res 2*8
vq_bank:    .res 2*8
vq_len:     .res 2*8

; ---- camera / map
cam_x:      .res 2
cam_y:      .res 2
cam_tx:     .res 2      ; camera tile coords of last draw
cam_ty:     .res 2
shake:      .res 2
look:       .res 2      ; horizontal look-ahead
surface_y:  .res 2      ; ground line y (px) or 0
last_idx:   .res 2
last_mt:    .res 2
explored:   .res 64     ; 32x16 bits (4x4 metatile blocks)

; ---- mission
mission:    .res 2      ; 0..9
max_mission: .res 2     ; highest unlocked
obj_type:   .res 2
obj_left:   .res 2
obj_total:  .res 2
exit_open:  .res 2
timer_on:   .res 2
timer_sec:  .res 2
timer_fr:   .res 2
has_key:    .res 2
kills:      .res 2
mis_frames: .res 2
mis_secs:   .res 2
complete_t: .res 2
msg_timer:  .res 2
msg_ptr:    .res 2
msg_pal:    .res 2
hud_dirty:  .res 2
depth_base: .res 2
spawn_rr:   .res 2      ; round-robin entity scan index
drop_next:  .res 2
quake:      .res 2

; ---- player
p_x:        .res 2      ; 1/16 px, feet center
p_y:        .res 2
p_vx:       .res 2
p_vy:       .res 2
p_px:       .res 2      ; pixels
p_py:       .res 2
p_face:     .res 2      ; 0 right, 1 left
p_ground:   .res 2
p_climb:    .res 2
p_crouch:   .res 2
p_aim:      .res 2      ; 0 fwd 1 up 2 diag up 3 diag down
p_anim:     .res 2
p_animt:    .res 2
p_hp:       .res 2
p_inv:      .res 2      ; invulnerability frames
p_dead:     .res 2
p_deadt:    .res 2
p_cool:     .res 2      ; weapon cooldown
p_gcool:    .res 2      ; grenade cooldown
p_weapon:   .res 2
p_ammo:     .res 2*5
p_dmg:      .res 2      ; armor damage stage 0..3 (visual only)
p_riding:   .res 2      ; actor slot*2+2 of elevator, or 0
p_flash:    .res 2      ; muzzle flash frames
p_haz:      .res 2      ; hazard damage tick
p_jumpheld: .res 2
p_win:      .res 2
p_drop:     .res 2

; ---- actors (struct of arrays, index = slot*2)
a_type:  .res MAX_ACT*2
a_x:     .res MAX_ACT*2
a_y:     .res MAX_ACT*2
a_vx:    .res MAX_ACT*2
a_vy:    .res MAX_ACT*2
a_state: .res MAX_ACT*2
a_timer: .res MAX_ACT*2
a_hp:    .res MAX_ACT*2
a_flags: .res MAX_ACT*2
a_parts: .res MAX_ACT*2
a_ent:   .res MAX_ACT*2
a_cool:  .res MAX_ACT*2
a_stun:  .res MAX_ACT*2
a_hurt:  .res MAX_ACT*2
a_anim:  .res MAX_ACT*2
a_aux:   .res MAX_ACT*2
a_aux2:  .res MAX_ACT*2
a_lh:    .res MAX_ACT*2     ; head part hp
a_la:    .res MAX_ACT*2     ; arm part hp
a_ll:    .res MAX_ACT*2     ; legs part hp
a_hitmask: .res 2*2         ; railgun: actors already hit (bitmask, 20 bits)

; ---- player projectiles
pb_type: .res MAX_PB*2
pb_x:    .res MAX_PB*2
pb_y:    .res MAX_PB*2
pb_vx:   .res MAX_PB*2
pb_vy:   .res MAX_PB*2
pb_life: .res MAX_PB*2

; ---- enemy projectiles
eb_type: .res MAX_EB*2
eb_x:    .res MAX_EB*2
eb_y:    .res MAX_EB*2
eb_vx:   .res MAX_EB*2
eb_vy:   .res MAX_EB*2
eb_life: .res MAX_EB*2

; ---- particles
pt_type: .res MAX_PART*2
pt_x:    .res MAX_PART*2
pt_y:    .res MAX_PART*2
pt_vx:   .res MAX_PART*2
pt_vy:   .res MAX_PART*2
pt_life: .res MAX_PART*2
pt_tile: .res MAX_PART*2    ; tile | attr<<8
pt_big:  .res MAX_PART*2
pt_next: .res 2

; ---- entity list
en_type:  .res MAX_ENT*2
en_param: .res MAX_ENT*2
en_x:     .res MAX_ENT*2
en_y:     .res MAX_ENT*2
en_flags: .res MAX_ENT*2    ; bit0 dead/collected, bit1 spawned
en_count: .res 2

; ---- laser gates disabled by EMP (restore list)
gate_x:   .res 2*8
gate_y:   .res 2*8
gate_t:   .res 2*8

; ---- sound
snd_queue: .res 2*4
           .res 2*4
snd_n:     .res 2
snd_seq:   .res 2

txt_pal:    .res 2
txt_opaque: .res 2

door_kind:  .res 2
door_n:     .res 2
door_stack: .res 2*24

rail_x:     .res 2
rail_y:     .res 2
rail_dx_v:  .res 2
rail_dy_v:  .res 2
rail_soft:  .res 2
rail_steps: .res 2
blast_x:    .res 2
blast_y:    .res 2
hit_dmg:    .res 2
hit_kind:   .res 2
hit_vx:     .res 2
hit_y:      .res 2

debris_push: .res 2
hb_n:       .res 2
hc_hp:       .res 2
hc_wpn:      .res 2
hc_ammo:     .res 2
hc_nade:     .res 2
hc_key:      .res 2
hc_row1:     .res 2
hb_slot:    .res MAX_ACT*2
hb_l:       .res MAX_ACT*2
hb_r:       .res MAX_ACT*2
hb_t:       .res MAX_ACT*2
hb_b:       .res MAX_ACT*2
hp_x:       .res 2
hp_y:       .res 2
p_aim_tmp:  .res 2

paused:     .res 2
at_pos:     .res 2
at_count:   .res 2
at_tmp:     .res 2
dbg_cnt:    .res 2
prof_t:     .res 2
prof_frame0: .res 2
prof_max:   .res 2
prof_over:  .res 2
prof_sum:   .res 2*12

; ---- menu
menu_sel:  .res 2
