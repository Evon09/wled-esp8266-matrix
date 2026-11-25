# Gera pixelstudio.htm e pixelstudio.htm.gz a partir de pixelstudio.src.htm
import gzip, pathlib
here = pathlib.Path(__file__).parent
src = (here / 'pixelstudio.src.htm').read_text(encoding='utf-8')
(here / 'pixelstudio.htm').write_text(src, encoding='utf-8')
(here / 'pixelstudio.htm.gz').write_bytes(gzip.compress(src.encode('utf-8'), 9))
print('pixelstudio.htm', len(src.encode()), 'bytes; gz', (here / 'pixelstudio.htm.gz').stat().st_size)
