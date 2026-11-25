# WLED no ESP8266 (Wemos D1 R2): GIFs, relógio e regras MQTT

🇬🇧 [Read in English](README.md)

Conjunto de mudanças sobre o [WLED](https://github.com/wled/WLED) (17.0.0-devV5, commit `356d5e7`) para uma
**matriz de LEDs 16x16 controlada por uma Wemos D1 R2 (ESP8266, 4 MB de flash, cerca de 80 KB de RAM)**.

O WLED desliga o efeito Imagem/GIF no ESP8266 porque o decodificador de GIF precisa de uns 24 KB de RAM.
Este projeto faz o efeito funcionar, enxuga o firmware para abrir espaço e acrescenta três ferramentas web
e um motor de regras MQTT, tudo rodando na própria placa.

> Tudo foi feito e testado em uma placa real. É um projeto pessoal, não uma versão oficial do WLED.
> Parte do código foi escrita com ajuda de IA (marcada com `AI:` nos fontes).

## Índice

- [O que você ganha](#o-que-você-ganha)
- [O que foi alterado e por quê](#o-que-foi-alterado-e-por-quê)
- [As ferramentas web](#as-ferramentas-web)
- [Usermod de regras MQTT](#usermod-de-regras-mqtt)
- [Compilar e instalar](#compilar-e-instalar)
- [Prints](#prints)
- [Limitações](#limitações)
- [Segurança](#segurança)
- [O que não foi feito](#o-que-não-foi-feito)
- [Estrutura do repositório](#estrutura-do-repositório)

## O que você ganha

| Recurso | Onde |
|---|---|
| Efeito Imagem/GIF no ESP8266 | firmware (`image_loader.cpp`, `lowram_libs/`) |
| Firmware enxuto (MQTT mantido; Alexa, Hue, infravermelho, Adalight e Loxone removidos) | `platformio_override.ini` |
| Relógio, data, clima, sensor, GIFs e efeitos como telas | ferramenta **Relógio LED** |
| Várias imagens em um GIF, sprite sheets, categorias | ferramenta **Estúdio de GIFs** |
| Regras: mensagem MQTT → ação na matriz, mudança de estado → mensagem MQTT | usermod `mqtt_rules` + ferramenta **Regras MQTT** |

Tamanho do firmware na D1 R2: flash 86,1 % (899.715 de 1.044.464 bytes), RAM 59,3 % na compilação e
cerca de 12 a 19 KB de heap livre em funcionamento.

## O que foi alterado e por quê

### 1. Configuração de compilação: `platformio_override.ini`

| Opção | Por quê |
|---|---|
| `-D WLED_ENABLE_GIF` | liga o efeito Imagem (fx 53) |
| `-D GIF_LOW_RAM`, `-D GIF_CODE_LIMIT=576` | escolhe o decodificador reduzido (veja o item 2) |
| `-D WLED_DISABLE_ALEXA`, `HUESYNC`, `INFRARED`, `ADALIGHT`, `LOXONE` | recursos que não uso; gastam flash e RAM. O **MQTT continua ligado** de propósito |
| `-D WLED_DISABLE_PARTICLESYSTEM2D` | economiza flash; efeitos de partículas não fazem falta em 16x16 |
| `custom_usermods = mqtt_rules` | inclui o motor de regras |
| `lib_extra_dirs = lowram_libs` | usa as bibliotecas modificadas no lugar das do registro |
| ambientes `d1_r2_gif_debug`, `_netdebug`, `_log` | log pela serial, log por UDP e `/giflog`, para diagnosticar a matriz quando o USB não pode ficar ligado |

### 2. Decodificador de GIF reduzido: `lowram_libs/AnimatedGIF`

**Por quê:** a AnimatedGIF original mantém um dicionário LZW de 4096 entradas mais uma pilha de pixels,
cerca de 24 KB em um único bloco. O ESP8266 tem uns 17 a 19 KB de heap quando está parado, então a
alocação sempre falhava e a matriz ficava preta.

**O que mudou:**
- O dicionário agora tem `GIF_CODE_LIMIT` entradas (padrão **576**, cerca de 7,3 KB). Um quadro de N pixels
  precisa de no máximo N + 258 códigos, então 576 permite quadros de até **318 pixels** (16x16 e 32x8 cabem).
  Com `1024` cabem 766 pixels (32x16), usando uns 9 KB.
- Foram adicionadas verificações de limites para que um quadro grande demais falhe de forma limpa em vez de
  estourar a memória.
- `lowram_libs/GifDecoder` é uma cópia cujo `library.properties` tem `architectures=*`; o original declara só
  AVR e ESP32 e o PlatformIO o recusava no ESP8266.

### 3. Mudanças no firmware: `wled00/`

| Arquivo | Mudança | Por quê |
|---|---|---|
| `image_loader.cpp` | Verifica o maior bloco livre do heap **antes** de alocar o decodificador | no ESP8266 não há exceções C++: um `new` que falha derrubaria e reiniciaria a placa |
| `image_loader.cpp` | Se a memória estiver curta, esquece o nome e tenta de novo a cada 500 ms, por até uns 10 s (depois reporta `ERR_NORAM_PX`) | o painel web usa RAM temporariamente; a imagem deve começar sozinha quando houver memória |
| `image_loader.cpp` | Libera o decodificador anterior antes de carregar a próxima imagem | senão, trocar de uma imagem para outra falhava até escolher outro efeito |
| `image_loader.cpp` | Recusa quadros maiores que `GIF_CODE_LIMIT - 258` pixels com erro claro | o dicionário reduzido não consegue decodificá-los |
| `image_loader.cpp` | Buffer circular opcional `GIF_LOG` | a matriz consome muita corrente e o USB cai; por isso o log é lido por HTTP |
| `wled_server.cpp` | `GET /giflog` (só com `-D GIF_LOG`) | serve esse log |
| `FX_fcn.cpp` | `Segment::setName` libera o decodificador antes de trocar o nome | o WLED recusa alocações abaixo de `MIN_HEAP_SIZE` (9 KB) no ESP8266; com o decodificador vivo, o nome da nova imagem era ignorado em silêncio |
| `fcn_declare.h` | declaração de `gifLogText()` | apoio ao item acima |
| `data/pixelforge/pixelforge.htm` | removida a trava "não disponível no ESP8266"; o pedido de reprodução envia `ix:0` | o bloqueio vinha do JavaScript da página; `ix` é o blur e precisa ser 0 no efeito Imagem nesta CPU |

### 4. Ajustes feitos na placa (não estão no código)

- **Ordem de cores GRB** no barramento de LEDs: no começo vermelho e verde estavam trocados.
- **Hora:** servidor NTP informado por **IP** (`200.160.0.8`), porque a placa não resolvia nomes; fuso *Brasília*.
- IDs de preset usados pela ferramenta de relógio: 201 a 205 (telas), 210 (ciclo), 211 a 213 (sensor),
  221 a 239 (telas extras de GIF/efeito).

## As ferramentas web

São arquivos HTML únicos guardados na placa (gzip) e listados no PixelForge em *Other tools* pelo
`pftools.json`. Cada uma lê e escreve na placa pela API JSON normal do WLED, então não precisam de firmware
extra (exceto o `mqtt_rules` para a ferramenta de regras).

### Relógio LED (`ferramentas/relogio`)
Transforma a matriz em relógio.
- Editor de layout: posição de horas e minutos; dá para **arrastar os números com o mouse** para posicioná-los.
- 12 h ou 24 h, formatos de data (alguns, como `24/11`, foram acrescentados porque não cabiam), fontes e tamanhos.
- Tela de clima e tela de sensor (GPIO), transições entre telas.
- **GIFs e efeitos padrão do WLED como telas extras** (um ou mais, opcional).
- Pré-visualização ao vivo com a **hora da placa**, não a do PC.
- Cria os presets e a playlist e guarda backup do que substitui.

### Estúdio de GIFs (`ferramentas/gifstudio`)
- Envie várias imagens e receba um GIF; sprite sheets são cortadas em quadros.
- Ordem e tempo dos quadros, ajuste para o tamanho da matriz.
- **Categorias:** agrupe GIFs por projeto e arraste um GIF para uma categoria. Ficam em `gifstudio.json`.

### Regras MQTT (`ferramentas/mqtt`)
Editor do arquivo de regras usado pelo usermod. Abas: Conexão, Mensagem → ação, Evento → mensagem, Testar.
- Ações: mostrar texto, tocar GIF, mostrar efeito do WLED, aplicar preset, mudar brilho, ligar/desligar, comando JSON.
- **Seletor de GIF com filtro por categoria e preview** (usa as categorias do Estúdio de GIFs).
- **Depois da ação:** voltar ao que estava rodando (relógio, GIF, efeito); no texto, **esperar terminar de rolar**;
  ou voltar a um preset fixo depois de N segundos.
- Resposta MQTT opcional, aba *Testar* que simula uma mensagem sem broker e log dos últimos acionamentos.
- **Regras por hora e clima** (aba *Por hora e clima*): disparam em um horário, a cada N minutos (com janela de horário
  opcional) ou quando a temperatura/umidade mudar, nos dias da semana que você marcar. Condição opcional (por exemplo, só
  se a temperatura passar de 28), ação opcional na matriz e mensagem MQTT opcional, que pode incluir `{hm}`, `{dw}`, `{t}`, `{h}`.
- Fontes de temperatura/umidade: um tópico onde um sensor publica, ou o clima da cidade escolhida na ferramenta de relógio.
- Atalhos para brokers públicos com aviso e botão que gera um tópico único.

## Usermod de regras MQTT

`usermods/mqtt_rules` guarda as regras em `/mqttrules.jsonl` (um objeto JSON por linha, até 760 caracteres,
até 10 tópicos assinados). As regras são lidas da flash quando preciso, então quase não usam RAM.
O formato das regras, os marcadores (`%dev%`, `{p}`, `{n}`), as opções `b` (voltar ao anterior) e `w`
(esperar o texto) e a API JSON estão em [usermods/mqtt_rules/readme.md](usermods/mqtt_rules/readme.md).

Como funciona o "voltar ao anterior": antes da primeira ação temporária o usermod guarda a playlist ou o
preset em execução e, quando a ação termina, aplica de novo. O "esperar o texto" acompanha a posição de
rolagem do efeito Scrolling Text e termina quando ela volta a zero, com limite de segurança de 3 minutos.

Verificado na placa: um texto longo voltou depois de rolar inteiro (cerca de 18 s, e não os 3 s do
temporizador), um texto que cabe voltou no tempo configurado e a playlist do relógio foi restaurada todas as vezes.

## Compilar e instalar

```powershell
git clone https://github.com/wled/WLED.git
cd WLED
git checkout 356d5e71c2107fac9475ff488c48d89ac2d382e9
git apply ..\wled-esp8266-matrix\patches\0001-wled-esp8266-gif.patch
Copy-Item -Recurse ..\wled-esp8266-matrix\lowram_libs .
Copy-Item -Recurse ..\wled-esp8266-matrix\usermods\mqtt_rules usermods\
Copy-Item ..\wled-esp8266-matrix\platformio_override.ini .
npm ci; npm run build
pio run -e d1_r2_gif
```

O `.bin` sai em `build_output/release/`. Grave com `pio run -e d1_r2_gif -t upload` (USB) ou abra
`http://IP-DA-PLACA/update` (OTA).

Instale as ferramentas (arquivos gzip) e registre-as:

```powershell
curl.exe -F "data=@ferramentas/relogio/relogio.htm.gz;filename=relogio.htm.gz"   http://IP-DA-PLACA/upload
curl.exe -F "data=@ferramentas/gifstudio/gifstudio.htm.gz;filename=gifstudio.htm.gz" http://IP-DA-PLACA/upload
curl.exe -F "data=@ferramentas/mqtt/mqttrules.htm.gz;filename=mqttrules.htm.gz"   http://IP-DA-PLACA/upload
```

Depois acrescente uma entrada por ferramenta (`id`, `name`, `file`, `desc`) no `pftools.json` da placa para
que apareça no PixelForge. As páginas também abrem direto em `http://IP-DA-PLACA/relogio.htm`, `/gifstudio.htm`
e `/mqttrules.htm`. Para mudar uma ferramenta, edite o `*.src.htm` e rode o `build.py` dela.

Dicas aprendidas na prática:
- OTA: feche as outras abas do navegador que apontam para a placa e use `curl -H "Expect:"`.
- O USB pode cair com a matriz ligada (consumo de corrente); alimente a matriz separadamente ou use OTA.
- Use o ambiente `d1_r2_gif_log` e leia `http://IP-DA-PLACA/giflog` para ver o que o carregador de GIF está fazendo.

## Prints

Ferramenta de regras com o seletor de GIF (filtro por categoria, miniaturas e preview grande):

![Regras MQTT, seletor de GIF](docs/img/mqtt-rules-gif-picker.jpg)

Outros prints (editor do relógio, Estúdio de GIFs, menu do PixelForge) podem ser colocados em `docs/img/`.

## Limitações

**GIF**
- Quadros de até **318 pixels** no build padrão (16x16, 32x8). GIFs maiores mostram erro. Subir `GIF_CODE_LIMIT`
  para 1024 permite 766 pixels (32x16), usando uns 2 KB a mais de RAM.
- O efeito Imagem precisa de `ix` (blur) em 0.
- A troca de imagem pode esperar até uns 10 s se o heap estiver curto (por exemplo com muitas páginas abertas).

**Memória**
- O heap livre fica em torno de 12 a 19 KB. O WLED recusa alocações abaixo de 9 KB; mantenha poucas abas
  abertas na placa e evite presets muito grandes ou muitos segmentos.
- Com o MQTT ligado, GIFs grandes podem não tocar enquanto o painel web está ocupado.
- A flash está em 86 %. Para abrir espaço é preciso remover recursos, não acrescentar.

**Rede**
- Sem TLS no ESP8266 neste build, então não há brokers `mqtts://` (HiveMQ Cloud e a maioria dos serviços hospedados).
- A placa não resolve nomes de forma confiável. Use **IPs** para o broker MQTT e para o servidor NTP.
- Brokers públicos exigem um tópico que ninguém mais use.

**Regras MQTT**
- 10 tópicos, 4 mensagens na fila, 760 caracteres por regra, texto de até 40 caracteres.
- As regras leem o arquivo a cada mensagem, então taxas muito altas de mensagens não são o objetivo.
- Regras de evento cobrem só mudança de preset, energia e brilho.
- "Esperar o texto" vale para o efeito Scrolling Text no segmento 0.
- A placa não tem sensor de temperatura/umidade. Os valores vêm de um tópico MQTT ou do clima da ferramenta de relógio, que
  só é enviado enquanto a página do relógio estiver aberta (e se perde ao reiniciar). Se as duas fontes forem usadas, vale a última a escrever.
- As regras de hora só funcionam depois que a placa tem a hora (NTP) e usam o fuso configurado nela. Confira se o fuso está
  certo: um fuso errado desloca todas as regras.
- As regras disparadas por valor guardam o estado "armado" só para as 32 primeiras regras; o log mostra os últimos 6 eventos.

**Ferramentas**
- Feitas para uma matriz 16x16 de um segmento. Outros tamanhos funcionam em princípio, mas não foram testados.
- O PixelForge pode reescrever o `pftools.json` e apagar as três entradas personalizadas; acrescente-as de novo se acontecer.
- As ferramentas não definem o preset de boot, então o relógio não inicia sozinho depois de reiniciar até que
  você defina um preset de boot nas configurações do WLED.

## Segurança

- Um broker MQTT público permite que qualquer pessoa que descubra seu tópico mande texto para a matriz. Use o
  tópico único gerado, faça testes curtos e desligue o MQTT depois. Para uso de verdade, rode seu próprio broker
  (Mosquitto, Home Assistant) na rede local e configure usuário e senha.
- Nunca publique senhas ou tokens digitados em tutoriais ou prints; troque-os se vazarem.
- O arquivo de regras pode executar qualquer comando JSON do WLED. Só deixe clientes de confiança publicarem nos tópicos assinados.

## O que não foi feito

- Redesenho para enviar quadros brutos (empurrar pixels direto).
- TLS no MQTT e correção da resolução de nomes (DNS).
- Iniciar o relógio automaticamente ao ligar.

## Estrutura do repositório

```
patches/                 diff contra o WLED (commit em WLED_BASE_COMMIT.txt)
lowram_libs/             AnimatedGIF (tabelas reduzidas) e GifDecoder (todas as arquiteturas)
usermods/mqtt_rules/     motor de regras + readme
ferramentas/             ferramentas relogio, gifstudio, mqtt (fonte, script de build, gzip)
platformio_override.ini  ambientes de compilação para a D1 R2
docs/img/                prints
```

O WLED usa licença MIT; a AnimatedGIF usa Apache-2.0. Confira a licença de cada projeto de origem antes de reutilizar o código.
