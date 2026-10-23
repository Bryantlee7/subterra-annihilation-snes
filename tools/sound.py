"""SPC700 sound driver, instrument samples (BRR), sound effects and music.

Produces build/spc.bin: one block loaded at SPC address $0200 (entry point).
Communication (CPU -> SPC):  port1 = id, port2 = arg, then port0 = sequence.
id 1..63 = sound effect, $80 | n = start song n (0 = stop). The driver echoes
the sequence number on port0 when done; after boot it writes $55 to port0.
"""
import math, random, os
from spc import Asm

ORG = 0x0200
DIR_PAGE = 0x02          # sample directory goes at $0200 + driver size, aligned
# ---------------------------------------------------------------- dp layout
LAST, CMD, ARG, KONM, KOFFM, RR, TMP, KOFFS, MON, FLAGS = range(0x00, 0x0A)
PTR = 0x10
PITCH = 0x12
M_PLO, M_PHI, M_LLO, M_LHI, M_WAIT, M_INST = 0x20, 0x24, 0x28, 0x2C, 0x30, 0x34
S_PLO, S_PHI, S_DLO, S_DHI, S_T = 0x40, 0x48, 0x50, 0x58, 0x60

# DSP registers
VOLL, VOLR, PL, PH, SRCN, ADSR1, ADSR2, GAIN = range(8)
MVOLL, MVOLR, EVOLL, EVOLR, KON, KOFF, FLG = 0x0C, 0x1C, 0x2C, 0x3C, 0x4C, 0x5C, 0x6C
EFB, PMON, NON, EON, DIR, ESA, EDL = 0x0D, 0x2D, 0x3D, 0x4D, 0x5D, 0x6D, 0x7D

# ================================================================ samples
def brr_encode(samples, loop):
    """samples: list of ints (-16384..16383), length multiple of 16."""
    out = bytearray()
    n = len(samples)
    assert n % 16 == 0
    for bi in range(0, n, 16):
        blk = samples[bi:bi + 16]
        peak = max(abs(s) for s in blk)
        shift = 0
        while shift < 12 and peak / (1 << max(shift - 1, 0)) > 7.4:
            shift += 1
        unit = 1 << max(shift - 1, 0) if shift else 0.5
        nibs = []
        for s in blk:
            v = int(round(s / unit)) if shift else int(round(s * 2))
            v = max(-8, min(7, v))
            nibs.append(v & 15)
        last = bi + 16 >= n
        hdr = (shift << 4) | (0 << 2) | ((1 if loop else 0) << 1 if last else 0) | (1 if last else 0)
        out.append(hdr)
        for i in range(0, 16, 2):
            out.append((nibs[i] << 4) | nibs[i + 1])
    return bytes(out)

def wave(fn, n=32, amp=12000):
    return [int(amp * fn(i / n)) for i in range(n)]

def make_samples():
    rnd = random.Random(5)
    S = {}
    S['sq50'] = (wave(lambda t: 1 if t < 0.5 else -1), True)
    S['sq25'] = (wave(lambda t: 1 if t < 0.25 else -1), True)
    S['saw'] = (wave(lambda t: 1 - 2 * t, amp=11000), True)
    S['tri'] = (wave(lambda t: 4 * t - 1 if t < 0.5 else 3 - 4 * t, amp=13000), True)
    S['sine'] = (wave(lambda t: math.sin(2 * math.pi * t), amp=13000), True)
    S['noise'] = ([rnd.randint(-11000, 11000) for _ in range(1024)], True)
    # kick: falling sine sweep
    kick = []
    ph = 0
    for i in range(1600):
        f = 140 * math.exp(-i / 300) + 45
        ph += 2 * math.pi * f / 32000
        kick.append(int(14000 * math.sin(ph) * math.exp(-i / 900)))
    S['kick'] = (kick, False)
    snare = []
    for i in range(1200):
        tone = math.sin(2 * math.pi * 190 * i / 32000) * 0.35
        snare.append(int(13000 * (rnd.uniform(-1, 1) * 0.8 + tone) * math.exp(-i / 260)))
    S['snare'] = (snare, False)
    S['hat'] = ([int(9000 * rnd.uniform(-1, 1) * math.exp(-i / 70)) for i in range(400)], False)
    # explosion: low rumbling noise (one-pole low pass) with a long tail
    blast = []
    y = 0
    for i in range(4800):
        y = y * 0.82 + rnd.uniform(-1, 1) * 0.18
        blast.append(int(15000 * y * 3.0 * math.exp(-i / 1600)))
    S['blast'] = ([max(-15000, min(15000, v)) for v in blast], False)
    return S

SAMPLE_ORDER = ['sq50', 'sq25', 'saw', 'tri', 'sine', 'noise', 'kick', 'snare', 'hat', 'blast']
SRC = {k: i for i, k in enumerate(SAMPLE_ORDER)}

# instruments: name -> (sample, adsr1, adsr2, flags[bit0 = fixed pitch])
INSTRUMENTS = [
    ('lead',   'sq25', 0xCF, 0xA8, 0),
    ('bass',   'tri',  0xCF, 0xC4, 0),
    ('pad',    'saw',  0xAA, 0xE2, 0),
    ('kick',   'kick', 0x8F, 0xE0, 1),
    ('snare',  'snare', 0x8F, 0xE0, 1),
    ('hat',    'hat',  0x8F, 0xE0, 1),
    ('arp',    'sq50', 0xFF, 0x70, 0),
    ('sus_sq', 'sq50', 0x8F, 0xE0, 0),
    ('sus_25', 'sq25', 0x8F, 0xE0, 0),
    ('sus_saw', 'saw', 0x8F, 0xE0, 0),
    ('sus_tri', 'tri', 0x8F, 0xE0, 0),
    ('nz_dec', 'noise', 0xFF, 0x14, 0),
    ('nz_sus', 'noise', 0x8F, 0xE0, 0),
    ('blast',  'blast', 0x8F, 0xE0, 0),
    ('sine',   'sine', 0xCF, 0xC6, 0),
]
INST = {n: i for i, (n, *_r) in enumerate(INSTRUMENTS)}

# ================================================================ sound effects
# id: (instrument, volume, pitch, delta per tick, length ticks)
SFX = {
    1:  ('nz_dec', 0x48, 0x1800, -0x80, 4),     # machine gun
    2:  ('sus_sq', 0x58, 0x1600, -0xB0, 14),    # plasma
    3:  ('sus_tri', 0x60, 0x0700, 0x110, 18),   # EMP launcher
    4:  ('sus_saw', 0x60, 0x3200, -0x1F0, 22),  # railgun
    5:  ('nz_dec', 0x30, 0x0C00, -0x30, 6),     # throw
    6:  ('blast', 0x7F, 0x1000, -0x18, 60),     # explosion
    7:  ('nz_dec', 0x40, 0x1000, 0, 5),         # hit wall
    8:  ('sus_25', 0x58, 0x0A00, -0x60, 10),    # player hurt
    9:  ('sus_saw', 0x60, 0x0C00, -0x28, 50),   # player death
    10: ('nz_dec', 0x50, 0x0800, -0x20, 12),    # enemy death
    11: ('sus_25', 0x30, 0x0900, 0x80, 6),      # jump
    12: ('nz_dec', 0x2C, 0x0600, 0, 3),         # land
    13: ('sus_sq', 0x50, 0x1000, 0x100, 10),    # pickup
    14: ('sus_sq', 0x40, 0x1800, 0, 4),         # menu select
    15: ('sus_sq', 0x50, 0x1000, 0x70, 16),     # start
    16: ('nz_sus', 0x48, 0x0400, 0x10, 24),     # door
    17: ('sus_tri', 0x58, 0x2000, -0x180, 16),  # EMP hit
    18: ('nz_dec', 0x30, 0x2000, 0, 2),         # click
    19: ('sus_tri', 0x30, 0x0C00, 0, 3),        # bounce
    20: ('nz_dec', 0x38, 0x1300, -0x60, 5),     # enemy shot
    21: ('blast', 0x68, 0x1600, -0x40, 20),     # heavy cannon
    22: ('sus_sq', 0x40, 0x1A00, 0, 6),         # alert
    23: ('nz_dec', 0x58, 0x0A00, -0x40, 8),     # sever
    24: ('sus_25', 0x50, 0x0C00, 0xC0, 20),     # rescue
    25: ('sus_sq', 0x50, 0x0C00, 0x80, 24),     # unlock
    26: ('sus_tri', 0x40, 0x0500, 0, 30),       # elevator
    27: ('sus_sq', 0x48, 0x2000, 0, 5),         # timer beep
}

# ================================================================ music
NOTE_IDX = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}

def note_num(s):
    """'C4' -> note number (1 = C1)."""
    name, octv = s[:-1], int(s[-1])
    return (octv - 1) * 12 + NOTE_IDX[name] + 1

def pitch_for(n):
    f = 32.703 * 2 ** ((n - 1) / 12)
    return min(0x3FFF, int(round(f * 4.096)))

def channel(events, loop=True):
    """events: list of tokens:
       ('i', name) instrument, ('v', vol), (note_str or '.', dur)
       drum shorthand: ('K', dur) ('S', dur) ('H', dur)"""
    out = [0x83] if loop else []
    cur_inst = None
    for ev in events:
        if ev[0] == 'i':
            out += [0x80, INST[ev[1]]]
            cur_inst = ev[1]
        elif ev[0] == 'v':
            out += [0x81, ev[1]]
        elif ev[0] in ('K', 'S', 'H'):
            inst = {'K': 'kick', 'S': 'snare', 'H': 'hat'}[ev[0]]
            if cur_inst != inst:
                out += [0x80, INST[inst]]
                cur_inst = inst
            out += [note_num('C4'), ev[1]]
        elif ev[0] == '.':
            out += [0x60, ev[1]]
        else:
            out += [note_num(ev[0]), ev[1]]
    out += [0x82] if loop else [0x00]
    return out

def seq(notes, dur):
    """'C4 E4 . G4' -> events with equal durations"""
    return [(n, dur) for n in notes.split()]

def rep(lst, n):
    return lst * n

def songs():
    S = {}
    # ---- 1 TITLE: slow, brooding A minor with a neon lead
    q = 36
    bass = [('i', 'bass'), ('v', 0x50)] + seq('A2 A2 F2 F2 C3 C3 G2 G2', q * 2)
    pad = [('i', 'pad'), ('v', 0x28)] + seq('E4 E4 C4 C4 G4 G4 D4 D4', q * 2)
    lead = [('i', 'lead'), ('v', 0x40)] + seq('. A4 C5 B4', q) + seq('A4 . E4 .', q) + seq('. F4 A4 G4', q) + \
        seq('F4 . C4 .', q) + seq('. E4 G4 A4', q) + seq('G4 . E4 .', q) + seq('. D4 G4 B4', q) + seq('A4 . . .', q)
    arp = [('i', 'arp'), ('v', 0x22)] + rep(seq('A3 C4 E4 C4', q // 2), 4) + rep(seq('F3 A3 C4 A3', q // 2), 4) + \
        rep(seq('C4 E4 G4 E4', q // 2), 4) + rep(seq('G3 B3 D4 B3', q // 2), 4)
    S[1] = [bass, lead, pad, arp]
    # ---- 2 BRIEFING: calm pulse
    S[2] = [[('i', 'bass'), ('v', 0x40)] + seq('D2 D2 A1 C2', 96),
            [('i', 'arp'), ('v', 0x24)] + rep(seq('D4 F4 A4 F4', 12), 4) + rep(seq('C4 E4 A4 E4', 12), 4),
            None,
            [('i', 'pad'), ('v', 0x20)] + seq('F3 E3 A3 G3', 96)]
    # ---- 3 CITY: synth bass in E minor, steady beat
    e = 12
    bassline = seq('E2 E2 E3 E2 G2 E2 D3 E2', e) * 2 + seq('C2 C2 C3 C2 D2 D2 D3 D2', e) * 2
    drums = rep([('K', e), ('H', e), ('S', e), ('H', e)], 8)
    lead = [('i', 'lead'), ('v', 0x38)] + seq('B4 . G4 A4', e * 2) + seq('B4 . D5 B4', e * 2) + \
        seq('C5 . B4 G4', e * 2) + seq('A4 . . .', e * 2)
    arp = [('i', 'arp'), ('v', 0x1C)] + rep(seq('E4 G4 B4 G4', e // 2 * 2), 4) + rep(seq('C4 E4 G4 E4', e // 2 * 2), 2) + \
        rep(seq('D4 F#4 A4 F#4', e // 2 * 2), 2)
    S[3] = [[('i', 'bass'), ('v', 0x58)] + bassline, lead, [('v', 0x48)] + drums, arp]
    # ---- 4 CAVE: dark, sparse, dripping
    q = 30
    S[4] = [[('i', 'bass'), ('v', 0x50)] + seq('D2 . . . C#2 . . . D2 . . . A1 . . .', q),
            [('i', 'lead'), ('v', 0x24)] + seq('. . A4 . . F4 . . . . G#4 . . E4 . .', q),
            [('v', 0x30)] + [('H', q), ('.', q * 3), ('K', q), ('.', q), ('H', q), ('.', q)] * 2,
            [('i', 'arp'), ('v', 0x14)] + rep(seq('D4 A4 F4 A4', q // 2), 4) + rep(seq('C#4 A4 E4 A4', q // 2), 4)]
    # ---- 5 TECH: driving D minor 16ths
    s16 = 7
    bass = seq('D2 D2 D3 D2 D2 C3 D2 A2', s16) * 2 + seq('A#1 A#1 A#2 A#1 C2 C2 C3 C2', s16) * 2
    drums = rep([('K', s16 * 2), ('H', s16), ('H', s16), ('S', s16 * 2), ('H', s16), ('K', s16)], 4)
    lead = [('i', 'lead'), ('v', 0x34)] + seq('D5 . A4 . F4 . D4 E4', s16 * 2) + seq('F4 . E4 . C4 . . .', s16 * 2)
    S[5] = [[('i', 'bass'), ('v', 0x58)] + bass, lead, [('v', 0x48)] + drums,
            [('i', 'pad'), ('v', 0x1C)] + seq('F4 F4 D4 E4', s16 * 8)]
    # ---- 6 BOSS: fast C minor riff
    s16 = 6
    bass = seq('C2 C2 C3 C2 D#2 C2 F2 F#2', s16) + seq('G2 G2 G3 G2 F2 D#2 D2 B1', s16)
    drums = rep([('K', s16), ('H', s16), ('S', s16), ('K', s16)], 4)
    lead = [('i', 'lead'), ('v', 0x3C)] + seq('C5 D#5 G5 D#5 C5 D#5 G5 G#5', s16 * 2) + \
        seq('G5 F5 D#5 D5 D#5 D5 C5 B4', s16 * 2)
    S[6] = [[('i', 'bass'), ('v', 0x5C)] + bass * 2, lead, [('v', 0x50)] + drums * 2,
            [('i', 'pad'), ('v', 0x20)] + seq('C4 G3', s16 * 16)]
    # ---- 7 CHASE: urgent G minor
    s = 7
    bass = seq('G2 G2 G3 G2 G2 G3 F2 F3', s) + seq('D#2 D#2 D#3 D#2 D2 D2 D3 D2', s)
    S[7] = [[('i', 'bass'), ('v', 0x58)] + bass * 2,
            [('i', 'lead'), ('v', 0x34)] + seq('G4 A#4 D5 C5 A#4 A4 G4 F4', s * 4),
            [('v', 0x48)] + rep([('K', s), ('H', s), ('S', s), ('H', s)], 8),
            [('i', 'arp'), ('v', 0x18)] + rep(seq('G4 D5', s), 16)]
    # ---- 8 CLEAR jingle (no loop)
    S[8] = [channel([('i', 'bass'), ('v', 0x50)] + seq('C3 G2 C3', 12) + [('C3', 48)], False),
            channel([('i', 'lead'), ('v', 0x48)] + seq('C5 E5 G5', 10) + [('C6', 50)], False),
            channel([('v', 0x40), ('K', 10), ('S', 10), ('K', 10), ('S', 40)], False),
            channel([('i', 'arp'), ('v', 0x28)] + seq('E4 G4 C5 E5 G5 C6', 8), False)]
    # ---- 9 FAIL
    S[9] = [channel([('i', 'bass'), ('v', 0x50)] + seq('C3 B2 A#2', 24) + [('A2', 80)], False),
            channel([('i', 'lead'), ('v', 0x40)] + seq('G4 F#4 F4', 24) + [('E4', 80)], False), None, None]
    # ---- 10 VICTORY: bright C major
    q = 24
    S[10] = [[('i', 'bass'), ('v', 0x50)] + seq('C2 C3 G2 C3 A1 A2 E2 A2 F1 F2 C2 F2 G1 G2 D2 G2', q),
             [('i', 'lead'), ('v', 0x40)] + seq('E5 . G5 . C6 . G5 E5 C5 . E5 . A5 . . . F5 . A5 . C6 . A5 F5 D5 . G5 . B5 . . .', q // 2 * 2 // 2),
             [('v', 0x40)] + rep([('K', q), ('H', q), ('S', q), ('H', q)], 4),
             [('i', 'pad'), ('v', 0x1C)] + seq('E4 C4 A3 B3', q * 4)]
    # convert to byte channels
    out = {}
    for k, chs in S.items():
        bc = []
        for ch in chs:
            if ch is None:
                bc.append(None)
            elif isinstance(ch, list) and ch and isinstance(ch[0], int):
                bc.append(ch)
            else:
                bc.append(channel(ch))
        out[k] = bc
    return out

# ================================================================ driver
def build():
    a = Asm(ORG)
    bit = 'bits'
    a.jmp('start')
    # ---- tables first
    a.label('bits')
    a.data([1, 2, 4, 8, 16, 32, 64, 128])

    a.label('start')
    a.mov_x_imm(0xEF)
    a.mov_sp_x()
    a.mov_a_imm(0)
    a.mov_x_imm(0)
    a.label('clr')
    a.mov_dpx_a(0)
    a.inc_x()
    a.cmp_x_imm(0xE0)
    a.bne('clr')
    a.dsp_imm(FLG, 0x20)
    a.dsp_imm(KON, 0)
    a.dsp_imm(KOFF, 0xFF)
    a.dsp_imm(MVOLL, 0x60)
    a.dsp_imm(MVOLR, 0x60)
    a.dsp_imm(EVOLL, 0)
    a.dsp_imm(EVOLR, 0)
    a.dsp_imm(EON, 0)
    a.dsp_imm(NON, 0)
    a.dsp_imm(PMON, 0)
    a.dsp_imm(EFB, 0)
    a.label('dirval')
    a.dsp_imm(DIR, 0)           # patched below with the directory page
    a.dsp_imm(KOFF, 0)
    # music voices default volume
    for v in range(4):
        a.dsp_imm(v * 16 + VOLL, 0x50)
        a.dsp_imm(v * 16 + VOLR, 0x50)
    a.mov_dp_imm(0xFA, 133)     # timer 0: ~60 Hz
    a.mov_dp_imm(0xF1, 0x31)    # enable timer 0, clear input ports
    a.mov_dp_imm(LAST, 0)
    a.mov_dp_imm(0xF4, 0x55)    # ready

    a.label('main')
    a.mov_a_dp(0xF4)
    a.cmp_a_dp(LAST)
    a.beq('nocmd')
    a.mov_dp_a(LAST)
    a.mov_a_dp(0xF5)
    a.mov_dp_a(CMD)
    a.mov_a_dp(0xF6)
    a.mov_dp_a(ARG)
    a.call('do_cmd')
    a.call('flush')
    a.mov_a_dp(LAST)
    a.mov_dp_a(0xF4)
    a.label('nocmd')
    a.mov_a_dp(0xFD)
    a.beq('main')
    a.call('tick')
    a.jmp('main')

    # ---- commands
    a.label('do_cmd')
    a.mov_a_dp(CMD)
    a.bmi('music_cmd')
    a.bne('sfx_cmd')
    a.ret()
    a.label('music_cmd')
    a.and_a_imm(0x7F)
    a.jmp('music_start')

    a.label('sfx_cmd')
    a.asl_a()
    a.asl_a()
    a.asl_a()
    a.mov_y_a()                 # Y = id*8
    a.mov_a_dp(RR)
    a.inc_dp(RR)
    a.and_a_imm(3)
    a.or_a_imm(4)
    a.mov_x_a()                 # X = voice 4..7
    a.mov_a_absy('sfx_tbl')     # instrument
    a.push_y()
    a.call('set_inst')
    a.pop_y()
    a.mov_a_absy('sfx_tbl+1')   # volume
    a.call('set_vol')
    a.mov_a_absy('sfx_tbl+2')
    a.mov_dpx_a(S_PLO)
    a.mov_dp_a(PITCH)
    a.mov_a_absy('sfx_tbl+3')
    a.mov_dpx_a(S_PHI)
    a.mov_dp_a(PITCH + 1)
    a.mov_a_absy('sfx_tbl+4')
    a.mov_dpx_a(S_DLO)
    a.mov_a_absy('sfx_tbl+5')
    a.mov_dpx_a(S_DHI)
    a.mov_a_absy('sfx_tbl+6')
    a.mov_dpx_a(S_T)
    a.call('write_pitch')
    a.mov_a_absx('bits')
    a.or_a_dp(KONM)
    a.mov_dp_a(KONM)
    a.ret()

    # X = voice, A = volume
    a.label('set_vol')
    a.mov_dp_a(TMP)
    a.mov_a_x()
    a.xcn_a()
    a.mov_dp_a(0xF2)
    a.mov_dp_dp(0xF3, TMP)
    a.or_a_imm(1)
    a.mov_dp_a(0xF2)
    a.mov_dp_dp(0xF3, TMP)
    a.ret()

    # X = voice, A = instrument (clobbers Y)
    a.label('set_inst')
    a.asl_a()
    a.asl_a()
    a.mov_y_a()
    a.mov_a_x()
    a.xcn_a()
    a.or_a_imm(SRCN)
    a.mov_dp_a(0xF2)
    a.mov_a_absy('inst_tbl')
    a.mov_dp_a(0xF3)
    a.mov_a_x()
    a.xcn_a()
    a.or_a_imm(ADSR1)
    a.mov_dp_a(0xF2)
    a.mov_a_absy('inst_tbl+1')
    a.mov_dp_a(0xF3)
    a.mov_a_x()
    a.xcn_a()
    a.or_a_imm(ADSR2)
    a.mov_dp_a(0xF2)
    a.mov_a_absy('inst_tbl+2')
    a.mov_dp_a(0xF3)
    a.mov_a_absy('inst_tbl+3')
    a.mov_dp_a(FLAGS)
    a.ret()

    # X = voice, PITCH = value
    a.label('write_pitch')
    a.mov_a_x()
    a.xcn_a()
    a.or_a_imm(PL)
    a.mov_dp_a(0xF2)
    a.mov_dp_dp(0xF3, PITCH)
    a.or_a_imm(PH)
    a.mov_dp_a(0xF2)
    a.mov_dp_dp(0xF3, PITCH + 1)
    a.ret()

    # write accumulated key on / key off
    a.label('flush')
    a.mov_a_dp(KOFFM)
    a.or_a_dp(KOFFS)
    a.mov_dp_a(KOFFS)
    a.mov_a_dp(KONM)
    a.eor_a_imm(0xFF)
    a.and_a_dp(KOFFS)
    a.mov_dp_a(KOFFS)
    a.dsp_a(KOFF)
    a.mov_a_dp(KONM)
    a.dsp_a(KON)
    a.mov_dp_imm(KONM, 0)
    a.mov_dp_imm(KOFFM, 0)
    a.ret()

    # ---- music
    a.label('music_start')
    a.push_a()
    a.mov_a_dp(KOFFM)
    a.or_a_imm(0x0F)
    a.mov_dp_a(KOFFM)
    a.mov_dp_imm(MON, 0)
    a.pop_a()
    a.cmp_a_imm(0)
    a.bne('ms_go')
    a.ret()
    a.label('ms_go')
    a.dec_a()
    a.asl_a()
    a.asl_a()
    a.asl_a()
    a.mov_y_a()
    a.mov_x_imm(0)
    a.label('ms_loop')
    a.mov_a_absy('song_tbl')
    a.mov_dpx_a(M_PLO)
    a.mov_dpx_a(M_LLO)
    a.inc_y()
    a.mov_a_absy('song_tbl')
    a.mov_dpx_a(M_PHI)
    a.mov_dpx_a(M_LHI)
    a.inc_y()
    a.cmp_a_imm(0)
    a.beq('ms_skip')
    a.mov_a_imm(1)
    a.mov_dpx_a(M_WAIT)
    a.mov_a_imm(0)
    a.mov_dpx_a(M_INST)
    a.mov_a_absx('bits')
    a.or_a_dp(MON)
    a.mov_dp_a(MON)
    a.label('ms_skip')
    a.inc_x()
    a.cmp_x_imm(4)
    a.bne('ms_loop')
    a.ret()

    # ---- timer tick
    a.label('tick')
    a.mov_x_imm(4)
    a.label('sfx_l')
    a.mov_a_dpx(S_T)
    a.beq('sfx_n')
    a.dec_dpx(S_T)
    a.mov_a_dpx(S_PLO)
    a.clrc()
    a.adc_a_dpx(S_DLO)
    a.mov_dpx_a(S_PLO)
    a.mov_dp_a(PITCH)
    a.mov_a_dpx(S_PHI)
    a.adc_a_dpx(S_DHI)
    a.and_a_imm(0x3F)
    a.mov_dpx_a(S_PHI)
    a.mov_dp_a(PITCH + 1)
    a.call('write_pitch')
    a.mov_a_dpx(S_T)
    a.bne('sfx_n')
    a.mov_a_absx('bits')
    a.or_a_dp(KOFFM)
    a.mov_dp_a(KOFFM)
    a.label('sfx_n')
    a.inc_x()
    a.cmp_x_imm(8)
    a.bne('sfx_l')
    a.mov_x_imm(0)
    a.label('mus_l')
    a.call('music_ch')
    a.inc_x()
    a.cmp_x_imm(4)
    a.bne('mus_l')
    a.jmp('flush')

    # X = channel
    a.label('music_ch')
    a.mov_a_absx('bits')
    a.and_a_dp(MON)
    a.bne('mc_on')
    a.ret()
    a.label('mc_on')
    a.dec_dpx(M_WAIT)
    a.beq('mc_go')
    a.ret()
    a.label('mc_go')
    a.mov_a_dpx(M_PLO)
    a.mov_dp_a(PTR)
    a.mov_a_dpx(M_PHI)
    a.mov_dp_a(PTR + 1)
    a.label('mc_read')
    a.mov_y_imm(0)
    a.mov_a_indy(PTR)
    a.incw_dp(PTR)
    a.cmp_a_imm(0)
    a.beq('mc_end')
    a.cmp_a_imm(0x60)
    a.bcc('mc_note')
    a.beq('mc_rest')
    a.cmp_a_imm(0x80)
    a.beq('mc_inst')
    a.cmp_a_imm(0x81)
    a.beq('mc_vol')
    a.cmp_a_imm(0x82)
    a.beq('mc_loop')
    a.cmp_a_imm(0x83)
    a.beq('mc_setloop')
    a.label('mc_end')
    a.mov_a_absx('bits')
    a.eor_a_imm(0xFF)
    a.and_a_dp(MON)
    a.mov_dp_a(MON)
    a.jmp('mc_save')
    a.label('mc_inst')
    a.mov_a_indy(PTR)
    a.incw_dp(PTR)
    a.mov_dpx_a(M_INST)
    a.bra('mc_read')
    a.label('mc_vol')
    a.mov_a_indy(PTR)
    a.incw_dp(PTR)
    a.call('set_vol')
    a.bra('mc_read')
    a.label('mc_loop')
    a.mov_a_dpx(M_LLO)
    a.mov_dp_a(PTR)
    a.mov_a_dpx(M_LHI)
    a.mov_dp_a(PTR + 1)
    a.bra('mc_read')
    a.label('mc_setloop')
    a.mov_a_dp(PTR)
    a.mov_dpx_a(M_LLO)
    a.mov_a_dp(PTR + 1)
    a.mov_dpx_a(M_LHI)
    a.bra('mc_read')
    a.label('mc_rest')
    a.mov_a_indy(PTR)
    a.incw_dp(PTR)
    a.mov_dpx_a(M_WAIT)
    a.mov_a_absx('bits')
    a.or_a_dp(KOFFM)
    a.mov_dp_a(KOFFM)
    a.jmp('mc_save')
    a.label('mc_note')
    a.push_a()
    a.mov_a_dpx(M_INST)
    a.call('set_inst')
    a.pop_a()
    a.asl_a()
    a.mov_y_a()
    a.mov_a_absy('pitch_tbl-2')
    a.mov_dp_a(PITCH)
    a.mov_a_absy('pitch_tbl-1')
    a.mov_dp_a(PITCH + 1)
    a.mov_a_dp(FLAGS)
    a.and_a_imm(1)
    a.beq('mc_p')
    a.mov_dp_imm(PITCH, 0x00)
    a.mov_dp_imm(PITCH + 1, 0x10)
    a.label('mc_p')
    a.call('write_pitch')
    a.mov_y_imm(0)
    a.mov_a_indy(PTR)
    a.incw_dp(PTR)
    a.mov_dpx_a(M_WAIT)
    a.mov_a_absx('bits')
    a.or_a_dp(KONM)
    a.mov_dp_a(KONM)
    a.label('mc_save')
    a.mov_a_dp(PTR)
    a.mov_dpx_a(M_PLO)
    a.mov_a_dp(PTR + 1)
    a.mov_dpx_a(M_PHI)
    a.ret()

    # ---- data tables
    a.label('inst_tbl')
    for (n, smp, ad1, ad2, fl) in INSTRUMENTS:
        a.data([SRC[smp], ad1, ad2, fl])
    a.label('sfx_tbl')
    for i in range(64):
        if i in SFX:
            inst, vol, p, d, ln = SFX[i]
            a.data([INST[inst], vol, p & 255, p >> 8, d & 255, (d >> 8) & 255, ln, 0])
        else:
            a.data([0] * 8)
    a.label('pitch_tbl')
    for n in range(1, 96):
        p = pitch_for(n)
        a.data([p & 255, p >> 8])
    S = songs()
    a.label('song_tbl')
    for k in range(1, 11):
        chs = S[k]
        for c in range(4):
            if c < len(chs) and chs[c]:
                a.w16('song%d_%d' % (k, c))
            else:
                a.w16(0)
    for k in range(1, 11):
        for c, ch in enumerate(S[k]):
            if ch:
                a.label('song%d_%d' % (k, c))
                a.data(ch)
    # ---- samples + directory (page aligned)
    while a.pc() & 0xFF:
        a.data([0])
    dir_addr = a.pc()
    smp = make_samples()
    blobs = [brr_encode(*smp[k]) for k in SAMPLE_ORDER]
    a.label('dir')
    a.data([0] * (4 * len(blobs)))
    starts = []
    for bl in blobs:
        starts.append(a.pc())
        a.data(bl)
    code = bytearray(a.link())
    for i, st in enumerate(starts):
        off = dir_addr - ORG + i * 4
        code[off:off + 4] = bytes([st & 255, st >> 8, st & 255, st >> 8])
    # patch DIR register value (dsp_imm emits 8F reg F2 8F val F3)
    p = a.labels['dirval'] - ORG
    assert code[p] == 0x8F and code[p + 1] == DIR and code[p + 3] == 0x8F
    code[p + 4] = dir_addr >> 8
    assert ORG + len(code) < 0xFFC0
    return bytes(code)

if __name__ == '__main__':
    import sys
    data = build()
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), '..', 'build', 'spc.bin')
    open(out, 'wb').write(data)
    print('spc driver+data: %d bytes' % len(data))
