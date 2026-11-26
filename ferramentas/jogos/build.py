# Gera jogos.htm.gz a partir de jogos.src.htm
import gzip, pathlib
here = pathlib.Path(__file__).parent
src = (here / 'jogos.src.htm').read_text(encoding='utf-8')
(here / 'jogos.htm').write_text(src, encoding='utf-8')
(here / 'jogos.htm.gz').write_bytes(gzip.compress(src.encode('utf-8'), 9))
print('jogos.htm', len(src.encode()), 'bytes; gz', (here / 'jogos.htm.gz').stat().st_size)
