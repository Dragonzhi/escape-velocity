param(
  [Parameter(Mandatory=$true)][string]$Action,     # restore | click | drag
  [int]$StartX = 0, [int]$StartY = 0,
  [int]$EndX = -1, [int]$EndY = -1,
  [int]$Steps = 14, [int]$StepMs = 30
)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class M {
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
}
"@
$DOWN = 0x0002; $UP = 0x0004
$proc = Get-Process Dora -ErrorAction Stop | Select-Object -First 1
$hw = $proc.MainWindowHandle
[M]::ShowWindow($hw, 9) | Out-Null
[M]::SetForegroundWindow($hw) | Out-Null
Start-Sleep -Milliseconds 400
$cr = New-Object M+RECT; [M]::GetClientRect($hw, [ref]$cr) | Out-Null
$cw = [int]($cr.Right - $cr.Left); $ch = [int]($cr.Bottom - $cr.Top)
$org = New-Object M+POINT; $org.X = 0; $org.Y = 0
[M]::ClientToScreen($hw, [ref]$org) | Out-Null
$ox = [int]$org.X; $oy = [int]$org.Y
"client=$cw x $ch origin=$ox,$oy foreground=$([M]::GetForegroundWindow() -eq $hw)"
if ($Action -eq 'restore') { exit 0 }

$ax = $ox + $StartX; $ay = $oy + $StartY
"action=$Action client=($StartX,$StartY) screen=($ax,$ay)"
[M]::SetCursorPos($ax, $ay) | Out-Null
Start-Sleep -Milliseconds 200
[M]::mouse_event($DOWN, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 150
if ($Action -eq 'drag') {
  $bx = $ox + $EndX; $by = $oy + $EndY
  "target screen=($bx,$by) steps=$Steps"
  for ($i = 1; $i -le $Steps; $i++) {
    $t = $i / $Steps
    $mx = [int]($ax + ($bx - $ax) * $t)
    $my = [int]($ay + ($by - $ay) * $t)
    [M]::SetCursorPos($mx, $my) | Out-Null
    Start-Sleep -Milliseconds $StepMs
  }
}
[M]::mouse_event($UP, 0, 0, 0, [IntPtr]::Zero)
'done'