param(
  [ValidateSet('portrait','landscape')][string]$Shape = 'portrait'
)
# 把引擎窗口设成手机竖屏比例（客户区 400x710 → View.size ≈ 601x1066）或横屏（1349x820 → 2024x1230）。
# 开发时建议保持 portrait：UI 布局、相机取景、触摸命中都会按竖屏真实形态走（交付形态就是竖屏）。
# ⚠️ 本文件必须是 CRLF 换行：Windows PowerShell 5.1 的 here-string 在纯 LF 下会解析失败。
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class SW {
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int ht, bool repaint);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$proc = Get-Process Dora -ErrorAction Stop | Select-Object -First 1
$hw = $proc.MainWindowHandle
[SW]::ShowWindow($hw, 9) | Out-Null
[SW]::SetForegroundWindow($hw) | Out-Null
Start-Sleep -Milliseconds 300
$wr = New-Object SW+RECT
[SW]::GetWindowRect($hw, [ref]$wr) | Out-Null
$cr = New-Object SW+RECT
[SW]::GetClientRect($hw, [ref]$cr) | Out-Null
$ncW = ($wr.Right - $wr.Left) - ($cr.Right - $cr.Left)
$ncH = ($wr.Bottom - $wr.Top) - ($cr.Bottom - $cr.Top)
if ($Shape -eq 'portrait') { $cw = 400; $ch = 710 } else { $cw = 1349; $ch = 820 }
[SW]::MoveWindow($hw, $wr.Left, $wr.Top, $cw + $ncW, $ch + $ncH, $true) | Out-Null
Start-Sleep -Milliseconds 800
[SW]::GetClientRect($hw, [ref]$cr) | Out-Null
$w = $cr.Right - $cr.Left; $h = $cr.Bottom - $cr.Top
"shape=$Shape client=${w}x${h}  (View.size = client x1.5)"