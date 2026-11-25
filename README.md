# WLED para ESP8266 (Wemos D1 R2) com GIFs, relógio e regras MQTT

Ajustes sobre o [WLED](https://github.com/wled/WLED) (17.0.0-devV5) para uma matriz de LEDs 16x16
em uma **Wemos D1 R2 (ESP8266, 4 MB)**:

- **Efeito Imagem/GIF no ESP8266**, que o WLED desliga por falta de RAM (decodificador LZW com tabelas reduzidas).
- **Firmware enxuto**: sem Adalight, Loxone, Alexa, Hue e infravermelho. O MQTT continua.
- **Usermod `mqtt_rules`**: regras MQTT guardadas num arquivo da placa (mostrar texto, tocar GIF, mudar preset/brilho, avisar eventos), com retorno ao que estava rodando e espera do texto terminar de rolar.
- **Três ferramentas web** para a placa (PixelForge → Other tools):
  - **Relógio LED**: hora, data, clima, sensor, GIFs e efeitos como telas, posição dos números por arrastar.
  - **Estúdio de GIFs**: várias imagens → GIF, sprite sheets, categorias.
  - **Regras MQTT**: editor das regras, com seletor de GIF por categoria e preview.

## Como montar

```powershell
git clone https://github.com/wled/WLED.git
cd WLED
git checkout 356d5e71c2107fac9475ff488c48d89ac2d382e9   # versão usada (patches/WLED_BASE_COMMIT.txt)
git apply ..\wled-esp8266-matrix\patches\0001-wled-esp8266-gif.patch
Copy-Item -Recurse ..\wled-esp8266-matrix\lowram_libs .
Copy-Item -Recurse ..\wled-esp8266-matrix\usermods\mqtt_rules usermods\
Copy-Item ..\wled-esp8266-matrix\platformio_override.ini .
npm ci; npm run build
pio run -e d1_r2_gif
```

O firmware sai em `build_output/release/`. Grave por USB (`pio run -e d1_r2_gif -t upload`) ou pela
placa em `http://IP-DA-PLACA/update`.

Ambientes úteis em `platformio_override.ini`: `d1_r2_gif` (final), `d1_r2_gif_debug` (log na serial),
`d1_r2_gif_log` (log dos GIFs em `/giflog`).

## Ferramentas

Cada pasta em `ferramentas/` tem o código (`*.src.htm`), um `build.py` que gera a página comprimida
e o `.htm.gz` pronto. Envie para a placa:

```powershell
curl.exe -F "data=@ferramentas/mqtt/mqttrules.htm.gz;filename=mqttrules.htm.gz" http://IP-DA-PLACA/upload
```

Depois registre cada uma em `pftools.json` na placa (campos `id`, `name`, `file`, `desc`) para que apareça
em "Other tools" do PixelForge. As páginas também abrem direto em `http://IP-DA-PLACA/mqttrules.htm`.

## Limites conhecidos

- GIFs de até 318 pixels por quadro (16x16 e 32x8 funcionam); acima disso o decodificador não cabe na RAM.
- Com o MQTT ligado, a memória livre fica em torno de 12 a 17 KB.
- O ESP8266 não faz TLS e resolve nomes mal: use o **IP** do broker e do servidor de hora.
- Brokers públicos são abertos a qualquer pessoa. Use tópico único e desligue o MQTT quando terminar.

Parte do código foi escrita com ajuda de IA (marcado nos fontes). Veja `usermods/mqtt_rules/readme.md`
para o formato das regras.
