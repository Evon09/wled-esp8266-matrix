# Gera gifstudio.htm.gz a partir de gifstudio.src.htm
import gzip, pathlib
here = pathlib.Path(__file__).parent
src = (here / 'gifstudio.src.htm').read_text(encoding='utf-8')
(here / 'gifstudio.htm').write_text(src, encoding='utf-8')
(here / 'gifstudio.htm.gz').write_bytes(gzip.compress(src.encode('utf-8'), 9))
print('gifstudio.htm', len(src.encode()), 'bytes; gz', (here / 'gifstudio.htm.gz').stat().st_size)
