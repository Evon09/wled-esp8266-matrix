"""Desenha os ícones animados 16x16 dos avisos do celular.

Grava dois arquivos a partir dos mesmos desenhos (só usa a biblioteca padrão):
  icones.js      GIFs em base64, para a amostra na ferramenta MQTT
  mqtt_icons.h   pixels na memória de programa, que o firmware (usermod mqtt_rules) desenha por cima da matriz
Depois de mudar um desenho: python icones.py && python build.py, e recompile o firmware.
"""
import base64, pathlib, struct

N = 16
COL = {'.': 0x000000, 'W': 0xffffff, 'G': 0x1fc257, 'R': 0xf0231c, 'Y': 0xffc400, 'B': 0x1e90ff, 'C': 0x29b6f6,
       'P': 0x7b2ff7, 'M': 0xd6249f, 'O': 0xfd8d32, 'L': 0xb8e2ff, 'D': 0xc98a00}


def art(text):
    rows = text.split()
    rows += ['.' * N] * (N - len(rows))
    assert len(rows) == N and all(len(r) == N for r in rows), text
    return [[COL[c] for c in r] for r in rows]


def put(img, pts, col):
    out = [r[:] for r in img]
    for x, y in pts:
        out[y][x] = COL[col]
    return out


def up(img):
    return img[1:] + [[0] * N]


def badge(img, col='R'):
    return put(img, [(13, 0), (14, 0), (12, 1), (13, 1), (14, 1), (15, 1), (12, 2), (13, 2), (14, 2), (15, 2), (13, 3), (14, 3)], col)


def bounce(img, col='R'):
    """ícone com a bolinha de aviso piscando e um pulinho"""
    return [(badge(img, col), 30), (badge(up(img), col), 18), (badge(img, col), 18), (img, 22)]


WHATSAPP = art('''
................
.....GGGGGG.....
...GGGGGGGGGG...
..GGWWGGGGGGGG..
.GGWWWGGGGGGGGG.
.GGWWWGGGGGGGGG.
GGGGWWGGGGGGGGGG
GGGGWGGGGGGGGGGG
GGGGWWGGGGGGGGGG
GGGGGWWGGGGGGGGG
.GGGGGWWGGWWGGG.
.GGGGGGWWWWWWGG.
..GGGGGGWWWWGG..
.GGGGGGGGGGGGG..
.GG..GGGGGG.....
G...............
''')

GMAIL = art('''
................
................
................
RWWWWWWWWWWWWWWR
RRWWWWWWWWWWWWRR
RWRWWWWWWWWWWRWR
RWWRWWWWWWWWRWWR
RWWWRWWWWWWRWWWR
RWWWWRWWWWRWWWWR
RWWWWWRWWRWWWWWR
RWWWWWWRRWWWWWWR
RWWWWWWWWWWWWWWR
RWWWWWWWWWWWWWWR
RWWWWWWWWWWWWWWR
''')

YOUTUBE = art('''
................
................
................
.RRRRRRRRRRRRRR.
RRRRRRRRRRRRRRRR
RRRRRRWRRRRRRRRR
RRRRRRWWWRRRRRRR
RRRRRRWWWWWRRRRR
RRRRRRWWWWWWRRRR
RRRRRRWWWWWRRRRR
RRRRRRWWWRRRRRRR
RRRRRRWRRRRRRRRR
RRRRRRRRRRRRRRRR
.RRRRRRRRRRRRRR.
''')

TELEGRAM = art('''
................
.....CCCCCC.....
...CCCCCCCCCC...
..CCCCCCCCCCCC..
.CCCCCCCCCCWWCC.
.CCCCCCCCWWWWCC.
CCCCCCWWWWWWWCCC
CCCWWWWWWLWWWCCC
CCWWWWWWLWWWWCCC
CCCCCWWLWWWWCCCC
.CCCCCWWWWWWCCC.
.CCCCCWWCWWWCCC.
..CCCCWCCCWCCC..
...CCCCCCCCCC...
.....CCCCCC.....
''')

BUBBLE = art('''
................
................
..BBBBBBBBBBBB..
.BBBBBBBBBBBBBB.
.BBBBBBBBBBBBBB.
.BBBBBBBBBBBBBB.
.BBBBBBBBBBBBBB.
.BBBBBBBBBBBBBB.
.BBBBBBBBBBBBBB.
.BBBBBBBBBBBBBB.
..BBBBBBBBBBBB..
....BBBB........
....BBB.........
....BB..........
....B...........
''')

BELL = art('''
................
.......YY.......
.......YY.......
.....YYYYYY.....
....YYYYYYYY....
...YYYYYYYYYY...
...YYWYYYYYYY...
...YYWYYYYYYY...
...YWWYYYYYYY...
...YYYYYYYYYY...
..YYYYYYYYYYYY..
.DDDDDDDDDDDDDD.
................
......DDDD......
.......DD.......
''')


def instagram():
    img = [[0] * N for _ in range(N)]
    stops = [(0.0, (253, 215, 90)), (0.25, (253, 141, 50)), (0.55, (214, 36, 159)), (1.0, (80, 60, 230))]
    for y in range(N):
        for x in range(N):
            if (x in (0, 15) and y in (0, 1, 14, 15)) or (y in (0, 15) and x in (1, 14)):
                continue
            t = (x + (15 - y)) / 30
            for (a, ca), (b, cb) in zip(stops, stops[1:]):
                if a <= t <= b:
                    k = (t - a) / (b - a)
                    r, g, bl = (round(ca[i] + (cb[i] - ca[i]) * k) & 0xf0 for i in range(3))
                    img[y][x] = (r << 16) | (g << 8) | bl
    frame = [(x, 3) for x in range(5, 11)] + [(x, 12) for x in range(5, 11)] + [(3, y) for y in range(5, 11)] + [(12, y) for y in range(5, 11)]
    frame += [(4, 4), (11, 4), (4, 11), (11, 11)]
    lens = [(7, 5), (8, 5), (6, 6), (9, 6), (5, 7), (10, 7), (5, 8), (10, 8), (6, 9), (9, 9), (7, 10), (8, 10)]
    return put(img, frame + lens + [(10, 5)], 'W')


def sms_frames():
    dots = [[(x, 5), (x + 1, 5), (x, 6), (x + 1, 6)] for x in (3, 7, 11)]
    frames = [(put(BUBBLE, sum(dots[:k], []), 'W'), 22) for k in (1, 2, 3)]
    return frames + [(frames[-1][0], 25)]


def bell_frames():
    def swing(dx):
        # o corpo balança para um lado e o badalo para o outro
        return [([0] * N + r + [0] * N)[N - (dx if y < 12 else -dx):2 * N - (dx if y < 12 else -dx)] for y, r in enumerate(BELL)]
    return [(badge(swing(0)), 15), (badge(swing(-1)), 15), (badge(swing(0)), 15), (swing(1), 15)]


ICONS = {
    'whatsapp': bounce(WHATSAPP),
    'instagram': bounce(instagram()),
    'gmail': bounce(GMAIL, 'Y'),
    'youtube': bounce(YOUTUBE, 'Y'),
    'telegram': bounce(TELEGRAM),
    'sms': sms_frames(),
    'outro': bell_frames(),
}


def gif(frames):
    """GIF animado em laço, com quadros inteiros. O LZW sai sem compressão (um 'clear' antes de o código crescer)."""
    colors = [0]
    for img, _ in frames:
        for row in img:
            for c in row:
                if c not in colors:
                    colors.append(c)
    bits = max(2, (len(colors) - 1).bit_length())
    assert bits <= 7, len(colors)
    out = bytearray(b'GIF89a' + struct.pack('<HHBBB', N, N, 0x80 | 0x70 | (bits - 1), 0, 0))
    for i in range(1 << bits):
        c = colors[i] if i < len(colors) else 0
        out += c.to_bytes(3, 'big')
    out += b'\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00'
    clear, end, width = 1 << bits, (1 << bits) + 1, bits + 1
    for img, delay in frames:
        out += struct.pack('<BBBBHBB', 0x21, 0xf9, 4, 0x04, delay, 0, 0)
        out += struct.pack('<BHHHHB', 0x2c, 0, 0, N, N, 0)
        acc = n = 0
        data = bytearray()
        codes, run = [clear], 0
        for row in img:
            for c in row:
                if run == (1 << bits) - 2:
                    codes.append(clear)
                    run = 0
                codes.append(colors.index(c))
                run += 1
        codes.append(end)
        for code in codes:
            acc |= code << n
            n += width
            while n >= 8:
                data.append(acc & 255)
                acc >>= 8
                n -= 8
        if n:
            data.append(acc & 255)
        out.append(bits)
        for i in range(0, len(data), 255):
            chunk = data[i:i + 255]
            out.append(len(chunk))
            out += chunk
        out.append(0)
    out.append(0x3b)
    return bytes(out)


def header():
    """mqtt_icons.h: por ícone uma paleta e um byte por pixel; quadros repetidos são guardados uma vez só"""
    out = ['// Generated by ferramentas/mqtt/icones.py. Do not edit by hand.', '// AI: below section was generated by an AI', '#pragma once', '',
           '#define MR_ICON_SIZE 16', '#define MR_ICON_STEPS 4', '',
           'struct MrIcon { char name[10]; const uint32_t* pal; const uint8_t* px; uint8_t frame[MR_ICON_STEPS]; uint8_t delay[MR_ICON_STEPS]; }; // delay in 1/100 s', '']
    table = []
    for name, frames in ICONS.items():
        assert len(frames) == 4 and len(name) < 10
        colors, unique, order = [0], [], []
        for img, _ in frames:
            flat = [c for row in img for c in row]
            for c in flat:
                if c not in colors:
                    colors.append(c)
            data = [colors.index(c) for c in flat]
            if data not in unique:
                unique.append(data)
            order.append(unique.index(data))
        assert len(colors) <= 256
        out.append('static const uint32_t mrPal_%s[] PROGMEM = {%s};' % (name, ','.join('0x%06X' % c for c in colors)))
        out.append('static const uint8_t mrPx_%s[] PROGMEM = {' % name)
        for data in unique:
            out += ['  ' + ','.join(str(v) for v in data[i:i + 32]) + ',' for i in range(0, len(data), 32)]
        out += ['};', '']
        table.append('  {"%s", mrPal_%s, mrPx_%s, {%s}, {%s}},' % (name, name, name, ','.join(map(str, order)), ','.join(str(d) for _, d in frames)))
    out += ['static const MrIcon mrIcons[] PROGMEM = {'] + table + ['};', '// AI: end', '']
    return '\n'.join(out)


if __name__ == '__main__':
    here = pathlib.Path(__file__).parent
    items = []
    for name, frames in ICONS.items():
        data = gif(frames)
        items.append("%s:'%s'" % (name, base64.b64encode(data).decode()))
        print(name, len(data), 'bytes')
    # pasta do usermod: dentro do repositório ou, na máquina de desenvolvimento, na árvore do WLED ao lado
    targets = [d for d in (here / '../../usermods/mqtt_rules', here / '../../WLED/usermods/mqtt_rules') if d.is_dir()]
    assert targets, 'pasta usermods/mqtt_rules não encontrada'
    for d in targets:
        (d / 'mqtt_icons.h').write_text(header(), encoding='utf-8', newline='\n')
        print('mqtt_icons.h ->', d.resolve())
    (here / 'icones.js').write_text('/* gerado por icones.py: não edite à mão */\nconst ICONES={\n' + ',\n'.join(items) + '};\n', encoding='utf-8', newline='\n')
