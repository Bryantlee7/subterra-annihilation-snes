"""All palettes. Colors are '#rrggbb'; converted to BGR555 at build time."""

# --- Sprite palettes (OBJ 0-7). Slot meaning follows snesgfx.LETTERS. ---
#            .        k          d          m          l          o          O          v          V          s          S          g          G          r          R          w
SPR_PALS = [
    # 0 player: steel-blue powered armor, orange accents, cyan visor
    ['#000000', '#0c0c14', '#24345a', '#46669a', '#88aad8', '#8a3a0c', '#f08a20', '#0c5a6a', '#40f0f0', '#7a4a30', '#d89a70', '#30303a', '#8a8a9a', '#6a0808', '#d02020', '#ffffff'],
    # 1 guard: black/gray uniform, gold badge, brown belt
    ['#000000', '#0c0c10', '#26262e', '#46465a', '#7a7a90', '#5a3a1a', '#d8b040', '#1a1a1a', '#606080', '#8a5a3a', '#e0a878', '#2a2a2a', '#7a7a7a', '#6a0808', '#d02020', '#ffffff'],
    # 2 soldier: olive camo, red beret slots
    ['#000000', '#0c100a', '#28361a', '#4a6a2a', '#7a9a4a', '#3a2a14', '#8a6a3a', '#6a1010', '#c02828', '#6a3a20', '#b07850', '#2a2a2a', '#7a7a7a', '#6a0808', '#d02020', '#ffffff'],
    # 3 robots: gunmetal, hazard yellow, red eye, blue core, orange sparks
    ['#000000', '#08080c', '#2e2e3a', '#565668', '#9a9ab0', '#8a6a00', '#f0c020', '#800000', '#ff3020', '#1a4a90', '#50b0ff', '#1e1e22', '#6a6a72', '#c05a00', '#ffd040', '#ffffff'],
    # 4 effects: explosion reds/oranges, plasma green, EMP blue, rail violet, smoke
    ['#000000', '#200808', '#a02000', '#f06000', '#ffd040', '#108a20', '#70ff60', '#1040c0', '#70e8ff', '#6a2aa0', '#d8b0ff', '#404040', '#909090', '#b01010', '#ff5050', '#ffffff'],
    # 5 debris: rock browns, metal grays, blood
    ['#000000', '#0c0806', '#3a2410', '#6a4a28', '#9a7a50', '#3a3a44', '#8a8a9a', '#1a1a1a', '#5a5a5a', '#c05a00', '#ffd040', '#2a2a2a', '#7a7a7a', '#5a0000', '#b80808', '#ffffff'],
    # 6 pickups
    ['#000000', '#0c0c0c', '#1a5a1a', '#2a9a2a', '#7ae07a', '#8a6a00', '#f0d040', '#105090', '#40c0ff', '#5a2a8a', '#c080ff', '#3a3a3a', '#a0a0a0', '#900000', '#ff3030', '#ffffff'],
    # 7 captives / friend: red jacket, jeans, hair
    ['#000000', '#0c0808', '#5a1414', '#9a2a2a', '#d85050', '#22224a', '#44449a', '#3a2410', '#d8b050', '#8a5a3a', '#f0b890', '#2a2a2a', '#7a7a7a', '#6a0808', '#d02020', '#ffffff'],
]

# --- BG3 (HUD/text) 2bpp palettes, CGRAM 0-31 (8 palettes x 4 colors) ---
BG3_PALS = [
    ['#000000', '#000000', '#ffffff', '#8a8aa0'],  # 0 white text on black
    ['#000000', '#000000', '#ffd040', '#f08a20'],  # 1 yellow / orange
    ['#000000', '#000000', '#60ff60', '#208a20'],  # 2 green
    ['#000000', '#000000', '#ff4040', '#8a1010'],  # 3 red
    ['#000000', '#000000', '#40f0f0', '#2070a0'],  # 4 cyan
    ['#000000', '#000000', '#c080ff', '#6a2aa0'],  # 5 purple
    ['#000000', '#3a3a50', '#ffffff', '#8a8aa0'],  # 6 white on slate (map/boxes)
    ['#000000', '#7a7a7a', '#b8b8c8', '#4a4a5a'],  # 7 automap: solid/open/special
]

# --- BG palettes 2..7 (CGRAM 32..127) ---
# Pal 2 EARTH (per region):
#  1 outline 2 dirt dark 3 dirt mid 4 dirt light 5 dirt hilite 6 pebble dk 7 pebble lt
#  8 top accent dk 9 top accent lt 10 rock dk 11 rock mid 12 rock lt 13 rock hilite
#  14 crystal dk 15 crystal lt
EARTH = {
    'surface': ['#000000', '#140c06', '#3a2412', '#5a3a1e', '#7a5430', '#9a7048', '#2a1a0c', '#a08a68', '#1a3a12', '#3a7a26', '#30303a', '#4a4a58', '#6a6a7e', '#8a8aa0', '#205a8a', '#60c0ff'],
    'clay':    ['#000000', '#180a04', '#5a2a10', '#8a4a20', '#b06a34', '#d08a50', '#3a1a08', '#e0b080', '#4a3a10', '#8a7a2a', '#3a2a24', '#5a4438', '#7a6250', '#9a826a', '#8a2a8a', '#ff70e0'],
    'granite': ['#000000', '#0a0a10', '#2a2a36', '#44445a', '#62627e', '#8282a0', '#1a1a24', '#a0a0b8', '#1a2a3a', '#2a5a7a', '#3a3040', '#564a5e', '#74687e', '#9a8aa6', '#1a6a6a', '#50ffe0'],
    'magma':   ['#000000', '#140404', '#3a0e0a', '#5a1a10', '#7a2a18', '#9a4020', '#240806', '#c06030', '#6a2000', '#f08000', '#2a2020', '#44302a', '#5e4034', '#7a5040', '#a03000', '#ffd020'],
    'ice':     ['#000000', '#08101a', '#1a3046', '#2a4a6a', '#4a729a', '#80a8d0', '#10202e', '#c0e0ff', '#4a6a8a', '#d0f0ff', '#283848', '#3c5468', '#587890', '#80a0b8', '#2a60c0', '#a0f0ff'],
    'moss':    ['#000000', '#0a1006', '#1e2e12', '#2e461a', '#466228', '#628238', '#141e0a', '#8aa060', '#2a5a10', '#70c030', '#26302a', '#3a483e', '#566a5a', '#748a78', '#2a8a2a', '#a0ff60'],
    'amethyst':['#000000', '#0e0814', '#2a1a3a', '#40285a', '#5a3a7a', '#7a54a0', '#1a1024', '#a088c0', '#3a1a4a', '#8a3aa0', '#2a2434', '#423a52', '#5e5474', '#7e7496', '#a020c0', '#ff80ff'],
    'coal':    ['#000000', '#060606', '#1a1816', '#2a2622', '#3e3830', '#564e44', '#100e0c', '#6a6050', '#2a2010', '#6a5020', '#202024', '#34343a', '#4a4a52', '#66666e', '#405a2a', '#a0ff40'],
    'facility':['#000000', '#0a0a0a', '#2e2a26', '#46403a', '#625a50', '#827868', '#1e1a16', '#a09888', '#2a2a2a', '#5a5a5a', '#2a2e34', '#40464e', '#5a626c', '#7a848e', '#2a4a8a', '#80c0ff'],
}

# Pal 3 STONE / CITY GROUND
STONE = ['#000000', '#08080a', '#1e1e24', '#34343e', '#4c4c58', '#6a6a78', '#1a1a20', '#2c2c34', '#d8b020', '#5a5a64', '#8a8a96', '#3a3632', '#5a544c', '#7e766a', '#a0a0aa', '#e0e0e8']
# Pal 4 METAL / TECH
METAL = ['#000000', '#060608', '#1a1c22', '#2e323c', '#4a505e', '#6e7686', '#9aa2b4', '#7a3a16', '#e8b818', '#26262a', '#30e050', '#ff2828', '#40e0f0', '#0a3a4a', '#6a3a16', '#c87a3a']
# Pal 5 CITY BUILDINGS / NEON
CITY = ['#000000', '#06060c', '#14142a', '#22224a', '#34346a', '#0c0c1e', '#f0d060', '#f09040', '#ff3aa0', '#ffa0e0', '#30d8ff', '#a0f0ff', '#40ff80', '#1a1a2a', '#3a3a5a', '#ffffff']
# Pal 6 MISC: ladders, doors, lasers, slime
MISC = ['#000000', '#080808', '#5a3a08', '#a0700a', '#e8b020', '#2a2e36', '#4a5262', '#7a8496', '#2a6aff', '#30f0f0', '#30e050', '#8a0a0a', '#ff2020', '#ffd0e0', '#1a5a10', '#70ff30']

# Pal 7 BG2 backdrop (per region): sky + far city + cave wall + pipes
#  1 sky darkest 2 sky dark 3 sky mid 4 horizon 5 far bldg 6 near bldg 7 win yellow
#  8 win cyan 9 moon 10 cave darkest 11 cave dark 12 cave mid 13 pipe dk 14 pipe mid 15 lamp
BACK = {
    'city':    ['#000000', '#06061a', '#0e0e2e', '#1e1446', '#4a2058', '#121226', '#1a1a34', '#d8b84a', '#3ab0d0', '#e8e8d0', '#0a0806', '#16120c', '#221c14', '#141820', '#262c38', '#d8a040'],
    'cave':    ['#000000', '#06061a', '#0e0e2e', '#1e1446', '#4a2058', '#121226', '#1a1a34', '#d8b84a', '#3ab0d0', '#e8e8d0', '#0a0806', '#16120c', '#221c14', '#141820', '#262c38', '#d8a040'],
    'cool':    ['#000000', '#06061a', '#0e0e2e', '#1e1446', '#4a2058', '#121226', '#1a1a34', '#d8b84a', '#3ab0d0', '#e8e8d0', '#06080c', '#0e1218', '#161c26', '#141820', '#262c38', '#60c0ff'],
    'hot':     ['#000000', '#06061a', '#0e0e2e', '#1e1446', '#4a2058', '#121226', '#1a1a34', '#d8b84a', '#3ab0d0', '#e8e8d0', '#0c0404', '#1a0806', '#2a0e08', '#201010', '#3a1a14', '#ff6020'],
    'green':   ['#000000', '#06061a', '#0e0e2e', '#1e1446', '#4a2058', '#121226', '#1a1a34', '#d8b84a', '#3ab0d0', '#e8e8d0', '#040806', '#08100a', '#0e1a10', '#101a14', '#1e2e22', '#80ff40'],
    'purple':  ['#000000', '#06061a', '#0e0e2e', '#1e1446', '#4a2058', '#121226', '#1a1a34', '#d8b84a', '#3ab0d0', '#e8e8d0', '#08040c', '#100a18', '#1a1026', '#16101e', '#2a2038', '#e060ff'],
    'facility':['#000000', '#06061a', '#0e0e2e', '#1e1446', '#4a2058', '#121226', '#1a1a34', '#d8b84a', '#3ab0d0', '#e8e8d0', '#06080a', '#0c1014', '#141a20', '#181e26', '#2a3440', '#40e0f0'],
}
