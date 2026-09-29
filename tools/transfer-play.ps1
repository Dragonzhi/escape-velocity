# L1 真实输入回归：冷启动 -> 停表/取消 -> 真实拖动 -> 发射 -> 点火抓帧 -> 成功 -> 重试。
# 单次调用内维持引擎；标记文件放在被 git 忽略的 test-results 中。
$ErrorActionPreference = 'Stop'
$transferRoot = Split-Path $PSScriptRoot -Parent
$transferResults = Join-Path $transferRoot '.agent/test-results'
$transferEngine = 'C:/Users/32485/Downloads/dora-ssr-v1.9.3-windows-x86/Dora.exe'
$transferMouse = Join-Path $PSScriptRoot 'input-inject/mousectl.ps1'
$transferEnter = Join-Path $transferResults 'enter-request.txt'
$transferReq = Join-Path $transferResults 'shot-request.txt'
$transferDone = Join-Path $transferResults 'shot-done.txt'
function Api([string]$route, [string]$body = '{}') {
  Invoke-RestMethod -Uri "http://127.0.0.1:8866/$route" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 15
}
function Logs {
  $value = [string](Api 'log').log
  $at = $value.LastIndexOf('[escape-velocity] started:')
  if ($at -ge 0) { return $value.Substring($at) }
  return $value
}
function Mouse([string]$action, [double]$x, [double]$y, [double]$endX = 0, [double]$endY = 0) {
  $cx = [int]($x * $transferCW / $transferVW)
  $cy = [int](($transferVH - $y) * $transferCH / $transferVH)
  $ex = [int]($endX * $transferCW / $transferVW)
  $ey = [int](($transferVH - $endY) * $transferCH / $transferVH)
  & powershell -NoProfile -ExecutionPolicy Bypass -File $transferMouse -Action $action -StartX $cx -StartY $cy -EndX $ex -EndY $ey -Steps 10 -StepMs 40 | Out-Null
}
function Click-Until([double]$x, [double]$y, [string]$pattern) {
  $before = Logs
  for ($attempt = 0; $attempt -lt 4; $attempt++) {
    Mouse 'click' $x $y
    Start-Sleep -Milliseconds 650
    $after = Logs
    if ($after.StartsWith($before) -and $after.Substring($before.Length) -match $pattern) { return }
  }
  throw "input not delivered: $pattern"
}
$transferShotId = 0
function Capture([string]$name, [switch]$Raw) {
  $script:transferShotId++
  Remove-Item -LiteralPath $transferDone -ErrorAction SilentlyContinue
  $requestTmp = $transferReq + '.tmp'
  Set-Content -LiteralPath $requestTmp -Value ("$name-$transferShotId-wait:1") -NoNewline
  [IO.File]::Move($requestTmp, $transferReq, $true)
  for ($wait = 0; $wait -lt 100; $wait++) {
    Start-Sleep -Milliseconds 25
    if (Test-Path -LiteralPath $transferDone) {
      $stem = (Get-Content -LiteralPath $transferDone -Raw).Split(' ')[0]
      $source = Join-Path $transferResults ($stem + '.tga')
      if (Test-Path -LiteralPath $source) {
        # saveScreenshot 异步写文件，done 先于 TGA 完成；必须读完像素才认成功。
        & python -c "from PIL import Image; im=Image.open(r'$source'); im.load()" 2>$null
        if ($LASTEXITCODE -ne 0) { continue }
        $dest = Join-Path $transferResults ($name + '.tga')
        Copy-Item -LiteralPath $source -Destination $dest -Force
        if (-not $Raw) {
          & python -c "from PIL import Image; Image.open(r'$dest').save(r'$transferResults/$name.png')"
          if ($LASTEXITCODE -ne 0) { throw "invalid screenshot: $name" }
        }
        return
      }
    }
  }
  throw "capture timeout: $name"
}
try {
  Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
  # 不能把前一轮同名文件误当本轮的异步写入结果。
  Get-ChildItem -LiteralPath $transferResults -Filter 'shot-*.tga' | ForEach-Object { Remove-Item -LiteralPath $_.FullName }
  Remove-Item -LiteralPath $transferReq,$transferDone -ErrorAction SilentlyContinue
  Set-Content -LiteralPath $transferEnter -Value '1@arm:2' -NoNewline
  Start-Process -FilePath $transferEngine -WorkingDirectory (Split-Path $transferEngine) -WindowStyle Hidden | Out-Null
  $up = $false
  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 500
    try { $null = Api 'status'; $up = $true; break } catch {}
  }
  if (-not $up) { throw 'Dora API did not start' }
  # 以 Hidden 启动后 MainWindowHandle 为 0；只枚举本次 Dora 进程的顶层窗口并恢复，供输入回归使用。
  Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class TransferWindow { public delegate bool EnumCallback(IntPtr h, IntPtr p); [DllImport("user32.dll")] static extern bool EnumWindows(EnumCallback cb, IntPtr p); [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint id); [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h); [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd); public static IntPtr Find(int id) { IntPtr found=IntPtr.Zero; EnumWindows((h,p)=>{ uint owner; GetWindowThreadProcessId(h,out owner); if(owner==id && GetWindow(h,4)==IntPtr.Zero && GetWindowTextLength(h)>0) { found=h; return false; } return true; },IntPtr.Zero); return found; } }'
  $transferHandle = [TransferWindow]::Find((Get-Process Dora | Select-Object -First 1).Id)
  if ($transferHandle -eq [IntPtr]::Zero) { throw 'Dora window missing' }
  [TransferWindow]::ShowWindow($transferHandle, 9) | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'input-inject/set-window.ps1') -Shape portrait | Out-Null
  Start-Sleep -Milliseconds 700
  $null = Api 'run' (@{ file = "$transferRoot/Test/SizeProbe"; asProj = $false } | ConvertTo-Json -Compress)
  $size = [regex]::Match((Logs), 'View\.size = ([0-9.]+) x ([0-9.]+)')
  if (-not $size.Success) { throw 'View.size missing' }
  $transferVW = [double]$size.Groups[1].Value
  $transferVH = [double]$size.Groups[2].Value
  $geo = & powershell -NoProfile -ExecutionPolicy Bypass -File $transferMouse -Action restore | Out-String
  $rect = [regex]::Match($geo, 'client=(\d+) x (\d+)')
  if (-not $rect.Success) { throw 'client rect missing' }
  $transferCW = [double]$rect.Groups[1].Value
  $transferCH = [double]$rect.Groups[2].Value
  if ($transferCW -le 0 -or $transferCH -le 0) { throw 'Dora client rect is empty' }
  Write-Output "View=$transferVW x $transferVH client=$transferCW x $transferCH"
  $null = Api 'run' (@{ file = "$transferRoot/Test/GameShot"; asProj = $false } | ConvertTo-Json -Compress)
  Start-Sleep -Milliseconds 1500
  if ((Logs) -notmatch 'auto arm') { throw 'initial freeze failed' }
  Click-Until 149 202 'paused \('
  Click-Until ($transferVW - 340) 152 'aim cancelled'
  Capture 'transfer-idle'
  # 读取 JSON 的目标半径，和游戏同一份拖动映射（最大拖动 380 View 像素）。
  $level = (Get-Content -LiteralPath (Join-Path $transferRoot 'Assets/Levels/levels.json') -Raw | ConvertFrom-Json).levels[0]
  $orbiter = $level.orbiters[0]
  $ra = [Math]::Sqrt([Math]::Pow($orbiter.orbitRadius + $orbiter.offset.x, 2) + [Math]::Pow($orbiter.offset.y, 2))
  $drag = 380 * ($ra - $level.probe.orbitRadius) / ($level.transfer.apoapsisMax - $level.probe.orbitRadius)
  Mouse 'drag' ($transferVW * 0.30) ($transferVH * 0.50) ($transferVW * 0.30 + $drag) ($transferVH * 0.50)
  Start-Sleep -Milliseconds 400
  if ((Logs) -notmatch 'transfer armed dv=4\.') { throw 'real drag did not arm transfer' }
  Capture 'transfer-planned'
  Click-Until ($transferVW - 82) 252 'view toggle fire'
  Capture 'transfer-3d'
  # 在当前进程直接注入一次真实鼠标按下，避免启动 PowerShell 的延迟错过短时点火。
  $cx = [int](($transferVW - 134) * $transferCW / $transferVW)
  $cy = [int](($transferVH - 152) * $transferCH / $transferVH)
  Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class TransferClick { [StructLayout(LayoutKind.Sequential)] public struct Point { public int X; public int Y; } [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p); [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y); [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e); }'
  $point = New-Object TransferClick+Point
  $point.X = $cx
  $point.Y = $cy
  [TransferClick]::ClientToScreen($transferHandle, [ref]$point) | Out-Null
  [TransferClick]::SetCursorPos($point.X, $point.Y) | Out-Null
  Start-Sleep -Milliseconds 150
  [TransferClick]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [TransferClick]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
  # 点火仅约 0.3 秒：先以真实暂停按钮冻结其中一帧，再截完整尾焰。
  $point.X = [int](149 * $transferCW / $transferVW)
  $point.Y = [int](($transferVH - 202) * $transferCH / $transferVH)
  [TransferClick]::ClientToScreen($transferHandle, [ref]$point) | Out-Null
  [TransferClick]::SetCursorPos($point.X, $point.Y) | Out-Null
  Start-Sleep -Milliseconds 20
  [TransferClick]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 60
  [TransferClick]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
  Capture 'transfer-ignition'
  if ((Logs) -notmatch 'flight t=0\.[12][0-9].*speed=0.00') {
    Start-Sleep -Milliseconds 550
    if ((Logs) -notmatch 'flight t=0\.[12][0-9].*speed=0.00') { throw 'failed to freeze within actual burn' }
  }
  Click-Until 149 202 'resumed \('
  Capture 'transfer-burn-00' -Raw
  for ($frame = 1; $frame -lt 12; $frame++) { Capture ('transfer-burn-' + $frame.ToString('00')) -Raw }
  Click-Until 149 202 'paused \('
  Capture 'transfer-paused'
  Start-Sleep -Milliseconds 600
  Capture 'transfer-paused-later'
  # 暂停冻结物理时间；相机平滑过渡仍可继续，所以像素差只作辅助证据。
  $first = Join-Path $transferResults 'transfer-paused.png'
  $later = Join-Path $transferResults 'transfer-paused-later.png'
  & python -c "from PIL import Image,ImageChops; a=Image.open(r'$first').crop((100,200,550,780)); b=Image.open(r'$later').crop((100,200,550,780)); print('PAUSE changed pixels=',sum(p!=0 for p in ImageChops.difference(a,b).convert('L').getdata()))"
  if ($LASTEXITCODE -ne 0) { throw 'pause screenshot check failed' }
  Click-Until 149 202 'resumed \('
  for ($wait = 0; $wait -lt 40; $wait++) {
    if ((Logs) -match 'result = success') { break }
    Start-Sleep -Milliseconds 500
  }
  if ((Logs) -notmatch 'launch button fire \(press\)' -or (Logs) -notmatch 'result = success') { throw 'real launch did not succeed' }
  Capture 'transfer-result'
  Click-Until ($transferVW - 80) ($transferVH - 49) 'quick retry tapped'
  Capture 'transfer-retry'
  $log = Logs
  Set-Content -LiteralPath (Join-Path $transferResults 'transfer-input-log.txt') -Value $log
  Write-Output $log
  Write-Output 'RESULT=PASS real drag / launch / pause / resume / arrival / retry'
} finally {
  Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
  Remove-Item -LiteralPath $transferEnter,$transferReq,$transferDone -ErrorAction SilentlyContinue
}
