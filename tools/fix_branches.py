#!/usr/bin/env python3
"""Rewrite out-of-range short branches reported by ca65 into inverted
branch + jmp. Reads ca65 error output on stdin."""
import re, sys, collections
INV = {'bcc': 'bcs', 'bcs': 'bcc', 'beq': 'bne', 'bne': 'beq', 'bmi': 'bpl', 'bpl': 'bmi',
       'bvc': 'bvs', 'bvs': 'bvc'}
errs = collections.defaultdict(set)
for line in sys.stdin:
    m = re.match(r'(src/[\w.]+)\((\d+)\): Error: Range error \(-?\d+ not in \[-128\.\.127\]\)', line)
    if m:
        errs[m.group(1)].add(int(m.group(2)))
n = 0
for path, lines_ in errs.items():
    src = open(path).read().split('\n')
    for ln in sorted(lines_, reverse=True):
        l = src[ln - 1]
        m = re.match(r'^(\S*:)?(\s*)(b(?:cc|cs|eq|ne|mi|pl|vc|vs|ra))\s+(\S+)(.*)$', l)
        if not m:
            print('cannot fix', path, ln, l)
            continue
        label, ws, op, target, rest = m.groups()
        label = label or ''
        n += 1
        tag = '@lb%d_%d' % (ln, n)
        if op == 'bra':
            new = ['%s%sjmp %s' % (label, ws if label else '    ', target)]
        else:
            new = ['%s%s%s %s' % (label, ws if label else '    ', INV[op], tag),
                   '    jmp %s' % target,
                   '%s:' % tag]
        src[ln - 1:ln] = new
    open(path, 'w').write('\n'.join(src))
print('fixed', n)
