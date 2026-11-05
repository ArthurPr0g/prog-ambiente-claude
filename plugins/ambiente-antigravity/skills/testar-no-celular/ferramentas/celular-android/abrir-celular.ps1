# Abre o celular Android (emulador) no canto direito da tela, já no site pedido.
# Uso: powershell -File abrir-celular.ps1 [url]
#   ex.: powershell -File abrir-celular.ps1 https://example.com
# O Claude também usa o adb (platform-tools) para tocar, rolar e tirar prints (sempre com -e: só o emulador).
param([string]$url = "")
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch {}

# Mesma regra do instalar-simuladores.ps1: com acento no caminho do usuário, tudo fica em C:\Android
$semAcento = ($env:LOCALAPPDATA + $env:USERPROFILE) -notmatch '[^\x20-\x7E]'
$sdk = if ($semAcento) { "$env:LOCALAPPDATA\Android\Sdk" } else { 'C:\Android\Sdk' }
$env:ANDROID_SDK_ROOT = $sdk
$env:ANDROID_HOME = $sdk
$env:ANDROID_AVD_HOME = if ($semAcento) { "$env:USERPROFILE\.android\avd" } else { 'C:\Android\avd' }
$adb = "$sdk\platform-tools\adb.exe"
$emu = "$sdk\emulator\emulator.exe"
if (-not (Test-Path $adb) -or -not (Test-Path $emu)) { "Emulador não instalado: rode instalar-simuladores.ps1."; exit 1 }
# -e = só o emulador (com um celular de verdade no cabo USB, o adb sem -e não sabe qual usar)
function Adb { & $adb -e @args 2>$null }

# Já está aberto?
$ligado = (& $adb devices 2>$null) -match "emulator-\d+\s+device"
if (-not $ligado) {
  # Sem janela de terminal (CreateNoWindow): só a janela do celular aparece.
  $info = New-Object System.Diagnostics.ProcessStartInfo $emu, "-avd Galaxy_S26 -gpu auto"
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  [System.Diagnostics.Process]::Start($info) | Out-Null
  # A primeira vez demora (1 a 3 min); depois abre em segundos. Desiste depois de 5 min.
  $limite = (Get-Date).AddMinutes(5)
  do { Start-Sleep 2 } until (((Adb shell getprop sys.boot_completed) -match "1") -or (Get-Date) -gt $limite)
  if (-not ((Adb shell getprop sys.boot_completed) -match "1")) { "O Android não terminou de ligar em 5 min. Confira a aceleração (instalar-simuladores.ps1 avisa) e tente de novo."; exit 1 }
  # Sem isso a tela apaga em ~10 s e o celular parece "preto/desligado"
  Adb shell svc power stayon true | Out-Null

  # Janela no canto inferior direito, com ~72% da altura da tela (o iPhone abre ao lado)
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type @"
using System; using System.Runtime.InteropServices;
public class JanEmu { [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool rp); }
"@
  $p = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($p) {
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $h = [int]($wa.Height * 0.72); $w = [int]($h * 1190 / 2450)
    [JanEmu]::MoveWindow($p.MainWindowHandle, $wa.Right - $w - 12, $wa.Bottom - $h - 12, $w, $h, $true) | Out-Null
  }
}
Adb shell input keyevent KEYCODE_WAKEUP | Out-Null
if ($url) {
  # Com bloqueio de tela ativo o Chrome não abre (o Android responde "unable to resolve Intent")
  if ((Adb shell dumpsys window) -match "isKeyguardShowing=true") { "Celular bloqueado: desbloqueie na janela do emulador e rode de novo." }
  Adb shell am start -a android.intent.action.VIEW -d $url com.android.chrome | Out-Null
}
"Celular pronto."
