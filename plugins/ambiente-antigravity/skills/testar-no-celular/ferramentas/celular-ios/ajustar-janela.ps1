# Ajudante da janela do iPhone (fica rodando enquanto o iPhone está aberto).
# 1) Tira menu, barra de endereço e barra de título do navegador de teste do WebKit.
# 2) Posiciona ao lado do Android (ou no canto inferior direito).
# 3) Lê comandos do abrir-iphone.mjs pela entrada padrão:
#    forma <x> <y> <w> <h> <raio> [btn <x> <y> <w> <h>]...  -> recorta a janela no formato do aparelho
#    inicio                                                   -> arrasta a janela seguindo o mouse até soltar o botão
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Text; using System.Collections.Generic; using System.Runtime.InteropServices;
public class Jan {
  public delegate bool CB(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(CB cb, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr p, CB cb, IntPtr l);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
  [DllImport("user32.dll")] public static extern bool SetMenu(IntPtr h, IntPtr m);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int hh, bool rp);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int hh, uint f);
  [DllImport("user32.dll")] public static extern int SetWindowRgn(IntPtr h, IntPtr r, bool redraw);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool ReleaseCapture();
  [DllImport("gdi32.dll")] public static extern IntPtr CreateRoundRectRgn(int a, int b, int c, int d, int e, int f);
  [DllImport("gdi32.dll")] public static extern IntPtr CreateRectRgn(int a, int b, int c, int d);
  [DllImport("gdi32.dll")] public static extern int CombineRgn(IntPtr d, IntPtr a, IntPtr b, int modo);
  [DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out P p);
  [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int k);
  public struct P { public int X, Y; }
  public struct R { public int L, T, Rt, B; }
  public static List<IntPtr> Topo(string titulo, int pid) { var l = new List<IntPtr>(); EnumWindows((h, x) => { var s = new StringBuilder(256); GetWindowText(h, s, 256); if (IsWindowVisible(h) && s.ToString().StartsWith(titulo)) l.Add(h); return true; }, IntPtr.Zero); return l; }
  public static List<IntPtr> Filhos(IntPtr p, string classe) { var l = new List<IntPtr>(); EnumChildWindows(p, (h, x) => { var s = new StringBuilder(256); GetClassName(h, s, 256); if (s.ToString() == classe) l.Add(h); return true; }, IntPtr.Zero); return l; }
}
"@

# Acha a janela mais nova com o título do iPhone que ainda tem menu (= ainda não ajustada)
$fim = (Get-Date).AddSeconds(20); $h = [IntPtr]::Zero
do {
  foreach ($j in [Jan]::Topo("iPhone 15", 0)) { if ([Jan]::Filhos($j, "ToolbarWindow32").Count) { $h = $j } }
  if ($h -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 250 }
} until ($h -ne [IntPtr]::Zero -or (Get-Date) -gt $fim)
if ($h -eq [IntPtr]::Zero) { exit 1 }

$web = [Jan]::Filhos($h, "WebKit2WebViewWindowClass") | Select-Object -First 1
$rw = New-Object Jan+R; [Jan]::GetWindowRect($web, [ref]$rw) | Out-Null
$LARG = $rw.Rt - $rw.L; $ALT = $rw.B - $rw.T

[Jan]::SetMenu($h, [IntPtr]::Zero) | Out-Null
foreach ($t in [Jan]::Filhos($h, "ToolbarWindow32")) { [Jan]::ShowWindow($t, 0) | Out-Null }
# Sem barra de título nem bordas (WS_CAPTION | WS_THICKFRAME | botões)
$GWL_STYLE = -16
$estilo = [Jan]::GetWindowLong($h, $GWL_STYLE)
$estilo = $estilo -band (-bnot (0x00C00000 -bor 0x00040000 -bor 0x00020000 -bor 0x00010000))
[Jan]::SetWindowLong($h, $GWL_STYLE, $estilo) | Out-Null

# Posição: à esquerda do Android, se aberto; senão, canto inferior direito
$wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$x = $wa.Right - $LARG - 12; $y = $wa.Bottom - $ALT - 12
$emu = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if ($emu) {
  $re = New-Object Jan+R; [Jan]::GetWindowRect($emu.MainWindowHandle, [ref]$re) | Out-Null
  if ($re.L -gt $LARG) { $x = $re.L - $LARG + 10; $y = [Math]::Max($wa.Top, $re.B - $ALT + 10) }
}
# SWP_FRAMECHANGED | SWP_NOZORDER
[Jan]::SetWindowPos($h, [IntPtr]::Zero, $x, $y, $LARG, $ALT, 0x0020 -bor 0x0004) | Out-Null
Start-Sleep -Milliseconds 300
[Jan]::MoveWindow($web, 0, 0, $LARG, $ALT, $true) | Out-Null
"janela=$h web=$web ${LARG}x${ALT} pos=$x,$y estilo=" + ("0x{0:X}" -f [Jan]::GetWindowLong($h, $GWL_STYLE))
"pronto"

while ($null -ne ($linha = [Console]::In.ReadLine())) {
  $p = $linha.Trim().Split(" ")
  if ($p[0] -eq "inicio") {
    # Segue o mouse (posição real do Windows) enquanto o botão esquerdo estiver apertado
    $ri = New-Object Jan+R; [Jan]::GetWindowRect($h, [ref]$ri) | Out-Null
    $c0 = New-Object Jan+P; [Jan]::GetCursorPos([ref]$c0) | Out-Null
    $c = New-Object Jan+P
    while (([Jan]::GetAsyncKeyState(0x01) -band 0x8000) -ne 0) {
      [Jan]::GetCursorPos([ref]$c) | Out-Null
      # SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE
      [Jan]::SetWindowPos($h, [IntPtr]::Zero, $ri.L + $c.X - $c0.X, $ri.T + $c.Y - $c0.Y, 0, 0, 0x0001 -bor 0x0004 -bor 0x0010) | Out-Null
      Start-Sleep -Milliseconds 8
    }
  }
  elseif ($p[0] -eq "forma") {
    $n = [int[]]($p[1..5])
    $rgn = [Jan]::CreateRoundRectRgn($n[0], $n[1], $n[0] + $n[2] + 1, $n[1] + $n[3] + 1, 2 * $n[4], 2 * $n[4])
    $i = 6
    while ($i + 4 -lt $p.Count -and $p[$i] -eq "btn") {
      $b = [int[]]($p[($i + 1)..($i + 4)])
      $r2 = [Jan]::CreateRectRgn($b[0], $b[1], $b[0] + $b[2], $b[1] + $b[3])
      [Jan]::CombineRgn($rgn, $rgn, $r2, 2) | Out-Null   # RGN_OR
      [Jan]::DeleteObject($r2) | Out-Null
      $i += 5
    }
    [Jan]::SetWindowRgn($h, $rgn, $true) | Out-Null   # a janela passa a ser dona da região
    [Jan]::MoveWindow($web, 0, 0, $LARG, $ALT, $true) | Out-Null
  }
}
