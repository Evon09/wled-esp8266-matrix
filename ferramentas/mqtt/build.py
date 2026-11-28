import gzip, pathlib
here = pathlib.Path(__file__).parent
src = (here / 'mqttrules.src.htm').read_text(encoding='utf-8')
icons = (here / 'icones.js').read_text(encoding='utf-8')  # gerado por icones.py
assert src.count('/*ICONS*/') == 1
src = src.replace('/*ICONS*/', icons.strip())
(here / 'mqttrules.htm').write_text(src, encoding='utf-8')
(here / 'mqttrules.htm.gz').write_bytes(gzip.compress(src.encode('utf-8'), 9))
print('mqttrules.htm', len(src.encode()), 'bytes; gz', (here / 'mqttrules.htm.gz').stat().st_size)
