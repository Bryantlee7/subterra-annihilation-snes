#!/usr/bin/env python3
"""Build a test ROM with scripted input, run it in mednafen, grab frames.

usage: run_test.py NAME SECONDS [--mission N] [--script FILE] [--every N]
                   [--publish "caption" --frames 120,300]
Frames land in scratch/NAME/fNNNNN.png plus sheet.png (last 16 sampled).
"""
import argparse, os, shutil, subprocess, sys, glob
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRATCH = os.environ.get('TEST_OUT', '/tmp/claude-1001/-home-bryant/b36f55a9-2dc9-4ecd-8c55-56694bd115ad/scratchpad/tests')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('name')
    ap.add_argument('seconds', type=float)
    ap.add_argument('--mission', type=int)
    ap.add_argument('--script')
    ap.add_argument('--every', type=int, default=30)
    ap.add_argument('--publish')
    ap.add_argument('--frames', default='')
    a = ap.parse_args()
    out = os.path.join(SCRATCH, a.name)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(out)
    rom = os.path.join(out, 'test.sfc')
    cmd = [sys.executable, os.path.join(ROOT, 'build.py'), '--out', rom]
    if a.mission:
        cmd += ['--mission', str(a.mission)]
    if a.script:
        cmd += ['--script', a.script]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        print(r.stdout, r.stderr)
        sys.exit(1)
    mov = os.path.join(out, 'run.mov')
    env = dict(os.environ, SDL_AUDIODRIVER='dummy')
    home = os.path.join(out, 'home')
    os.makedirs(home)
    env['HOME'] = home
    subprocess.run(['xvfb-run', '-a', 'timeout', '-s', 'INT', str(a.seconds),
                    'mednafen', '-video.driver', 'sdl', '-sound', '1', '-sound.driver', 'sdl',
                    '-qtrecord', mov, '-qtrecord.vcodec', 'png', rom],
                   env=env, capture_output=True)
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'frames.py'), mov, out,
                    str(a.every), '--sheet'])
    # SRAM debug dump
    for p in glob.glob(os.path.join(home, '.mednafen', 'sav', '*.srm')):
        d = open(p, 'rb').read()
        vals = [int.from_bytes(d[i:i + 2], 'little') for i in range(0x10, 0x20, 2)]
        print('debug: px=%d py=%d hp=%d state=%d cam=%d,%d frame=%d pc=%04X' % tuple(vals), 'nmi-frame=%d' % int.from_bytes(d[0x20:0x22], 'little'))
        names = ['player', 'spawn', 'actors', 'pbullets', 'ebullets', 'particles', 'camera', 'draw', 'hud', 'joy', 'sndflush', 'unused', 'TOTAL']
        prof = [int.from_bytes(d[0x40 + i * 2:0x42 + i * 2], 'little') for i in range(len(names))]
        if any(prof):
            fr = max(1, vals[6])
            print('histogram (32-line buckets):', [int.from_bytes(d[0x80 + i * 2:0x82 + i * 2], 'little') for i in range(9)])
            print('max frame lines', int.from_bytes(d[0x60:0x62], 'little'), 'frames over 180:', int.from_bytes(d[0x62:0x64], 'little'))
            print('profile (avg scanlines/frame of 262):', ', '.join('%s %.1f' % (n, p / fr) for n, p in zip(names, prof)))
        tr = [int.from_bytes(d[0x600 + i * 2:0x602 + i * 2], 'little') for i in range(256)]
        open(os.path.join(out, 'trace.txt'), 'w').write('\n'.join('%d %04X' % (i, v) for i, v in enumerate(tr)))
        # symbol lookup for the pc
        pc = vals[-1]
        best = None
        for line in open(os.path.join(ROOT, 'build', 'game.map')):
            pass
    if a.publish:
        for f in [x for x in a.frames.split(',') if x]:
            p = os.path.join(out, 'f%05d.png' % int(f))
            if os.path.exists(p):
                subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'publish_shot.py'), p, a.publish])
    print('output in', out)

main()
