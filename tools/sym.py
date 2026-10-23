#!/usr/bin/env python3
"""Nearest label for a bank-0/80 address: sym.py A082"""
import sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def lookup(addr):
    best = None
    for line in open(os.path.join(ROOT, 'build', 'game.lbl')):
        p = line.split()
        if len(p) < 3:
            continue
        a = int(p[1], 16)
        if a > 0xFFFF:
            continue
        name = p[2].lstrip('.')
        if name.startswith('@') or name.startswith('__'):
            continue
        if a <= addr and (best is None or a > best[0]):
            best = (a, name)
    return best
if __name__ == '__main__':
    for x in sys.argv[1:]:
        b = lookup(int(x, 16) & 0xFFFF)
        print(x, '->', b[1], '+%d' % ((int(x, 16) & 0xFFFF) - b[0]))
