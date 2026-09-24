param(
  [Parameter(Mandatory=$true)][string]$Action,
  [int]$StartX = 0,
  [int]$StartY = 0,
  [int]$EndX = -1,
  [int]$EndY = -1,
  [int]$Steps = 14,
  [int]$StepMs = 30,
  [int]$HoldMs = 0
)
# Action: restore | click | drag | press | move | release
# 坐标一律是"引擎窗口客户区像素"；换算见同目录 README.md
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class M {
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
}
"@
$DOWN = 0x0002
$UP = 0x0004
$proc = Get-Process Dora -ErrorAction Stop | Select-Object -First 1
$hw = $proc.MainWindowHandle
[M]::ShowWindow($hw, 9) | Out-Null
[M]::SetForegroundWindow($hw) | Out-Null
Start-Sleep -Milliseconds 400
$cr = New-Object M+RECT
[M]::GetClientRect($hw, [ref]$cr) | Out-Null
$cw = [int]($cr.Right - $cr.Left)
$ch = [int]($cr.Bottom - $cr.Top)
$org = New-Object M+POINT
[M]::ClientToScreen($hw, [ref]$org) | Out-Null
$ox = [int]$org.X
$oy = [int]$org.Y
"client=$cw x $ch origin=$ox,$oy foreground=$([M]::GetForegroundWindow() -eq $hw)"
if ($Action -eq "restore") { exit 0 }

function Press-Down([int]$sx, [int]$sy) {
  [M]::SetCursorPos($sx, $sy) | Out-Null
  Start-Sleep -Milliseconds 150
  [M]::mouse_event($DOWN, 0, 0, 0, [IntPtr]::Zero)
}
function Move-To([int]$sx, [int]$sy, [int]$n, [int]$ms) {
  $cur = New-Object M+POINT
  [M]::GetCursorPos([ref]$cur) | Out-Null
  for ($i = 1; $i -le $n; $i++) {
    $t = $i / $n
    $mx = [int]($cur.X + ($sx - $cur.X) * $t)
    $my = [int]($cur.Y + ($sy - $cur.Y) * $t)
    [M]::SetCursorPos($mx, $my) | Out-Null
    Start-Sleep -Milliseconds $ms
  }
}
function Release-Up() {
  [M]::mouse_event($UP, 0, 0, 0, [IntPtr]::Zero)
}

$ax = $ox + $StartX
$ay = $oy + $StartY
$bx = $ox + $EndX
$by = $oy + $EndY

if ($Action -eq "press") {
  "press client=($StartX,$StartY) screen=($ax,$ay)"
  Press-Down $ax $ay
  exit 0
}
if ($Action -eq "move") {
  "move to client=($StartX,$StartY) screen=($ax,$ay) steps=$Steps"
  Move-To $ax $ay $Steps $StepMs
  exit 0
}
if ($Action -eq "release") {
  "release"
  Release-Up
  exit 0
}
if ($Action -eq "click") {
  "click client=($StartX,$StartY) screen=($ax,$ay)"
  Press-Down $ax $ay
  Start-Sleep -Milliseconds 120
  Release-Up
  "done"
  exit 0
}
if ($Action -eq "drag") {
  "drag client=($StartX,$StartY) -> ($EndX,$EndY) hold=$HoldMs steps=$Steps x $StepMs ms"
  Press-Down $ax $ay
  if ($HoldMs -gt 0) { "hold $HoldMs ms"; Start-Sleep -Milliseconds $HoldMs }
  Move-To $bx $by $Steps $StepMs
  Release-Up
  "done"
  exit 0
}
"unknown action: $Action"
exit 2