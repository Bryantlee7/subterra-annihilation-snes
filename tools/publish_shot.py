#!/usr/bin/env python3
"""Copy a screenshot into public_html's progress gallery and rebuild its index.

usage: publish_shot.py image.png "caption" [--scale N]
Images are listed newest first on
https://bryant.redconfetti.com/games/subterra/progress/
"""
import html, json, os, sys, time
from PIL import Image

OUT = os.path.expanduser('~/public_html/games/subterra/progress')
DB = os.path.join(OUT, 'shots.json')

def main():
    src, caption = sys.argv[1], sys.argv[2]
    scale = 2
    if '--scale' in sys.argv:
        scale = int(sys.argv[sys.argv.index('--scale') + 1])
    os.makedirs(OUT, exist_ok=True)
    shots = json.load(open(DB)) if os.path.exists(DB) else []
    name = 'shot%03d.png' % (len(shots) + 1)
    im = Image.open(src).convert('RGB')
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(os.path.join(OUT, name))
    shots.append({'file': name, 'caption': caption,
                  'time': time.strftime('%Y-%m-%d %H:%M')})
    json.dump(shots, open(DB, 'w'), indent=1)
    write_index(shots)
    print('published', name)

def write_index(shots):
    items = []
    for s in reversed(shots):
        items.append(
            '<figure><a href="%s"><img src="%s" alt="%s"></a>'
            '<figcaption><b>%s</b> &middot; %s</figcaption></figure>'
            % (s['file'], s['file'], html.escape(s['caption']),
               html.escape(s['time']), html.escape(s['caption'])))
    page = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Subterra: Annihilation - Progress</title>
<style>
body { background:#101018; color:#ddd; font-family:system-ui,sans-serif; margin:0; padding:16px; }
h1 { color:#f08a20; font-size:1.4em; }
a { color:#40f0f0; }
figure { margin:0 0 28px; }
img { max-width:100%%; image-rendering:pixelated; border:2px solid #2a3a5a; }
figcaption { margin-top:6px; color:#aab; }
</style>
</head>
<body>
<h1>Subterra: Annihilation &mdash; build progress</h1>
<p>A real SNES game being built step by step. Newest screenshots first.
<a href="../../../">&larr; Home</a></p>
%s
</body>
</html>
''' % '\n'.join(items)
    open(os.path.join(OUT, 'index.html'), 'w').write(page)

main()
