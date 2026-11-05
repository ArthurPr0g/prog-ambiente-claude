# configurar.ps1 - aplica o ambiente de trabalho do Claude Code neste PC (Windows 10/11). No Mac/Linux: configurar.sh.
#   1) Regras de trabalho no CLAUDE.md (num bloco marcado; o resto do arquivo fica intacto)
#   2) Antigravity: configurações do Claude Code (somadas às da pessoa, sem apagar nada) e extensões padrão
#   3) Confere o login do Claude (a pasta padrão ~\.claude liga o microfone e o Chrome no painel)
# Pode rodar de novo quando quiser. Tudo que for alterado ganha uma cópia "<arquivo>.antes-ambiente-<data>".
#
#   .\configurar.ps1                        -> regras + configurações/extensões do Antigravity
#   .\configurar.ps1 -InstalarAntigravity   -> também instala o Antigravity pelo winget, se faltar
#   .\configurar.ps1 -SoRegras | -SoAntigravity
#
# Duas contas do Claude (ex.: pessoal + trabalho) no mesmo PC:
#   .\configurar.ps1 -Contas 2 -NomeConta2 "Trabalho" -PastaConta2 "C:\Projetos\Empresa|D:\Outra pasta"
#   - Conta 1 (principal) = pasta padrão ~\.claude. É também a que liga o microfone e o Chrome no painel.
#   - Conta 2 = pasta ~\.claude-<nome>. As pastas de -PastaConta2 (separadas por |) abrem num perfil próprio do
#     Antigravity que usa essa conta; as outras pastas continuam na conta 1.
#   - No terminal (cmd, PowerShell 5 e 7): comandos  claude-<nome>  e  claude-contas  (arquivos .cmd em ~\.local\bin).
#   Para voltar a 1 conta, rode com -Contas 1: nada da conta 2 é apagado, ela só deixa de ser configurada.

param(
    [switch]$InstalarAntigravity, [switch]$SoRegras, [switch]$SoAntigravity,
    [ValidateSet(1, 2)][int]$Contas = 1,
    [string]$NomeConta2 = 'Trabalho',
    [string[]]$PastaConta2 = @(),
    [string]$PastaComandos = '',      # onde gravar claude-<nome>.cmd (padrão: ~\.local\bin)
    [switch]$NaoAlterarPath,          # só para testes: não mexe no PATH do usuário
    [string]$DadosAntigravity = ''    # só para testes: pasta de dados isolada do Antigravity (--user-data-dir)
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}   # acentos legíveis para quem lê a saída
$aqui = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$data = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pendencias = New-Object System.Collections.Generic.List[string]
function Passo([string]$m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Copia([string]$arq) {
    if (Test-Path -LiteralPath $arq) { Copy-Item -LiteralPath $arq -Destination "$arq.antes-ambiente-$data" -Force; Write-Host "cópia de segurança: $arq.antes-ambiente-$data" }
}
if (-not $PastaComandos) { $PastaComandos = Join-Path $HOME '.local\bin' }
function Parar([string]$m) { Write-Host $m -ForegroundColor Red; exit 2 }   # erro de uso: mensagem limpa, sem "erro vermelho" técnico

# Contas: a 1 é sempre a pasta padrão; a 2 ganha uma pasta própria com o nome dela (sem acento/espaço)
if ($Contas -eq 2 -and $NomeConta2 -notmatch '^[\p{L}\p{N} _-]{1,40}$') { Parar "Nome da conta 2 inválido: ""$NomeConta2"". Use só letras, números, espaço, hífen ou sublinhado (até 40)." }
$slug2 = (($NomeConta2.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '').ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $slug2) { $slug2 = 'trabalho' }
$listaContas = @(@{ nome = 'principal'; pasta = (Join-Path $HOME '.claude'); comando = 'claude' })
if ($Contas -eq 2) {
    $listaContas += @{ nome = $NomeConta2; pasta = (Join-Path $HOME ".claude-$slug2"); comando = "claude-$slug2" }
    # Várias pastas: separadas por | (aspas e barra no fim são tiradas: com "powershell -File" elas atrapalham)
    $PastaConta2 = @($PastaConta2 | ForEach-Object { $_ -split '\|' } | ForEach-Object { $_.Trim().Trim('"').Trim() } | Where-Object { $_ } |
        ForEach-Object { if ($_ -match '^[A-Za-z]:\\?$') { $_.Substring(0, 2) + '\' } else { $_.TrimEnd('\') } })
    foreach ($p in $PastaConta2) { if (-not (Test-Path -LiteralPath $p -PathType Container)) { Parar "A pasta da conta 2 não existe: $p (confira o caminho; várias pastas vão separadas por |)" } }
    if (-not $PastaConta2.Count) { $pendencias.Add("Nenhuma pasta foi ligada à conta $NomeConta2. Rode de novo com -PastaConta2 ""C:\caminho\da\pasta"" para ela abrir nessa conta.") }
}

# ---------- 1) Regras de trabalho ----------
if (-not $SoAntigravity) {
    Passo 'Regras de trabalho do Claude'
    # Com 1 conta: a conta em uso (CLAUDE_CONFIG_DIR, se houver) ou ~\.claude. Com 2: as duas pastas.
    $destinos = if ($Contas -eq 2) { $listaContas | ForEach-Object { $_.pasta } } elseif ($env:CLAUDE_CONFIG_DIR) { @($env:CLAUDE_CONFIG_DIR) } else { @($listaContas[0].pasta) }
    $ini = '<!-- >>> ambiente-antigravity >>> -->'; $fim = '<!-- <<< ambiente-antigravity <<< -->'
    $regras = [IO.File]::ReadAllText((Join-Path $aqui 'regras-de-trabalho.md'), [Text.Encoding]::UTF8).Trim()
    $bloco = "$ini`n$regras`n$fim"
    foreach ($cfgDir in $destinos) {
        New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
        $arq = Join-Path $cfgDir 'CLAUDE.md'
        $atual = if (Test-Path -LiteralPath $arq) { [IO.File]::ReadAllText($arq, [Text.Encoding]::UTF8) } else { '' }
        $nIni = ([regex]::Matches($atual, [regex]::Escape($ini))).Count; $nFim = ([regex]::Matches($atual, [regex]::Escape($fim))).Count
        $i = $atual.IndexOf($ini); $f = $atual.IndexOf($fim)
        if ($nIni -eq 1 -and $nFim -eq 1 -and $f -gt $i) {
            $novo = $atual.Substring(0, $i) + $bloco + $atual.Substring($f + $fim.Length)
        } elseif ($nIni -eq 0 -and $nFim -eq 0) {
            $novo = if ($atual.Trim()) { $atual.TrimEnd() + "`n`n" + $bloco + "`n" } else { $bloco + "`n" }
        } else {
            # Marcadores faltando ou repetidos (bloco apagado pela metade?): não arrisca apagar regras da pessoa
            $pendencias.Add("Não mexi em $arq porque o bloco do ambiente-antigravity está incompleto ou repetido (marcadores $ini e $fim). Arrume à mão (deixe um início e um fim, ou apague os dois) e rode de novo.")
            continue
        }
        if ($novo -cne $atual) { Copia $arq; [IO.File]::WriteAllText($arq, $novo, $utf8); Write-Host "OK: regras em $arq" }
        else { Write-Host "OK: regras já estavam atualizadas em $arq" }
    }
}

# ---------- 2) Antigravity ----------
# Junta as nossas chaves ao settings.json da pessoa: listas são somadas, nada dela some, arquivo com comentários não é tocado.
# Com Node usa o mesclar-json.js (mesmo do Mac/Linux); sem Node, faz o mesmo aqui.
$mesclarJs = Join-Path $PSScriptRoot 'mesclar-json.js'
$nossasArq = Join-Path $aqui 'antigravity\settings.json'
function ParaJson($v, [int]$n = 0) {
    # JSON legível (o ConvertTo-Json do PowerShell 5.1 deixa recuos estranhos e troca ' < & por \u00xx)
    $esp = ' ' * (4 * ($n + 1)); $fecha = ' ' * (4 * $n)
    if ($null -eq $v) { return 'null' }
    if ($v -is [bool]) { return $(if ($v) { 'true' } else { 'false' }) }
    if ($v -is [string]) { return '"' + ($v -replace '\\', '\\' -replace '"', '\"' -replace "`r", '\r' -replace "`n", '\n' -replace "`t", '\t') + '"' }
    if ($v -is [ValueType]) { return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $v) }
    if ($v -is [System.Collections.IEnumerable] -and $v -isnot [System.Management.Automation.PSCustomObject]) {
        $itens = @($v | ForEach-Object { $esp + (ParaJson $_ ($n + 1)) })
        if (-not $itens.Count) { return '[]' }
        return "[`n" + ($itens -join ",`n") + "`n$fecha]"
    }
    $props = @($v.PSObject.Properties | ForEach-Object { $esp + (ParaJson $_.Name) + ': ' + (ParaJson $_.Value ($n + 1)) })
    if (-not $props.Count) { return '{}' }
    return "{`n" + ($props -join ",`n") + "`n$fecha}"
}
function MesclarPs([string]$sArq, [string]$configDir) {
    $nossas = [IO.File]::ReadAllText($nossasArq, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($configDir) { $nossas | Add-Member -NotePropertyName 'claudeCode.environmentVariables' -NotePropertyValue @([pscustomobject]@{ name = 'CLAUDE_CONFIG_DIR'; value = $configDir }) -Force }
    $dela = [pscustomobject]@{}
    if (Test-Path -LiteralPath $sArq) {
        $txt = [IO.File]::ReadAllText($sArq, [Text.Encoding]::UTF8).TrimStart([char]0xFEFF)
        if ($txt.Trim()) {
            if ($txt -match '(?m)^\s*//|/\*') { return 'invalido' }
            try { $dela = $txt | ConvertFrom-Json } catch { return 'invalido' }
            if ($dela -isnot [System.Management.Automation.PSCustomObject]) { return 'invalido' }
        }
    }
    $mudou = $false
    foreach ($p in $nossas.PSObject.Properties) {
        $novo = $p.Value
        $tem = $dela.PSObject.Properties[$p.Name]
        if ($tem -and $p.Name -eq 'claudeCode.environmentVariables') {
            $nomes = @($p.Value | ForEach-Object { $_.name })
            $novo = @(@($tem.Value) | Where-Object { $nomes -notcontains $_.name }) + @($p.Value)
        } elseif ($tem -and $tem.Value -is [array] -and $p.Value -is [array] -and -not (@($tem.Value) + @($p.Value) | Where-Object { $_ -is [System.Management.Automation.PSCustomObject] })) {
            $novo = @($tem.Value); foreach ($x in $p.Value) { if ($novo -cnotcontains $x) { $novo += $x } }
        }
        $antes = if ($tem) { $tem.Value | ConvertTo-Json -Depth 20 -Compress } else { $null }
        if ($antes -cne ($novo | ConvertTo-Json -Depth 20 -Compress)) { $dela | Add-Member -NotePropertyName $p.Name -NotePropertyValue $novo -Force; $mudou = $true }
    }
    if ($mudou) { New-Item -ItemType Directory -Force -Path (Split-Path $sArq) | Out-Null; [IO.File]::WriteAllText($sArq, (ParaJson $dela) + "`n", $utf8) }
    if ($mudou) { 'mudou' } else { 'igual' }
}
function Mesclar([string]$sArq, [string]$configDir = '') {
    $bk = "$sArq.antes-ambiente-$data"
    if (Test-Path -LiteralPath $sArq) { Copy-Item -LiteralPath $sArq -Destination $bk -Force }
    $node = Get-Command node -ErrorAction SilentlyContinue
    $r = if ($node) { $ErrorActionPreference = 'Continue'; "$(& node $mesclarJs mesclar $sArq $nossasArq $configDir 2>$null)".Trim() } else { MesclarPs $sArq $configDir }
    if ($r -eq 'mudou' -and (Test-Path -LiteralPath $bk)) { Write-Host "cópia de segurança: $bk" } else { Remove-Item -LiteralPath $bk -Force -ErrorAction SilentlyContinue }
    switch ($r) {
        'mudou' { Write-Host "OK: configurações em $sArq" }
        'igual' { Write-Host "OK: configurações já estavam aplicadas em $sArq" }
        'invalido' { $pendencias.Add("O arquivo $sArq tem comentários (ou não é um JSON válido), então não mexi nele para não apagá-los. Peça ao Claude para juntar à mão as chaves de: $nossasArq") }
        default { $pendencias.Add("Não consegui juntar as configurações em $sArq ($r).") }
    }
}

if (-not $SoRegras) {
    Passo 'Antigravity'
    # Instalação só do usuário (padrão), para todos os usuários (Arquivos de Programas) ou no PATH
    function AcharAntigravity {
        $c = @((Join-Path $env:LOCALAPPDATA 'Programs\Antigravity IDE\bin\antigravity-ide.cmd'),
            (Join-Path $env:ProgramFiles 'Antigravity IDE\bin\antigravity-ide.cmd'),
            (Get-Command antigravity-ide -ErrorAction SilentlyContinue).Source) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        if ($c) { $c } else { Join-Path $env:LOCALAPPDATA 'Programs\Antigravity IDE\bin\antigravity-ide.cmd' }
    }
    $cli = AcharAntigravity
    if (-not (Test-Path $cli) -and $InstalarAntigravity) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'winget não encontrado (Windows 10 antigo?). Instale o Antigravity pelo site https://antigravity.google, ou o "Instalador de Aplicativo" da Microsoft Store, e rode de novo.' }
        Write-Host 'Instalando o Antigravity (winget)...'
        $ErrorActionPreference = 'Continue'
        & winget install --id Google.AntigravityIDE -e --silent --accept-package-agreements --accept-source-agreements
        $ErrorActionPreference = 'Stop'
        $cli = AcharAntigravity
    }
    if (-not (Test-Path $cli)) {
        $pendencias.Add('Antigravity não está instalado. Rode de novo com -InstalarAntigravity (ou instale por https://antigravity.google).')
    } else {
        $user = if ($DadosAntigravity) { Join-Path $DadosAntigravity 'User' } else { Join-Path $env:APPDATA 'Antigravity IDE\User' }
        New-Item -ItemType Directory -Force -Path $user | Out-Null
        $extensoes = @(Get-Content (Join-Path $aqui 'antigravity\extensoes.txt') -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ })
        # O CLI do Antigravity escreve avisos no canal de erro mesmo quando dá certo,
        # e com 'Stop' o PowerShell 5.1 trataria isso como falha: aqui vale 'Continue'.
        function Ag {
            $ErrorActionPreference = 'Continue'
            if ($DadosAntigravity) { & $cli --user-data-dir $DadosAntigravity --extensions-dir (Join-Path $DadosAntigravity 'extensoes') @args 2>$null } else { & $cli @args 2>$null }
        }
        function Lista([string[]]$perfil) { @(Ag --list-extensions @perfil | Where-Object { $_ -match '^[\w-]+\.[\w-]+$' } | ForEach-Object { $_.Trim().ToLower() }) }
        function InstalarExtensoes([string[]]$perfil, [string]$onde) {
            $ja = Lista $perfil
            foreach ($e in $extensoes) {
                if ($ja -contains $e.ToLower()) { Write-Host "$e : já instalada ($onde)"; continue }
                Ag --install-extension $e @perfil | Out-Null
                if ((Lista $perfil) -contains $e.ToLower()) { Write-Host "$e : instalada ($onde)" } else { $pendencias.Add("Extensão $e não instalou ($onde). Instale pela aba Extensões do Antigravity.") }
            }
        }

        # Perfil padrão do Antigravity = conta 1 (principal)
        Mesclar (Join-Path $user 'settings.json')
        InstalarExtensoes @() 'perfil padrão'

        # Conta 2: perfil próprio do Antigravity. A conta do Claude é escolhida por CLAUDE_CONFIG_DIR, e a
        # extensão só aceita essa configuração no nível do usuário/perfil (scope "machine"): no .vscode da pasta ela é ignorada.
        if ($Contas -eq 2) {
            Passo "Antigravity: perfil da conta $NomeConta2"
            $stArq = Join-Path $user 'globalStorage\storage.json'
            function LocalDoPerfil {
                if (-not (Test-Path -LiteralPath $stArq)) { return $null }
                try { (@((Get-Content -LiteralPath $stArq -Raw -Encoding UTF8 | ConvertFrom-Json).userDataProfiles) | Where-Object { $_.name -ceq $NomeConta2 } | Select-Object -First 1).location } catch { $null }
            }
            # Abrir a pasta com --profile cria o perfil (vazio) se faltar e liga a pasta a ele (documentação do VS Code, base do Antigravity)
            # Start-Process: não espera a janela (se o Antigravity estiver fechado, o comando só voltaria quando ele fechasse)
            $extra = if ($DadosAntigravity) { @('--user-data-dir', "`"$DadosAntigravity`"", '--extensions-dir', "`"$(Join-Path $DadosAntigravity 'extensoes')`"") } else { @() }
            foreach ($p in $PastaConta2) {
                Start-Process -FilePath $cli -ArgumentList (@($extra) + @("`"$p`"", '--profile', "`"$NomeConta2`"")) -WindowStyle Hidden
                Write-Host "Pasta ligada ao perfil $($NomeConta2): $p"
            }
            $loc = LocalDoPerfil
            for ($t = 0; -not $loc -and $t -lt 30; $t++) { Start-Sleep -Seconds 1; $loc = LocalDoPerfil }
            if (-not $loc) {
                $pendencias.Add("Não achei o perfil ""$NomeConta2"" no Antigravity. Crie pelo menu Perfis (engrenagem > Perfis > Novo perfil, vazio, com esse nome), abra a pasta da conta 2 com ele e rode este script de novo.")
            } else {
                Mesclar (Join-Path $user "profiles\$loc\settings.json") $listaContas[1].pasta
                InstalarExtensoes @('--profile', $NomeConta2) "perfil $NomeConta2"
            }
        }
        $pendencias.Add('No Antigravity: entre com a sua conta Google (se ainda não entrou).')
        $pendencias.Add('No Antigravity, Ctrl+Shift+P > "Reload Window" em cada janela aberta para as configurações valerem.')
    }
}

# ---------- 2b) Duas contas: comandos no terminal ----------
# Arquivos .cmd numa pasta do PATH: funcionam no cmd e no PowerShell 5 e 7 sem depender da política de scripts
# (que vem bloqueada no Windows) e sem mexer no perfil do PowerShell.
if ($Contas -eq 2 -and -not $SoAntigravity) {
    Passo "Conta $($NomeConta2): comandos no terminal"
    $c2 = $listaContas[1]
    New-Item -ItemType Directory -Force -Path $PastaComandos | Out-Null
    # Só ASCII no .cmd (o cmd lê o arquivo na página de código do Windows): a pasta vai como %USERPROFILE%\.claude-<slug>
    $semClaude = 'where claude >nul 2>nul || (echo Claude Code de terminal nao encontrado. Instale: https://code.claude.com/docs & exit /b 1)'
    $pastaCmd = "%USERPROFILE%\.claude-$slug2"
    $cmd2 = "@echo off`r`nrem Claude Code na conta $slug2 (criado pelo plugin ambiente-antigravity)`r`n$semClaude`r`nsetlocal`r`nset ""CLAUDE_CONFIG_DIR=$pastaCmd""`r`nclaude %*`r`n"
    $cmdContas = "@echo off`r`nrem Mostra o login das duas contas do Claude (criado pelo plugin ambiente-antigravity)`r`n$semClaude`r`nsetlocal`r`nset CLAUDE_CONFIG_DIR=`r`necho == principal (%USERPROFILE%\.claude)`r`nclaude auth status --text`r`nset ""CLAUDE_CONFIG_DIR=$pastaCmd""`r`necho.`r`necho == $slug2 ($pastaCmd)`r`nclaude auth status --text`r`n"
    foreach ($par in @(@("$($c2.comando).cmd", $cmd2), @('claude-contas.cmd', $cmdContas))) {
        $arq = Join-Path $PastaComandos $par[0]
        $atual = if (Test-Path -LiteralPath $arq) { [IO.File]::ReadAllText($arq) } else { '' }
        if ($atual -cne $par[1]) { Copia $arq; [IO.File]::WriteAllText($arq, $par[1], (New-Object System.Text.UTF8Encoding($false))); Write-Host "OK: $arq" } else { Write-Host "OK: $arq já estava atualizado" }
    }
    # A pasta precisa estar no PATH do usuário (o instalador oficial do Claude Code já põe ~\.local\bin)
    $pathUser = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (@($pathUser -split ';' | ForEach-Object { $_.TrimEnd('\') }) -notcontains $PastaComandos.TrimEnd('\')) {
        if ($NaoAlterarPath) { Write-Host "(teste) não acrescentei $PastaComandos ao PATH" }
        else {
            [Environment]::SetEnvironmentVariable('Path', ($(if ($pathUser) { $pathUser.TrimEnd(';') + ';' } else { '' }) + $PastaComandos), 'User')
            Write-Host "OK: $PastaComandos acrescentado ao PATH do usuário"
            $pendencias.Add('Feche e abra o terminal (e o Antigravity) para os comandos novos aparecerem.')
        }
    }
    # Versão anterior do plugin (1.2) gravava funções no perfil do PowerShell: tira o bloco antigo, se houver
    $docs = [Environment]::GetFolderPath('MyDocuments')
    foreach ($perfilPs in @((Join-Path $docs 'WindowsPowerShell\profile.ps1'), (Join-Path $docs 'PowerShell\profile.ps1'))) {
        if (-not (Test-Path -LiteralPath $perfilPs)) { continue }
        $atual = [IO.File]::ReadAllText($perfilPs, [Text.Encoding]::UTF8)
        $novo = [regex]::Replace($atual, '(?s)\r?\n?# >>> ambiente-antigravity-contas >>>.*?# <<< ambiente-antigravity-contas <<<\r?\n?', "`r`n")
        if ($novo -cne $atual) { Copia $perfilPs; [IO.File]::WriteAllText($perfilPs, $novo.TrimEnd() + "`r`n", (New-Object System.Text.UTF8Encoding($true))); Write-Host "OK: bloco antigo tirado de $perfilPs" }
    }
}

# ---------- 3) Login (e o plugin na conta 2) ----------
# A extensão do Claude no Antigravity/VS Code só mostra o botão de MICROFONE e só liga o CHROME (@browser)
# se achar login em ~\.claude. Ela lê essa pasta mesmo quando o chat usa outra (CLAUDE_CONFIG_DIR).
# Sem login ali, as duas funções somem sem nenhum erro. Aqui só conferimos; nada é alterado.
Passo 'Login do Claude (microfone e Chrome)'
$ErrorActionPreference = 'Continue'
$claudeTerminal = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claudeTerminal -and (Test-Path "$HOME\.local\bin\claude.exe")) { $claudeTerminal = "$HOME\.local\bin\claude.exe" }
$claude = $claudeTerminal
if (-not $claude) {
    # Só a extensão: dá para conferir o login, mas os comandos no terminal precisam do Claude Code de terminal
    $claude = (Get-ChildItem "$env:USERPROFILE\.antigravity-ide\extensions", "$env:USERPROFILE\.antigravity\extensions", "$env:USERPROFILE\.vscode\extensions" -Recurse -Filter claude.exe -ErrorAction SilentlyContinue |
        Where-Object FullName -like '*anthropic.claude-code*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    if ($Contas -eq 2) { $pendencias.Add('Os comandos claude-' + $slug2 + ' e claude-contas precisam do Claude Code de terminal, que não está instalado. Instale (no PowerShell: irm https://claude.ai/install.ps1 | iex) ou use só o painel do Claude no Antigravity.') }
}
function NaConta([string]$pasta, [scriptblock]$bloco) {
    $antes = $env:CLAUDE_CONFIG_DIR
    if ($pasta -and $pasta -ne (Join-Path $HOME '.claude')) { $env:CLAUDE_CONFIG_DIR = $pasta } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
    try { & $bloco } finally { if ($antes) { $env:CLAUDE_CONFIG_DIR = $antes } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } }
}
if ($claude) {
    # Conta 2: o plugin também nela, para "configura meu ambiente" funcionar nas duas
    if ($Contas -eq 2 -and -not $SoAntigravity) {
        NaConta $listaContas[1].pasta {
            if (-not ((& $claude plugin list 2>$null) | Out-String).Contains('ambiente-antigravity@prog-ambiente')) {
                & $claude plugin marketplace add ArthurPr0g/prog-ambiente-claude 2>&1 | Out-Null
                & $claude plugin install ambiente-antigravity@prog-ambiente 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { Write-Host "OK: plugin instalado também na conta $NomeConta2" } else { $pendencias.Add("O plugin não instalou na conta $($NomeConta2). No Antigravity, numa pasta da conta $NomeConta2, peça ao Claude: instale esse plugin https://github.com/ArthurPr0g/prog-ambiente-claude") }
            }
        }
    }
    foreach ($c in $listaContas) {
        $st = NaConta $c.pasta { try { (& $claude auth status --json 2>$null) | Out-String | ConvertFrom-Json } catch { $null } }
        $uso = if ($c.nome -eq 'principal') { 'conta principal (é ela que liga o microfone e o Chrome no painel)' } else { "conta $($c.nome)" }
        if ($st -and $st.loggedIn) { Write-Host "OK: $uso - logada ($($st.email))" }
        elseif ($st) {
            $como = if (-not $claudeTerminal) { 'entre pelo painel do Claude no Antigravity' + $(if ($c.nome -ne 'principal') { " (numa pasta da conta $($c.nome))" } else { '' }) }
            elseif ($c.nome -eq 'principal') { 'num terminal NOVO rode  claude auth login' } else { "num terminal NOVO rode  $($c.comando) auth login" }
            $pendencias.Add("Entre na $($uso): $como e depois, no Antigravity, Ctrl+Shift+P > ""Reload Window"".")
        } else { Write-Host "Não deu para conferir o login da $uso (versão antiga do Claude Code?)." }
    }
} else { Write-Host 'Claude Code não encontrado: o login será feito pelo painel do Claude no Antigravity.' }

Write-Host "`nPronto." -ForegroundColor Green
if ($pendencias.Count) {
    Write-Host 'PENDENTE (passos seus):' -ForegroundColor Yellow
    $pendencias | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}
