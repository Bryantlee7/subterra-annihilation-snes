#!/usr/bin/env python3
"""Build the ROM.  usage: python3 build.py [--mission N] [--script file] [--out path]

--mission N   boot straight into mission N (1-10), skipping the title (testing)
--script F    scripted joypad input (testing), see tools/run_test.py
"""
import argparse, os, subprocess, sys
ROOT = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(ROOT, 'build')

def run(cmd):
    r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    out = (r.stdout + r.stderr).strip()
    lines = [l for l in out.splitlines() if 'does not exist' not in l]
    if lines:
        print('\n'.join(lines))
    if r.returncode:
        sys.exit(r.returncode)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mission', type=int)
    ap.add_argument('--script')
    ap.add_argument('--out', default=os.path.join(B, 'game.sfc'))
    a = ap.parse_args()
    os.makedirs(B, exist_ok=True)
    run([sys.executable, 'tools/build_assets.py'])
    flags = []
    if a.mission:
        flags += ['-D', 'START_MISSION=%d' % (a.mission - 1)]
    script_inc = os.path.join(B, 'autotest_script.inc')
    if a.script:
        flags += ['-D', 'AUTOTEST=1']
        steps = []
        for line in open(a.script):
            line = line.split('#')[0].strip()
            if not line:
                continue
            n, *btns = line.split()
            if n.upper() == 'WARP':
                steps.append((0xFFFF, int(btns[0])))
                steps.append((0xFFFE, int(btns[1])))
                continue
            mask = 0
            for b in btns:
                mask |= BTN[b.upper()]
            steps.append((int(n), mask))
        with open(script_inc, 'w') as f:
            f.write('at_script:\n')
            for n, m in steps:
                f.write('    .word %d, $%04X\n' % (n, m))
            f.write('    .word 0, 0\n')
    else:
        open(script_inc, 'w').write('; no script\n')
    run(['ca65', '--cpu', '65816', '-g', '-I', 'src'] + flags + ['-o', 'build/game.o', 'src/main.s'])
    run(['ld65', '-C', 'snes.cfg', '-o', a.out, '-m', 'build/game.map', '-Ln', 'build/game.lbl', 'build/game.o'])
    run([sys.executable, 'tools/fix_checksum.py', a.out])

BTN = dict(B=0x8000, Y=0x4000, SELECT=0x2000, START=0x1000, UP=0x0800, DOWN=0x0400,
           LEFT=0x0200, RIGHT=0x0100, A=0x0080, X=0x0040, L=0x0020, R=0x0010, NONE=0)
main()
