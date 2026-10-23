#!/usr/bin/env python3
"""Print start, exit and objective positions for a mission: entpos.py 2"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import levels
inv = {v: k for k, v in levels.ET.items()}
m = int(sys.argv[1]) - 1
L, info = levels.generate(m)
sx, sy = info['start']
print('start px', sx * 16 + 8, (sy + 1) * 16, 'obj', info['obj'], info['count'])
if info.get('exit'):
    ex, ey = info['exit']
    print('exit px', ex * 16 + 8, (ey + 1) * 16)
show = set(sys.argv[2:]) or {'PK_CHIP', 'GENERATOR', 'TERMINAL', 'CAPTIVE', 'FRIEND', 'BOSS', 'COMMANDER', 'PK_KEY', 'ELEVATOR'}
for t, p, x, y in L.ents:
    if inv[t] in show:
        print(inv[t], x, y, 'param', p)
