# configurar.ps1 - aplica o ambiente de trabalho do Claude Code neste PC (Windows).
#   1) Regras de trabalho no CLAUDE.md do usuário (num bloco marcado; o resto do arquivo fica intacto)
#   2) Antigravity: configurações do Claude Code (mescladas, sem apagar as da pessoa) e extensões padrão
# Pode rodar de novo quando quiser: o bloco de regras é substituído, não duplicado.
# Tudo que for alterado ganha uma cópia de segurança "<arquivo>.antes-ambiente-<data>".
#
#   .\configurar.ps1                        -> regras + configurações/extensões do Antigravity
#   .\configurar.ps1 -InstalarAntigravity   -> também instala o Antigravity pelo winget, se faltar
#   .\configurar.ps1 -SoRegras | -SoAntigravity

param([switch]$InstalarAntigravity, [switch]$SoRegras, [switch]$SoAntigravity)

$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$data = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pendencias = New-Object System.Collections.Generic.List[string]
function Passo([string]$m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Copia([string]$arq) {
    if (Test-Path -LiteralPath $arq) { Copy-Item -LiteralPath $arq -Destination "$arq.antes-ambiente-$data" -Force; Write-Host "cópia de segurança: $arq.antes-ambiente-$data" }
}

# ---------- 1) Regras de trabalho ----------
if (-not $SoAntigravity) {
    Passo 'Regras de trabalho do Claude'
    # Dentro do Claude Code, CLAUDE_CONFIG_DIR aponta para a conta em uso; sem ela, é ~/.claude
    $cfgDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    $arq = Join-Path $cfgDir 'CLAUDE.md'
    $ini = '<!-- >>> ambiente-antigravity >>> -->'; $fim = '<!-- <<< ambiente-antigravity <<< -->'
    $regras = [IO.File]::ReadAllText((Join-Path $aqui 'regras-de-trabalho.md'), [Text.Encoding]::UTF8).Trim()
    $bloco = "$ini`n$regras`n$fim"
    $atual = if (Test-Path -LiteralPath $arq) { [IO.File]::ReadAllText($arq, [Text.Encoding]::UTF8) } else { '' }
    $i = $atual.IndexOf($ini); $f = $atual.IndexOf($fim)
    if ($i -ge 0 -and $f -gt $i) {
        $novo = $atual.Substring(0, $i) + $bloco + $atual.Substring($f + $fim.Length)
    } elseif ($atual.Trim()) {
        $novo = $atual.TrimEnd() + "`n`n" + $bloco + "`n"
    } else {
        $novo = $bloco + "`n"
    }
    if ($novo -ne $atual) { Copia $arq; [IO.File]::WriteAllText($arq, $novo, $utf8); Write-Host "OK: regras em $arq" }
    else { Write-Host "OK: regras já estavam atualizadas em $arq" }
}

# ---------- 2) Antigravity ----------
if (-not $SoRegras) {
    Passo 'Antigravity'
    $cli = Join-Path $env:LOCALAPPDATA 'Programs\Antigravity IDE\bin\antigravity-ide.cmd'
    if (-not (Test-Path $cli) -and $InstalarAntigravity) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'winget não encontrado. Instale o Antigravity pelo site https://antigravity.google e rode de novo.' }
        Write-Host 'Instalando o Antigravity (winget)...'
        & winget install --id Google.AntigravityIDE -e --silent --accept-package-agreements --accept-source-agreements
    }
    if (-not (Test-Path $cli)) {
        $pendencias.Add('Antigravity não está instalado. Rode de novo com -InstalarAntigravity (ou instale por https://antigravity.google).')
    } else {
        # Configurações: só as chaves deste pacote são gravadas; as da pessoa ficam
        $user = Join-Path $env:APPDATA 'Antigravity IDE\User'
        New-Item -ItemType Directory -Force -Path $user | Out-Null
        $sArq = Join-Path $user 'settings.json'
        $nossas = [IO.File]::ReadAllText((Join-Path $aqui 'antigravity\settings.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
        $dela = $null
        if (Test-Path -LiteralPath $sArq) {
            $txt = [IO.File]::ReadAllText($sArq, [Text.Encoding]::UTF8)
            if ($txt.Trim()) { try { $dela = $txt | ConvertFrom-Json } catch { $dela = 'invalido' } }
        }
        if ($dela -eq 'invalido') {
            $pendencias.Add("O settings.json do Antigravity tem comentários ou vírgulas sobrando, então não mexi nele. Junte à mão as chaves de: $(Join-Path $aqui 'antigravity\settings.json')")
        } else {
            if (-not $dela) { $dela = [pscustomobject]@{} }
            $mudou = $false
            foreach ($p in $nossas.PSObject.Properties) {
                $antes = if ($dela.PSObject.Properties[$p.Name]) { $dela.($p.Name) | ConvertTo-Json -Depth 20 -Compress } else { $null }
                if ($antes -ne ($p.Value | ConvertTo-Json -Depth 20 -Compress)) { $dela | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force; $mudou = $true }
            }
            if ($mudou) { Copia $sArq; [IO.File]::WriteAllText($sArq, ($dela | ConvertTo-Json -Depth 20), $utf8); Write-Host "OK: configurações em $sArq" }
            else { Write-Host 'OK: configurações já estavam aplicadas' }
        }

        # Extensões. O CLI do Antigravity escreve avisos no canal de erro mesmo quando dá certo,
        # e com 'Stop' o PowerShell 5.1 trataria isso como falha: aqui vale 'Continue'.
        function Ag { $ErrorActionPreference = 'Continue'; & $cli @args 2>$null }
        function Lista { @(Ag --list-extensions | Where-Object { $_ -match '^[\w-]+\.[\w-]+$' } | ForEach-Object { $_.Trim().ToLower() }) }
        $ja = Lista
        foreach ($e in (Get-Content (Join-Path $aqui 'antigravity\extensoes.txt') -Encoding UTF8)) {
            $e = $e.Trim(); if (-not $e) { continue }
            if ($ja -contains $e.ToLower()) { Write-Host "$e : já instalada"; continue }
            Ag --install-extension $e | Out-Null
            $ok = (Lista) -contains $e.ToLower()
            if ($ok) { Write-Host "$e : instalada" } else { $pendencias.Add("Extensão $e não instalou. Instale pela aba Extensões do Antigravity.") }
        }
        $pendencias.Add('No Antigravity: entre com a sua conta Google (se ainda não entrou).')
        $pendencias.Add('Abra o painel do Claude (ícone do Claude na barra lateral) e entre com a sua conta do Claude.')
        $pendencias.Add('Feche e abra o Antigravity para as configurações valerem.')
    }
}

Write-Host "`nPronto." -ForegroundColor Green
if ($pendencias.Count) {
    Write-Host 'PENDENTE (passos seus):' -ForegroundColor Yellow
    $pendencias | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}
