# configurar.ps1 - aplica o ambiente de trabalho do Claude Code neste PC (Windows).
#   1) Regras de trabalho no CLAUDE.md do usuário (num bloco marcado; o resto do arquivo fica intacto)
#   2) Antigravity: configurações do Claude Code (mescladas, sem apagar as da pessoa) e extensões padrão
# Pode rodar de novo quando quiser: o bloco de regras é substituído, não duplicado.
# Tudo que for alterado ganha uma cópia de segurança "<arquivo>.antes-ambiente-<data>".
#
#   .\configurar.ps1                        -> regras + configurações/extensões do Antigravity
#   .\configurar.ps1 -InstalarAntigravity   -> também instala o Antigravity pelo winget, se faltar
#   .\configurar.ps1 -SoRegras | -SoAntigravity
#
# Duas contas do Claude (ex.: pessoal + trabalho) no mesmo PC:
#   .\configurar.ps1 -Contas 2 -NomeConta2 "Trabalho" -PastaConta2 "C:\Projetos\Empresa"
#   - Conta 1 (principal) = pasta padrão ~\.claude. É também a que liga o microfone e o Chrome no painel.
#   - Conta 2 = pasta ~\.claude-<nome>. As pastas de -PastaConta2 abrem num perfil próprio do Antigravity
#     que usa essa conta; as outras pastas continuam na conta 1.
#   - No terminal: comandos  claude-<nome>  (abre o Claude na conta 2) e  claude-contas  (mostra os logins).
#   Para voltar a 1 conta, rode com -Contas 1: nada da conta 2 é apagado, ela só deixa de ser configurada.

param(
    [switch]$InstalarAntigravity, [switch]$SoRegras, [switch]$SoAntigravity,
    [ValidateSet(1, 2)][int]$Contas = 1,
    [string]$NomeConta2 = 'Trabalho',
    [string[]]$PastaConta2 = @(),
    [string]$PerfilPowerShell = '',  # onde gravar os comandos das contas (padrão: perfil do PowerShell do usuário)
    [string]$DadosAntigravity = ''   # só para testes: pasta de dados isolada do Antigravity (--user-data-dir)
)

$ErrorActionPreference = 'Stop'
$aqui = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$data = Get-Date -Format 'yyyyMMdd-HHmmss'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$pendencias = New-Object System.Collections.Generic.List[string]
function Passo([string]$m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Copia([string]$arq) {
    if (Test-Path -LiteralPath $arq) { Copy-Item -LiteralPath $arq -Destination "$arq.antes-ambiente-$data" -Force; Write-Host "cópia de segurança: $arq.antes-ambiente-$data" }
}

# Contas: a 1 é sempre a pasta padrão; a 2 ganha uma pasta própria com o nome dela (sem acento/espaço)
$slug2 = (($NomeConta2.Normalize([Text.NormalizationForm]::FormD) -replace '\p{Mn}', '').ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $slug2) { $slug2 = 'trabalho' }
$listaContas = @(@{ nome = 'principal'; pasta = (Join-Path $HOME '.claude'); comando = 'claude' })
if ($Contas -eq 2) {
    $listaContas += @{ nome = $NomeConta2; pasta = (Join-Path $HOME ".claude-$slug2"); comando = "claude-$slug2" }
    $PastaConta2 = @($PastaConta2 | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') })
    foreach ($p in $PastaConta2) { if (-not (Test-Path -LiteralPath $p -PathType Container)) { throw "A pasta da conta 2 não existe: $p" } }
    if (-not $PastaConta2.Count) { $pendencias.Add("Nenhuma pasta foi ligada à conta $NomeConta2. Rode de novo com -PastaConta2 ""C:\caminho\da\pasta"" para ela abrir nessa conta.") }
}

# ---------- 1) Regras de trabalho ----------
if (-not $SoAntigravity) {
    Passo 'Regras de trabalho do Claude'
    # Com 1 conta: a conta em uso (CLAUDE_CONFIG_DIR, se houver) ou ~/.claude. Com 2: as duas pastas.
    $destinos = if ($Contas -eq 2) { $listaContas | ForEach-Object { $_.pasta } } elseif ($env:CLAUDE_CONFIG_DIR) { @($env:CLAUDE_CONFIG_DIR) } else { @($listaContas[0].pasta) }
    $ini = '<!-- >>> ambiente-antigravity >>> -->'; $fim = '<!-- <<< ambiente-antigravity <<< -->'
    $regras = [IO.File]::ReadAllText((Join-Path $aqui 'regras-de-trabalho.md'), [Text.Encoding]::UTF8).Trim()
    $bloco = "$ini`n$regras`n$fim"
    foreach ($cfgDir in $destinos) {
        New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
        $arq = Join-Path $cfgDir 'CLAUDE.md'
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
        $user = if ($DadosAntigravity) { Join-Path $DadosAntigravity 'User' } else { Join-Path $env:APPDATA 'Antigravity IDE\User' }
        New-Item -ItemType Directory -Force -Path $user | Out-Null
        $nossas = [IO.File]::ReadAllText((Join-Path $aqui 'antigravity\settings.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
        $extensoes = @(Get-Content (Join-Path $aqui 'antigravity\extensoes.txt') -Encoding UTF8 | ForEach-Object { $_.Trim() } | Where-Object { $_ })

        # Grava só as chaves deste pacote (+ extras) num settings.json; as da pessoa ficam
        function Mesclar([string]$sArq, $extras) {
            $dela = $null
            if (Test-Path -LiteralPath $sArq) {
                $txt = [IO.File]::ReadAllText($sArq, [Text.Encoding]::UTF8)
                if ($txt.Trim()) { try { $dela = $txt | ConvertFrom-Json } catch { $dela = 'invalido' } }
            }
            if ($dela -eq 'invalido') {
                $pendencias.Add("O arquivo $sArq tem comentários ou vírgulas sobrando, então não mexi nele. Junte à mão as chaves de: $(Join-Path $aqui 'antigravity\settings.json')")
                return
            }
            if (-not $dela) { $dela = [pscustomobject]@{} }
            $mudou = $false
            foreach ($fonte in @($nossas, $extras)) {
                if (-not $fonte) { continue }
                foreach ($p in $fonte.PSObject.Properties) {
                    $antes = if ($dela.PSObject.Properties[$p.Name]) { $dela.($p.Name) | ConvertTo-Json -Depth 20 -Compress } else { $null }
                    if ($antes -ne ($p.Value | ConvertTo-Json -Depth 20 -Compress)) { $dela | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force; $mudou = $true }
                }
            }
            New-Item -ItemType Directory -Force -Path (Split-Path $sArq) | Out-Null
            if ($mudou) { Copia $sArq; [IO.File]::WriteAllText($sArq, ($dela | ConvertTo-Json -Depth 20), $utf8); Write-Host "OK: configurações em $sArq" }
            else { Write-Host "OK: configurações já estavam aplicadas em $sArq" }
        }
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
        Mesclar (Join-Path $user 'settings.json') $null
        InstalarExtensoes @() 'perfil padrão'

        # Conta 2: perfil próprio do Antigravity. A conta do Claude é escolhida por CLAUDE_CONFIG_DIR, e a
        # extensão só aceita essa configuração no nível do usuário/perfil (scope "machine"): no .vscode da pasta ela é ignorada.
        if ($Contas -eq 2) {
            Passo "Antigravity: perfil da conta $NomeConta2"
            $stArq = Join-Path $user 'globalStorage\storage.json'
            function LocalDoPerfil {
                if (-not (Test-Path -LiteralPath $stArq)) { return $null }
                try { (@((Get-Content -LiteralPath $stArq -Raw -Encoding UTF8 | ConvertFrom-Json).userDataProfiles) | Where-Object { $_.name -eq $NomeConta2 } | Select-Object -First 1).location } catch { $null }
            }
            # Abrir a pasta com --profile cria o perfil (vazio) se faltar e liga a pasta a ele (documentação do VS Code, base do Antigravity)
            foreach ($p in $PastaConta2) { Ag $p --profile $NomeConta2 | Out-Null; Write-Host "Pasta ligada ao perfil $($NomeConta2): $p" }
            $loc = LocalDoPerfil
            for ($t = 0; -not $loc -and $t -lt 30; $t++) { Start-Sleep -Seconds 1; $loc = LocalDoPerfil }
            if (-not $loc) {
                $pendencias.Add("Não achei o perfil ""$NomeConta2"" no Antigravity. Crie pelo menu Perfis (engrenagem > Perfis > Novo perfil, vazio), abra a pasta da conta 2 com ele e rode este script de novo.")
            } else {
                $extra = [pscustomobject]@{ 'claudeCode.environmentVariables' = @([pscustomobject]@{ name = 'CLAUDE_CONFIG_DIR'; value = $listaContas[1].pasta }) }
                Mesclar (Join-Path $user "profiles\$loc\settings.json") $extra
                InstalarExtensoes @('--profile', $NomeConta2) "perfil $NomeConta2"
            }
        }
        $pendencias.Add('No Antigravity: entre com a sua conta Google (se ainda não entrou).')
        $pendencias.Add('No Antigravity, Ctrl+Shift+P > "Reload Window" em cada janela aberta para as configurações valerem.')
    }
}

# ---------- 2b) Duas contas: comandos no terminal e o plugin também na conta 2 ----------
if ($Contas -eq 2 -and -not $SoAntigravity) {
    Passo "Conta $($NomeConta2): comandos no PowerShell"
    $ini = '# >>> ambiente-antigravity-contas >>>'; $fim = '# <<< ambiente-antigravity-contas <<<'
    $c2 = $listaContas[1]
    $blocoPerfil = @"
$ini
# Duas contas do Claude Code: a principal usa ~\.claude; a "$NomeConta2" usa a própria pasta.
function $($c2.comando) {
    `$antes = `$env:CLAUDE_CONFIG_DIR; `$env:CLAUDE_CONFIG_DIR = '$($c2.pasta)'
    try { & claude @args } finally { if (`$antes) { `$env:CLAUDE_CONFIG_DIR = `$antes } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } }
}
function claude-contas {
    foreach (`$p in @('', '$($c2.pasta)')) {
        `$antes = `$env:CLAUDE_CONFIG_DIR
        if (`$p) { `$env:CLAUDE_CONFIG_DIR = `$p } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
        Write-Host "`n== `$(if (`$p) { '$NomeConta2 (' + `$p + ')' } else { 'principal (~\.claude)' })" -ForegroundColor Cyan
        try { & claude auth status --text } finally { if (`$antes) { `$env:CLAUDE_CONFIG_DIR = `$antes } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } }
    }
}
$fim
"@
    $perfilPs = if ($PerfilPowerShell) { $PerfilPowerShell } else { $PROFILE.CurrentUserAllHosts }
    # O Windows vem com scripts bloqueados ("Restricted"): aí o PowerShell não carrega o perfil e os comandos não aparecem
    $politica = foreach ($s in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') { $v = Get-ExecutionPolicy -Scope $s; if ("$v" -ne 'Undefined') { "$v"; break } }
    if (-not $politica -or $politica -in 'Restricted', 'AllSigned') {
        $pendencias.Add("O Windows está bloqueando scripts do PowerShell ($(if ($politica) { $politica } else { 'Restricted' })), então os comandos $($c2.comando) e claude-contas não vão carregar. Para liberar só para o seu usuário: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned")
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $perfilPs) | Out-Null
    $atual = if (Test-Path -LiteralPath $perfilPs) { [IO.File]::ReadAllText($perfilPs, [Text.Encoding]::UTF8) } else { '' }
    $novo = ([regex]::Replace($atual, "(?s)$([regex]::Escape($ini)).*?$([regex]::Escape($fim))\r?\n?", '')).TrimEnd()
    $novo = ($(if ($novo) { "$novo`r`n`r`n" } else { '' }) + ($blocoPerfil -replace "`r?`n", "`r`n") + "`r`n")
    if ($novo -ne $atual) { Copia $perfilPs; [IO.File]::WriteAllText($perfilPs, $novo, (New-Object Text.UTF8Encoding($true))); Write-Host "OK: comandos $($c2.comando) e claude-contas em $perfilPs" }
    else { Write-Host 'OK: comandos do terminal já estavam atualizados' }
}

# ---------- 3) Login da pasta padrão (microfone e Chrome) ----------
# A extensão do Claude no Antigravity/VS Code só mostra o botão de MICROFONE e só liga o CHROME (@browser)
# se achar login em ~\.claude. Ela lê essa pasta mesmo quando o chat usa outra (CLAUDE_CONFIG_DIR).
# Sem login ali, as duas funções somem sem nenhum erro. Aqui só conferimos; nada é alterado.
Passo 'Login do Claude (microfone e Chrome)'
$ErrorActionPreference = 'Continue'
$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) {
    $claude = (Get-ChildItem "$env:USERPROFILE\.antigravity-ide\extensions", "$env:USERPROFILE\.antigravity\extensions", "$env:USERPROFILE\.vscode\extensions" -Recurse -Filter claude.exe -ErrorAction SilentlyContinue |
        Where-Object FullName -like '*anthropic.claude-code*' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
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
                if ($LASTEXITCODE -eq 0) { Write-Host "OK: plugin instalado também na conta $NomeConta2" } else { $pendencias.Add("Plugin não instalou na conta $($NomeConta2): rode  $($listaContas[1].comando) plugin install ambiente-antigravity@prog-ambiente") }
            }
        }
    }
    foreach ($c in $listaContas) {
        $st = NaConta $c.pasta { try { (& $claude auth status --json 2>$null) | Out-String | ConvertFrom-Json } catch { $null } }
        $uso = if ($c.nome -eq 'principal') { 'conta principal (é ela que liga o microfone e o Chrome no painel)' } else { "conta $($c.nome)" }
        if ($st -and $st.loggedIn) { Write-Host "OK: $uso - logada ($($st.email))" }
        elseif ($st) {
            $cmd = if ($c.nome -eq 'principal') { 'claude auth login' } else { "$($c.comando) auth login" }
            $pendencias.Add("Entre na $($uso): num PowerShell NOVO rode  $cmd  e depois, no Antigravity, Ctrl+Shift+P > ""Reload Window"".")
        } else { Write-Host "Não deu para conferir o login da $uso (versão antiga do Claude Code?)." }
    }
} else { Write-Host 'Claude Code não encontrado no PATH: o login será feito pelo painel do Claude no Antigravity.' }

Write-Host "`nPronto." -ForegroundColor Green
if ($pendencias.Count) {
    Write-Host 'PENDENTE (passos seus):' -ForegroundColor Yellow
    $pendencias | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}
