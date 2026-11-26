# Gera relogio.htm a partir de relogio.src.htm embutindo as fontes .wbf do firmware (base64).
import base64, pathlib
FONT_DIR = pathlib.Path(r'C:\Users\Jair\Documents\WELED\WLED\wled00\src\font')
FILES = ['font_tom-thumb_6px.wbf', 'font_TinyUnicode_8px.wbf', 'console_font_6x8.wbf', 'c64esque_9px.wbf', 'font_5x12.wbf']
fonts = [base64.b64encode((FONT_DIR / f).read_bytes()).decode() for f in FILES]
here = pathlib.Path(__file__).parent
src = (here / 'relogio.src.htm').read_text(encoding='utf-8')
assert src.count('/*WX*/') == 1
out = src.replace('/*FONTS*/[]', '[' + ','.join('"%s"' % f for f in fonts) + ']')
out = out.replace('/*WX*/', (here / 'clima_gif.js').read_text(encoding='utf-8'))  # desenhos animados do tempo
(here / 'relogio.htm').write_text(out, encoding='utf-8')
import gzip
(here / 'relogio.htm.gz').write_bytes(gzip.compress(out.encode('utf-8'), 9))
print('relogio.htm', len(out.encode()), 'bytes; gz', (here / 'relogio.htm.gz').stat().st_size)
