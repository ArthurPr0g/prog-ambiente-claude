# instalar-simuladores.ps1 - instala os simuladores de celular para testar sites (Windows 10/11, 64 bits).
#   Android: emulador oficial do Google + Android 15 com Chrome (aparelho "Galaxy_S26", 360 x 780 no site)
#   iPhone:  WebKit (o motor do Safari) dentro de uma moldura de iPhone 15 (393 x 659 no site)
#   Atalhos no Menu Iniciar, pasta "Simuladores de celular"
#
#   .\instalar-simuladores.ps1                      -> os dois simuladores
#   .\instalar-simuladores.ps1 -SoIphone            -> só o iPhone (~150 MB, poucos minutos)
#   .\instalar-simuladores.ps1 -SoAndroid           -> só o Android (~2,1 GB de download)
#   .\instalar-simuladores.ps1 -InstalarFaltantes   -> instala pelo winget o Node.js, se faltar (precisa para o iPhone)
#
# Pode rodar de novo quando quiser: o que já existe é pulado (inclusive um Android SDK do Android Studio),
# e uma instalação interrompida no meio é refeita. Downloads direto do Google, com checksum conferido.
param([switch]$SoIphone, [switch]$SoAndroid, [switch]$InstalarFaltantes, [string]$Pasta = (Join-Path $env:LOCALAPPDATA 'simuladores-celular'))

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}   # acentos legíveis para quem lê a saída
$origem = Split-Path -Parent $MyInvocation.MyCommand.Path
$pendencias = New-Object System.Collections.Generic.List[string]
function Passo([string]$m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function AtualizarPath { $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User') }
function LivreGB([string]$caminho) { [math]::Floor((Get-PSDrive -Name ([IO.Path]::GetPathRoot($caminho).Substring(0, 1))).Free / 1GB) }
function Winget([string]$id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    & winget install --id $id -e --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Null
    AtualizarPath; return $true
}
$fazAndroid = -not $SoIphone; $fazIphone = -not $SoAndroid
$emuExe = Join-Path $(if (($env:LOCALAPPDATA + $env:USERPROFILE) -notmatch '[^\x20-\x7E]') { Join-Path $env:LOCALAPPDATA 'Android' } else { 'C:\Android' }) 'Sdk\emulator\emulator.exe'

# ---------- 0) Conferências ----------
Passo 'Conferindo o PC'
if (-not [Environment]::Is64BitOperatingSystem) { throw 'Os simuladores precisam do Windows de 64 bits.' }
if ($fazAndroid -and $env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
    $pendencias.Add('Este PC tem processador ARM (ex.: Snapdragon): o emulador Android deste pacote é para Intel/AMD e foi pulado. O iPhone funciona.')
    $fazAndroid = $false
}
if ($fazAndroid -and (LivreGB $env:LOCALAPPDATA) -lt 12) {
    $pendencias.Add("O Android precisa de uns 12 GB livres no disco $([IO.Path]::GetPathRoot($env:LOCALAPPDATA)) (há $(LivreGB $env:LOCALAPPDATA) GB). Libere espaço e rode de novo.")
    $fazAndroid = $false
}
if ($fazAndroid -and -not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { throw 'curl.exe não encontrado (vem com o Windows 10 de 2018 em diante). Atualize o Windows e rode de novo.' }

# Copia as ferramentas para uma pasta fixa: os atalhos não quebram quando o plugin for atualizado
New-Item -ItemType Directory -Force -Path $Pasta | Out-Null
& robocopy $origem $Pasta /E /XD node_modules /XF instalar-simuladores.ps1 /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Não consegui copiar as ferramentas para $Pasta." }
Copy-Item -LiteralPath $MyInvocation.MyCommand.Path -Destination $Pasta -Force
Write-Host "Ferramentas em: $Pasta"

# ---------- 1) Android ----------
if ($fazAndroid) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    # Mesmo lugar do Android Studio (reaproveita o que já existe). O emulador não funciona com acento no caminho
    # (ex.: C:\Users\João): nesse caso tudo vai para C:\Android. O abrir-celular.ps1 usa a mesma regra.
    $semAcento = ($env:LOCALAPPDATA + $env:USERPROFILE) -notmatch '[^\x20-\x7E]'
    $raizAndroid = if ($semAcento) { Join-Path $env:LOCALAPPDATA 'Android' } else { 'C:\Android' }
    $sdk = Join-Path $raizAndroid 'Sdk'
    $baixar = Join-Path $raizAndroid '_downloads'
    $avdHome = if ($semAcento) { Join-Path $env:USERPROFILE '.android\avd' } else { 'C:\Android\avd' }
    New-Item -ItemType Directory -Force -Path $sdk, $baixar, $avdHome | Out-Null

    # Extrai numa pasta temporária e só depois move: se cair no meio, a próxima rodada refaz sem erro
    function Extrair([string]$zip, [string]$destino) {
        $tmp = Join-Path $baixar ('x-' + [IO.Path]::GetFileNameWithoutExtension($zip))
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $tmp)
        New-Item -ItemType Directory -Force -Path $destino | Out-Null
        Get-ChildItem -LiteralPath $tmp | ForEach-Object {
            $alvo = Join-Path $destino $_.Name
            if (Test-Path -LiteralPath $alvo) { Remove-Item -LiteralPath $alvo -Recurse -Force }
            Move-Item -LiteralPath $_.FullName -Destination $alvo
        }
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
    $pacotes = @(
        @{ nome = 'platform-tools (adb)'; url = 'https://dl.google.com/android/repository/platform-tools_r37.0.1-win.zip'; sha1 = 'e03e78b1d80b396f1c3358e31251cb31740e1110'; destino = $sdk; existe = 'platform-tools\adb.exe' },
        @{ nome = 'emulador'; url = 'https://dl.google.com/android/repository/emulator-windows_x64-16428233.zip'; sha1 = '488ed747e82de7e9bb5247becd1ac043c7e5e85d'; destino = $sdk; existe = 'emulator\emulator.exe' },
        @{ nome = 'Android 15 com Chrome e Play Store'; url = 'https://dl.google.com/android/repository/sys-img/google_apis_playstore/x86_64-35_r09.zip'; sha1 = '2f0054868e6aab3c098acd3decba17a82aed4176'; destino = (Join-Path $sdk 'system-images\android-35\google_apis_playstore'); existe = 'system-images\android-35\google_apis_playstore\x86_64\system.img' }
    )
    $falhou = $false
    foreach ($p in $pacotes) {
        if (Test-Path (Join-Path $sdk $p.existe)) { Write-Host "$($p.nome): já instalado"; continue }
        Passo "Baixando $($p.nome)"
        $zip = Join-Path $baixar ([IO.Path]::GetFileName($p.url))
        $ok = $false
        foreach ($tentativa in 1, 2) {
            if (-not (Test-Path $zip)) { & curl.exe -L --fail --retry 3 -C - -o $zip $p.url }
            if ((Test-Path $zip) -and (Get-FileHash $zip -Algorithm SHA1).Hash.ToLower() -eq $p.sha1) { $ok = $true; break }
            Remove-Item $zip -Force -ErrorAction SilentlyContinue   # baixou corrompido: tenta mais uma vez do zero
        }
        if (-not $ok) { $pendencias.Add("Não consegui baixar $($p.nome) (internet, proxy ou antivírus bloqueando dl.google.com?). Rode de novo."); $falhou = $true; break }
        Extrair $zip $p.destino
        Remove-Item $zip -Force   # libera ~1 GB
    }

    if (-not $falhou) {
        Passo 'Aceleração do processador (necessária para o Android ficar rápido)'
        $ErrorActionPreference = 'Continue'   # o emulator-check pode escrever no canal de erro justo quando falta a aceleração
        $acel = & (Join-Path $sdk 'emulator\emulator-check.exe') accel 2>&1 | Out-String
        $ErrorActionPreference = 'Stop'
        if ($acel -match 'usable') { Write-Host 'OK' } else {
            $pendencias.Add('Ligue a aceleração: abra "Ativar ou desativar recursos do Windows", marque "Plataforma do Hipervisor do Windows", OK e reinicie o PC. Se não aparecer, a virtualização (Intel VT-x / AMD-V) precisa ser ligada na BIOS.')
            Start-Process optionalfeatures.exe
        }

        Passo 'Aparelho virtual Galaxy_S26'
        $skin = Join-Path $sdk 'skins\Galaxy_S26'
        $temSkin = Test-Path (Join-Path $skin 'layout')
        if (-not $temSkin) {
            # Moldura oficial da Samsung (opcional): exige conta Samsung, então a pessoa baixa e deixa em Downloads
            $zipSkin = Get-ChildItem (Join-Path $env:USERPROFILE 'Downloads') -Filter 'Galaxy_S26*.zip' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($zipSkin) {
                $tmp = Join-Path $baixar 'skin-s26'
                if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
                [IO.Compression.ZipFile]::ExtractToDirectory($zipSkin.FullName, $tmp)
                $dentro = Get-ChildItem $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'layout') } | Select-Object -First 1
                if ($dentro) {
                    New-Item -ItemType Directory -Force -Path (Join-Path $sdk 'skins') | Out-Null
                    Move-Item -LiteralPath $dentro.FullName -Destination $skin
                    $temSkin = $true
                    # Recorte só do aparelho (tira o cartão azul da Samsung). Opcional: se o Python faltar ou falhar, fica a moldura original.
                    # Só roda se o Python já tiver Pillow, numpy e scipy: nada é instalado no Python da pessoa.
                    $ErrorActionPreference = 'Continue'
                    $temPy = $false
                    if (Get-Command python -ErrorAction SilentlyContinue) { & python -c "import PIL, numpy, scipy" 2>$null | Out-Null; $temPy = ($LASTEXITCODE -eq 0) }
                    $ErrorActionPreference = 'Stop'
                    if (-not $temPy) { Write-Host 'Moldura Samsung instalada como veio (o recorte opcional precisa do Python com Pillow, numpy e scipy).' }
                    if ($temPy) {
                        $ErrorActionPreference = 'Continue'
                        & python -I (Join-Path $Pasta 'celular-android\so-aparelho.py') $skin 2>$null
                        if ($LASTEXITCODE -ne 0 -and (Test-Path (Join-Path $skin '_original\layout'))) {
                            Copy-Item (Join-Path $skin '_original\*') $skin -Force
                            Write-Host 'Recorte da moldura não deu certo; ficou a moldura original (funciona igual).'
                        }
                        $ErrorActionPreference = 'Stop'
                    }
                }
                Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                Write-Host 'Sem moldura Samsung (opcional): o celular abre sem o desenho do aparelho. Para ter a moldura, baixe "Galaxy S26" em developer.samsung.com/galaxy-emulator-skin (pede conta Samsung), deixe o .zip em Downloads e rode de novo.'
            }
        }
        $avd = Join-Path $avdHome 'Galaxy_S26.avd'
        New-Item -ItemType Directory -Force -Path $avd | Out-Null
        $enc = New-Object System.Text.UTF8Encoding($false)
        [IO.File]::WriteAllText((Join-Path $avdHome 'Galaxy_S26.ini'), "avd.ini.encoding=UTF-8`npath=$avd`npath.rel=avd\Galaxy_S26.avd`ntarget=android-35`n", $enc)
        $cfg = @"
AvdId=Galaxy_S26
avd.ini.displayname=Galaxy S26 (Android 15)
abi.type=x86_64
hw.cpu.arch=x86_64
hw.cpu.ncore=4
hw.ramSize=4096
vm.heapSize=512
disk.dataPartition.size=6G
image.sysdir.1=system-images\android-35\google_apis_playstore\x86_64\
tag.id=google_apis_playstore
tag.display=Google Play
PlayStore.enabled=true
hw.device.name=galaxy_s26
hw.device.manufacturer=Samsung
hw.lcd.width=1080
hw.lcd.height=2340
hw.lcd.density=480
hw.keyboard=yes
hw.mainKeys=no
hw.gpu.enabled=yes
hw.gpu.mode=auto
fastboot.forceColdBoot=no
hw.audioInput=no
hw.camera.back=none
hw.camera.front=none
"@
        if ($temSkin) { $cfg += "`nskin.name=Galaxy_S26`nskin.path=$skin`nskin.dynamic=no`nshowDeviceFrame=yes" } else { $cfg += "`nshowDeviceFrame=no" }
        $cfgArq = Join-Path $avd 'config.ini'
        if (-not (Test-Path $cfgArq) -or $temSkin) { [IO.File]::WriteAllText($cfgArq, ($cfg -replace "`r`n", "`n") + "`n", $enc) }
        Write-Host 'OK'
    }
}

# ---------- 2) iPhone ----------
if ($fazIphone) {
    Passo 'iPhone (Node.js + Playwright + WebKit)'
    $node = Get-Command node -ErrorAction SilentlyContinue
    $versao = if ($node) { [int]((& node --version) -replace '^v(\d+).*', '$1') } else { 0 }
    if ($versao -lt 18 -and $InstalarFaltantes) {
        Write-Host 'Instalando o Node.js LTS (winget)...'
        [void](Winget 'OpenJS.NodeJS.LTS')
        # Confere de verdade (a pessoa pode ter recusado a permissão do Windows)
        $versao = if (Get-Command node -ErrorAction SilentlyContinue) { [int]((& node --version) -replace '^v(\d+).*', '$1') } else { 0 }
    }
    if ($versao -lt 18 -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
        $pendencias.Add('O iPhone precisa do Node.js 18 ou mais novo (com o npm). Instale (winget install OpenJS.NodeJS.LTS ou nodejs.org), abra um PowerShell novo e rode este script de novo.')
    } else {
        Push-Location (Join-Path $Pasta 'celular-ios')
        try {
            $ErrorActionPreference = 'Continue'
            & npm install --no-fund --no-audit --loglevel=error
            if ($LASTEXITCODE -ne 0) { $pendencias.Add('O "npm install" do iPhone falhou (internet ou proxy?). Rode de novo.') }
            else {
                & npx --no-install playwright install webkit
                if ($LASTEXITCODE -ne 0) { $pendencias.Add('O download do WebKit falhou (internet ou proxy?). Rode de novo.') } else { Write-Host 'OK' }
            }
        } finally { Pop-Location; $ErrorActionPreference = 'Stop' }
    }
}

# ---------- 3) Atalhos ----------
Passo 'Atalhos no Menu Iniciar'
$menu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Simuladores de celular'
New-Item -ItemType Directory -Force -Path $menu | Out-Null
$ps = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$sh = New-Object -ComObject WScript.Shell
if (Test-Path $emuExe) {
    $a = $sh.CreateShortcut((Join-Path $menu 'Android - Galaxy S26.lnk'))
    $a.TargetPath = $ps
    $a.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Pasta\celular-android\abrir-celular.ps1`""
    $a.WorkingDirectory = "$Pasta\celular-android"; $a.Description = 'Abre o celular Android (Chrome) para testar sites'; $a.WindowStyle = 7; $a.Save()
}
if (Test-Path (Join-Path $Pasta 'celular-ios\node_modules\playwright')) {
    $i = $sh.CreateShortcut((Join-Path $menu 'iPhone 15 - Safari.lnk'))
    $i.TargetPath = $ps
    $i.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command `"Set-Location -LiteralPath '$Pasta\celular-ios'; node abrir-iphone.mjs`""
    $i.WorkingDirectory = "$Pasta\celular-ios"; $i.Description = 'Abre o iPhone simulado (WebKit, motor do Safari) para testar sites'; $i.WindowStyle = 7; $i.Save()
}
Write-Host 'OK'

Write-Host "`nPronto. Menu Iniciar > Simuladores de celular." -ForegroundColor Green
if ($pendencias.Count) {
    Write-Host 'PENDENTE (passos seus):' -ForegroundColor Yellow
    $pendencias | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}
