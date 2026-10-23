import sys
from PIL import Image
from snesgfx import Canvas, rgb
import sprites, palettes

sh, tables = sprites.build()
SP = palettes.SPR_PALS

def tile_canvas(t, size):
    x, y = (t % 16) * 8, (t // 16) * 8
    return sh.grid.crop(x, y, size, size)

def put(img, t, size, x, y, pal, flip=False):
    c = tile_canvas(t, size)
    if flip: c = c.flip_h()
    for yy in range(size):
        for xx in range(size):
            v = c.p[yy][xx]
            if v:
                img.putpixel((x + xx, y + yy), rgb(SP[pal][v]))

N = sh.names
def human(img, ox, oy, pal, legs, torso, head, armset, arm_tiles, aim, flip=False):
    # origin feet center at (ox, oy)
    def P(t, size, dx, dy):
        if flip:
            dx = -dx - size
        put(img, t, size, ox + dx, oy + dy, pal, flip)
    ax = tables[armset][aim]
    sx, sy = sprites.SHOULDER
    P(N[legs], 16, -8, -16)
    P(N[torso], 16, -8, -26)
    P(N[head], 8, -3, -32)
    P(N[arm_tiles + str(aim)], 16, ax[0][0] + sx, ax[0][1] + sy)
    mx, my = ax[1][0] + sx, ax[1][1] + sy
    if flip: mx = -mx
    img.putpixel((ox + mx, oy + my), (255, 255, 0))

img = Image.new('RGB', (256, 224), (20, 24, 40))
for i, p in enumerate(['STAND', 'WALK1', 'WALK2', 'WALK3', 'WALK4', 'JUMP', 'CROUCH', 'CLIMB1']):
    human(img, 14 + i * 26, 40, 0, 'PL_LEGS_' + p, 'PL_TORSO', 'PL_HEAD', 'pl_arm', 'PL_ARM', i % 4)
for i, p in enumerate(['STAND', 'WALK1', 'WALK2', 'WALK3', 'WALK4', 'CROUCH']):
    human(img, 14 + i * 26, 84, 1 + (i % 2), 'HU_LEGS_' + p, 'HU_TORSO', ['HU_HEAD_GUARD', 'HU_HEAD_SOLDIER', 'HU_HEAD_BERET'][i % 3], 'hu_arm', 'HU_ARM', i % 4, flip=i > 2)
for i, p in enumerate(['STAND', 'WALK1', 'WALK2', 'WALK3']):
    human(img, 14 + i * 26, 128, 3, 'RB_LEGS_' + p, 'RB_TORSO', 'RB_HEAD', 'rb_arm', 'RB_ARM', i)
human(img, 180, 84, 7, 'HU_LEGS_STAND', 'HU_TORSO', 'HU_HEAD_CAPTIVE', 'hu_arm', 'HU_ARM', 0)
human(img, 210, 84, 0, 'PL_LEGS_STAND', 'PL_TORSO_DMG', 'PL_HEAD_DMG', 'pl_arm', 'PL_ARM', 0)
# heavy
for f in range(2):
    ox, oy = 140 + f * 50, 128
    put(img, N['HV_LEGS%d_L' % f], 16, ox - 16, oy - 16, 3); put(img, N['HV_LEGS%d_R' % f], 16, ox, oy - 16, 3)
    put(img, N['HV_BODY_L'], 16, ox - 16, oy - 32, 3); put(img, N['HV_BODY_R'], 16, ox, oy - 32, 3)
    put(img, N['HV_CANNON'], 16, ox + tables['hv_arm'][0][0] + 6, oy + tables['hv_arm'][0][1] - 22, 3)
x = 8
for n, pal in [('CR_BODY0', 3), ('CR_BODY1', 3), ('DR_BODY0', 3), ('DR_BODY1', 3), ('GEN0_TOP', 3), ('TERM0', 3), ('TERM2', 3),
               ('PK_HEALTH', 6), ('PK_MG', 6), ('PK_PLASMA', 6), ('PK_EMP', 6), ('PK_RAIL', 6), ('PK_GRENADE', 6), ('PK_KEY', 6), ('PK_CHIP', 6)]:
    put(img, N[n], 16, x, 150, pal); x += 16
put(img, N['GEN0_BOT'], 16, 8 + 4 * 16, 166, 3)
x = 8
for f in range(4):
    put(img, N['FX_EXPL%d' % f], 16, x, 190, 4); x += 18
for n in sh.names:
    if n.startswith(('FX_', 'DB_', 'UI_')) and not n.startswith('FX_EXPL'):
        pal = 5 if n.startswith('DB_') else (6 if n.startswith('UI_') else 4)
        put(img, N[n], 8, x, 194, pal); x += 9
        if x > 248: break
img = img.resize((768, 672), Image.NEAREST)
img.save(sys.argv[1])
print('blocks used', sh.next_block, 'of 128')
