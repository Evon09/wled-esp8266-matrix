# Instalador do WLED para matriz LED no ESP8266 (Windows PowerShell 5.1 ou mais novo).
# Abra pelo INSTALAR.bat (duplo clique). Parametros opcionais, para uso sem perguntas:
#   -Acao firmware|ferramentas|tudo|compilar   -Porta COM3   -Ip 192.168.0.50
#   -Simular  mostra o que faria, sem gravar nada na placa    -Sim  responde "sim" as confirmacoes
param(
  [ValidateSet('menu', 'firmware', 'ferramentas', 'tudo', 'compilar')][string]$Acao = 'menu',
  [string]$Porta = '',
  [string]$Ip = '',
  [switch]$Simular,
  [switch]$Sim,
  [string]$Origem = 'https://github.com/wled/WLED.git',
  [string]$PastaWLED = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$Raiz = Split-Path -Parent $PSScriptRoot
$Firmware = Join-Path $Raiz 'firmware\WLED_D1R2_GIF.bin'
$Base = '356d5e71c2107fac9475ff488c48d89ac2d382e9'
$EsptoolUrl = 'https://github.com/espressif/esptool/releases/download/v4.8.1/esptool-v4.8.1-win64.zip'
if (-not $PastaWLED) { $PastaWLED = Join-Path (Split-Path -Parent $Raiz) 'wled-build' }

$Ferramentas = @(
  @{ id = 'relogio'; name = 'Relógio LED'; file = 'relogio.htm'; pasta = 'relogio'; desc = 'Transforma a matriz em relógio: hora, data, clima, sensor, GIFs e efeitos.' },
  @{ id = 'gifstudio'; name = 'Estúdio de GIFs'; file = 'gifstudio.htm'; pasta = 'gifstudio'; desc = 'Cria GIFs a partir de várias imagens e organiza em categorias.' },
  @{ id = 'mqttrules'; name = 'Regras MQTT'; file = 'mqttrules.htm'; pasta = 'mqtt'; desc = 'Faz a matriz reagir a mensagens MQTT e avisar o que acontece.' },
  @{ id = 'pixelstudio'; name = 'Pixel Estúdio'; file = 'pixelstudio.htm'; pasta = 'pixelstudio'; desc = 'Editor de pixel art completo: quadros, sprites, GIF e espelho de tela e webcam.' },
  @{ id = 'jogos'; name = 'Jogos na Matriz'; file = 'jogos.htm'; pasta = 'jogos'; desc = '10 jogos para PC e celular: Tetris, Pong, Cobrinha, Plataforma e mais.' }
)

function Titulo($t) { Write-Host ''; Write-Host "== $t ==" -ForegroundColor Yellow }
function Ok($t) { Write-Host "  [ok] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "  [!]  $t" -ForegroundColor DarkYellow }
function Info($t) { Write-Host "  $t" }
function Falha($t) { throw $t }
function Perguntar($texto, $padrao) {
  if ($Sim -or [Console]::IsInputRedirected) { return $padrao }
  $r = Read-Host "  $texto"
  if ([string]::IsNullOrWhiteSpace($r)) { return $padrao }
  return $r.Trim()
}
# confirmacao: so segue com "s"; sem teclado, so segue com -Sim
function Confirmar($texto) {
  if ($Sim) { return $true }
  if ([Console]::IsInputRedirected) { return $false }
  return ((Read-Host "  $texto (s/N)").Trim().ToLower() -eq 's')
}

# ---------- esptool ----------
function Find-Esptool {
  $local = Get-ChildItem -Path (Join-Path $PSScriptRoot 'esptool') -Filter 'esptool.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($local) { return @{ exe = $local.FullName; args = @() } }
  $pioPy = Join-Path $env:USERPROFILE '.platformio\penv\Scripts\python.exe'
  $pioTool = Join-Path $env:USERPROFILE '.platformio\packages\tool-esptoolpy\esptool.py'
  if ((Test-Path $pioPy) -and (Test-Path $pioTool)) { return @{ exe = $pioPy; args = @($pioTool) } }
  if ((Test-Path $pioTool) -and (Get-Command python -ErrorAction SilentlyContinue)) {
    $serve = & python -c "import importlib.util as u; print(1 if u.find_spec('serial') else 0)"
    if ($serve -eq '1') { return @{ exe = 'python'; args = @($pioTool) } }
  }
  if (Get-Command python -ErrorAction SilentlyContinue) {
    $tem = & python -c "import importlib.util as u; print(1 if u.find_spec('esptool') else 0)"
    if ($tem -eq '1') { return @{ exe = 'python'; args = @('-m', 'esptool') } }
  }
  return $null
}
function Get-Esptool {
  $t = Find-Esptool
  if ($t) { return $t }
  Info 'Para gravar pela USB falta o esptool, o gravador oficial da Espressif (fabricante do chip).'
  Info "Origem: $EsptoolUrl (cerca de 34 MB)"
  if ($Simular) { Aviso 'Simulação: o download seria feito aqui.'; return @{ exe = 'esptool.exe'; args = @() } }
  if (-not (Confirmar 'Baixar agora?')) { Falha 'Sem o esptool não dá para gravar.' }
  $destino = Join-Path $PSScriptRoot 'esptool'
  New-Item -ItemType Directory -Force $destino | Out-Null
  $zip = Join-Path $destino 'esptool.zip'
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest -Uri $EsptoolUrl -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $destino -Force
  Remove-Item $zip
  $t = Find-Esptool
  if (-not $t) { Falha 'O download terminou, mas não achei o esptool.exe.' }
  Ok 'esptool pronto.'
  return $t
}
function Invoke-Esptool($t, [string[]]$parametros) {
  $todos = @($t.args) + $parametros
  if ($Simular) { Info ("simulação> {0} {1}" -f $t.exe, ($todos -join ' ')); return '' }
  $saida = & $t.exe @todos | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray; $_ }
  if ($LASTEXITCODE -ne 0) { Falha "O esptool terminou com erro ($LASTEXITCODE). Confira o cabo, a porta e os drivers." }
  return ($saida -join "`n")
}

# ---------- porta USB ----------
function Get-Portas {
  @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\((COM\d+)\)' -and $_.Name -notmatch 'Bluetooth' } |
    ForEach-Object { [pscustomobject]@{ porta = [regex]::Match($_.Name, '\((COM\d+)\)').Groups[1].Value; nome = $_.Name } })
}
function Select-Porta {
  if ($Porta) { return $Porta }
  while ($true) {
    $p = @(Get-Portas)
    if ($p.Count -eq 0) {
      Aviso 'Nenhuma porta serial encontrada. Ligue a placa com um cabo USB de DADOS.'
      Aviso 'Se ela continuar sem aparecer, instale o driver do chip USB da placa (CH340 ou CP210x).'
      if (-not (Confirmar 'Procurar de novo?')) { Falha 'Placa não encontrada.' }
      continue
    }
    for ($i = 0; $i -lt $p.Count; $i++) { Info ("{0}) {1}" -f ($i + 1), $p[$i].nome) }
    $n = Perguntar 'Qual é a sua placa? (número)' $(if ($p.Count -eq 1) { '1' } else { '' })
    if ($n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $p.Count) { return $p[[int]$n - 1].porta }
    if ($Sim -or [Console]::IsInputRedirected) { Falha 'Informe a porta com -Porta COMx.' }
  }
}

# ---------- endereco da placa ----------
function Read-Ip($texto, [switch]$opcional) {
  $v = $Ip
  while ($true) {
    if (-not $v) { $v = Perguntar $texto '' }
    if (-not $v -and $opcional) { return '' }
    if ($v -match '^\d{1,3}(\.\d{1,3}){3}$') { return $v }
    if ($Sim -or [Console]::IsInputRedirected) { Falha 'Informe o endereço da placa com -Ip 192.168.x.y' }
    Aviso 'Digite o endereço no formato 192.168.0.50'
    $v = ''
  }
}
# durante a tela de um GIF a placa recusa pedidos por alguns segundos: insiste antes de desistir
function Get-Info($ip) {
  for ($t = 1; $t -le 8; $t++) { try { return Invoke-RestMethod -Uri "http://$ip/json/info" -TimeoutSec 8 } catch { Start-Sleep -Seconds 2 } }
  return $null
}
# baixa um arquivo da placa; repete se a placa recusar ou o arquivo vier cortado. Devolve o codigo HTTP
function Get-DaPlaca($ip, $nome, $destino) {
  $codigo = '000'
  for ($t = 1; $t -le 4; $t++) {
    Wait-SemGif $ip
    if (Test-Path $destino) { Remove-Item $destino }
    $codigo = & curl.exe -s -m 30 -o $destino -w '%{http_code}' "http://$ip/$nome"
    if ($codigo -eq '404') { return '404' }
    if ($LASTEXITCODE -eq 0 -and $codigo -eq '200') {
      try { Get-Content -Path $destino -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null; return '200' } catch {}
    }
    Start-Sleep -Seconds 3
  }
  if (Test-Path $destino) { Remove-Item $destino }
  return "falhou ($codigo)"
}
function Save-Copia($ip) {
  $pasta = Join-Path $PSScriptRoot ('backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  New-Item -ItemType Directory -Force $pasta | Out-Null
  foreach ($n in 'presets.json', 'cfg.json', 'pftools.json') {
    $c = Get-DaPlaca $ip $n (Join-Path $pasta $n)
    if ($c -eq '200') { Ok "cópia de $n" } elseif ($c -ne '404') { Aviso "não consegui copiar $n" }
  }
  Info "Cópias em: $pasta"
}

# ---------- 1) firmware ----------
function Install-Firmware($arquivo) {
  Titulo 'Gravar o firmware pela USB'
  if (-not (Test-Path $arquivo)) { Falha "Não achei o firmware: $arquivo" }
  Info 'Serve para placas ESP8266 com 4 MB (Wemos D1 R2, D1 mini, NodeMCU). Não serve para ESP32.'
  $copia = Read-Ip 'Se a placa já tem WLED na rede, digite o IP para guardar uma cópia dos ajustes (ou Enter)' -opcional
  if ($copia -and -not $Simular) { if (Get-Info $copia) { Save-Copia $copia } else { Aviso 'Não alcancei a placa por esse IP; sigo sem cópia.' } }
  $t = Get-Esptool
  $porta = Select-Porta
  $chip = Invoke-Esptool $t @('--chip', 'esp8266', '--port', $porta, 'flash_id')
  if (-not $Simular -and $chip -match 'Detected flash size:\s*(\d+)MB' -and [int]$Matches[1] -lt 4) { Falha "Esta placa tem só $($Matches[1]) MB de flash; este firmware precisa de 4 MB." }
  Write-Host ''
  Info 'Placa nova, ou com outro programa: vale apagar tudo antes. Apagar remove Wi-Fi, presets e arquivos da placa.'
  $apagar = $false
  if (-not $Sim -and -not [Console]::IsInputRedirected) { $apagar = Confirmar 'Apagar TUDO antes de gravar?' }
  if (-not $Simular -and -not (Confirmar "Gravar o firmware na porta $porta?")) { Aviso 'Cancelado, nada foi gravado.'; return $false }
  if ($apagar) { Invoke-Esptool $t @('--chip', 'esp8266', '--port', $porta, 'erase_flash') | Out-Null }
  Invoke-Esptool $t @('--chip', 'esp8266', '--port', $porta, '--baud', '460800', 'write_flash', '--flash_size', 'detect', '0x0', $arquivo) | Out-Null
  if ($Simular) { Ok 'Simulação concluída: nada foi gravado.' } else { Ok 'Firmware gravado.' }
  Titulo 'Agora configure a placa'
  Info '1. No celular ou PC, conecte no Wi-Fi "WLED-AP" (senha padrão: wled1234).'
  Info '2. Abra http://4.3.2.1 > Config > WiFi Setup e informe a rede da sua casa.'
  Info '3. Config > LED Preferences: pino de dados, 256 LEDs, ordem das cores e limite de corrente da sua fonte.'
  Info '4. Config > 2D Configuration: matriz 16x16, conforme a ligação dos painéis.'
  Info '(Se a placa já estava configurada e você não apagou, os ajustes continuam.)'
  return $true
}

# ---------- 2) ferramentas ----------
# com um GIF tocando a placa quase não tem memória livre: espera a tela passar antes de enviar
function Wait-SemGif($ip) {
  for ($i = 0; $i -lt 45; $i++) {
    try { $s = Invoke-RestMethod -Uri "http://$ip/json/state" -TimeoutSec 8; if (-not @($s.seg | Where-Object { $_.fx -eq 53 -and $_.stop -gt 0 }).Count) { return } } catch {}
    Start-Sleep -Seconds 1
  }
  Aviso 'A placa continua tocando um GIF; escolha uma cor sólida se o envio falhar.'
}
function Send-Arquivo($ip, $caminho, $nome) {
  $conf = Join-Path $env:TEMP "wled_conf_$nome"
  for ($t = 1; $t -le 4; $t++) {
    Wait-SemGif $ip
    & curl.exe -s -f -m 90 -H 'Expect:' -F "data=@$caminho;filename=$nome" "http://$ip/upload" | Out-Null
    $enviou = $LASTEXITCODE -eq 0
    Start-Sleep -Seconds 2
    if (Test-Path $conf) { Remove-Item $conf }
    & curl.exe -s -f -m 60 -o $conf "http://$ip/$nome"
    if ($enviou -and (Test-Path $conf) -and (Get-FileHash $conf).Hash -eq (Get-FileHash $caminho).Hash) { Remove-Item $conf; return $true }
    Aviso "$nome não conferiu (tentativa $t); tentando de novo..."
    Start-Sleep -Seconds 4
  }
  return $false
}
function Register-Ferramentas($ip) {
  $atual = Join-Path $env:TEMP 'wled_pftools_atual.json'
  $codigo = Get-DaPlaca $ip 'pftools.json' $atual
  $lista = @()
  if ($codigo -eq '200') {
    $lido = Get-Content -Path $atual -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($item in $lido) { $lista += $item }
  }
  elseif ($codigo -ne '404') { Aviso "Não li a lista do PixelForge ($codigo); não vou alterá-la."; return }
  $ids = $Ferramentas | ForEach-Object { $_.id }
  $lista = @($lista | Where-Object { $ids -notcontains $_.id })
  foreach ($f in $Ferramentas) { $lista += [pscustomobject][ordered]@{ id = $f.id; name = $f.name; file = $f.file; author = 'local'; desc = $f.desc; ver = '1.0' } }
  $novo = Join-Path $env:TEMP 'wled_pftools_novo.json'
  [IO.File]::WriteAllText($novo, (ConvertTo-Json -InputObject $lista -Depth 6 -Compress), (New-Object Text.UTF8Encoding($false)))
  if (Send-Arquivo $ip $novo 'pftools.json') { Ok "lista do PixelForge atualizada ($($lista.Count) itens)" } else { Aviso 'Não consegui atualizar a lista do PixelForge (as ferramentas funcionam mesmo assim).' }
}
function Install-Ferramentas {
  Titulo 'Enviar as ferramentas pela rede'
  $placa = Read-Ip 'Endereço (IP) da placa na sua rede, ex.: 192.168.0.50'
  $info = Get-Info $placa
  if (-not $info) { Falha "A placa não respondeu em http://$placa. Confira se ela está ligada e na mesma rede." }
  Ok "placa encontrada: $($info.name), WLED $($info.ver), $($info.leds.count) LEDs"
  if (-not $info.leds.matrix) { Aviso 'A matriz 2D ainda não está configurada (Config > 2D Configuration). As ferramentas precisam dela.' }
  if (-not $info.gmr) { Aviso 'Este firmware não tem o repasse dos jogos (game_relay): grave o firmware deste projeto (opção 1).' }
  Info 'Dica: feche as abas abertas na placa e deixe-a em uma cor sólida durante o envio.'
  if ($Simular) { foreach ($f in $Ferramentas) { Info "simulação> enviaria $($f.file).gz" }; Ok 'Simulação concluída.'; return }
  Save-Copia $placa
  $falhas = 0
  foreach ($f in $Ferramentas) {
    $gz = Join-Path $Raiz "ferramentas\$($f.pasta)\$($f.file).gz"
    if (Send-Arquivo $placa $gz "$($f.file).gz") { Ok "$($f.name) enviada e conferida" } else { $falhas++; Aviso "$($f.name) não foi enviada" }
  }
  Register-Ferramentas $placa
  if ($falhas) { Falha "$falhas ferramenta(s) não foram enviadas. Rode esta opção de novo." }
  Ok "Pronto! Abra http://$placa no navegador: os botões Clock, GIFs, Pixel Art, MQTT e Games estão na tela principal."
}

# ---------- 4) compilar ----------
function Invoke-Passo($descricao, [scriptblock]$comando) {
  Info "> $descricao"
  & $comando
  if ($LASTEXITCODE -ne 0) { Falha "Falhou: $descricao" }
}
function Build-Firmware {
  Titulo 'Compilar o firmware a partir do código'
  foreach ($c in 'git', 'npm') { if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Falha "Falta instalar: $c (Git: git-scm.com, Node.js: nodejs.org)" } }
  $pio = $null
  if (Get-Command pio -ErrorAction SilentlyContinue) { $pio = @('pio') }
  elseif (Get-Command python -ErrorAction SilentlyContinue) {
    $tem = & python -c "import importlib.util as u; print(1 if u.find_spec('platformio') else 0)"
    if ($tem -eq '1') { $pio = @('python', '-m', 'platformio') }
  }
  if (-not $pio) { Falha 'Falta o PlatformIO. Instale com:  python -m pip install platformio' }
  Info "Pasta de trabalho: $PastaWLED"
  if (-not (Test-Path (Join-Path $PastaWLED '.git'))) { Invoke-Passo 'baixar o código do WLED' { git clone $Origem $PastaWLED } }
  Push-Location $PastaWLED
  try {
    Invoke-Passo 'ir para a versão base' { git -c advice.detachedHead=false checkout $Base }
    $patch = Join-Path $Raiz 'patches\0001-wled-esp8266-gif.patch'
    cmd /c "git apply --check `"$patch`" >nul 2>nul"
    if ($LASTEXITCODE -eq 0) { Invoke-Passo 'aplicar as modificações' { git apply $patch } }
    else {
      cmd /c "git apply --reverse --check `"$patch`" >nul 2>nul"
      if ($LASTEXITCODE -ne 0) { Falha 'A pasta tem outras alterações e o patch não se aplica. Apague a pasta de trabalho e rode de novo.' }
      Ok 'modificações já aplicadas'
    }
    Copy-Item -Recurse -Force (Join-Path $Raiz 'lowram_libs') .
    Copy-Item -Recurse -Force (Join-Path $Raiz 'usermods\*') 'usermods'
    Copy-Item -Force (Join-Path $Raiz 'platformio_override.ini') .
    Ok 'bibliotecas, módulos e configuração copiados'
    if (-not (Test-Path 'node_modules')) { Invoke-Passo 'instalar dependências do painel (npm ci)' { npm ci } }
    Invoke-Passo 'montar o painel web' { npm run build }
    $exe = $pio[0]; $pre = @($pio | Select-Object -Skip 1)
    Invoke-Passo 'compilar (pode demorar na primeira vez)' { & $exe @pre run -e d1_r2_gif }
    $bin = Get-ChildItem 'build_output\release\*D1R2_GIF.bin' | Select-Object -First 1
    if (-not $bin) { Falha 'A compilação terminou, mas não achei o arquivo .bin.' }
    Ok "firmware compilado: $($bin.FullName) ($($bin.Length) bytes)"
    return $bin.FullName
  }
  finally { Pop-Location }
}

# ---------- principal ----------
function Run-Acao($a) {
  switch ($a) {
    'firmware' { Install-Firmware $Firmware | Out-Null }
    'ferramentas' { Install-Ferramentas }
    'tudo' {
      if (Install-Firmware $Firmware) {
        if (-not $Simular) { Perguntar 'Quando a placa estiver configurada e na sua rede, aperte Enter' '' | Out-Null }
        Install-Ferramentas
      }
    }
    'compilar' {
      $saida = @(Build-Firmware)
      $bin = $saida[$saida.Count - 1]
      if (-not $Sim -and (Confirmar 'Gravar agora na placa, pela USB, o firmware compilado?')) { Install-Firmware $bin | Out-Null }
    }
  }
}

Write-Host ''
Write-Host '  WLED na matriz LED (ESP8266) - instalador' -ForegroundColor Cyan
if ($Simular) { Aviso 'MODO SIMULAÇÃO: nada será gravado na placa.' }
if ($Acao -ne 'menu') {
  try { Run-Acao $Acao; exit 0 } catch { Write-Host "  [erro] $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
}
while ($true) {
  Write-Host ''
  Write-Host '  1) Instalação completa (firmware pela USB + ferramentas pela rede)'
  Write-Host '  2) Só gravar o firmware pela USB'
  Write-Host '  3) Só enviar/atualizar as ferramentas pela rede'
  Write-Host '  4) Avançado: compilar o firmware a partir do código'
  Write-Host '  0) Sair'
  $o = Read-Host '  Escolha'
  $a = @{ '1' = 'tudo'; '2' = 'firmware'; '3' = 'ferramentas'; '4' = 'compilar' }[$o]
  if ($o -eq '0') { break }
  if (-not $a) { continue }
  try { Run-Acao $a } catch { Write-Host "  [erro] $($_.Exception.Message)" -ForegroundColor Red }
}
