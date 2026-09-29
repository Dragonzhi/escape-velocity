# L1 真实鼠标验收：0.25× 待机 -> 拖动/发射 -> 暂停 -> 手动机位 -> 掠月 -> 返回/手动结束 -> 重试。
# GameShot 只读状态用于等实际时机；所有玩法动作都走窗口中的鼠标命中。
param([switch]$ManualEnd)
$ErrorActionPreference = 'Stop'
$flybyRoot = Split-Path $PSScriptRoot -Parent
$flybyResults = Join-Path $flybyRoot '.agent/test-results'
$flybyEngine = 'C:/Users/32485/Downloads/dora-ssr-v1.9.3-windows-x86/Dora.exe'
$flybyEnter = Join-Path $flybyResults 'enter-request.txt'
$flybyReq = Join-Path $flybyResults 'shot-request.txt'
$flybyDone = Join-Path $flybyResults 'shot-done.txt'
$flybyObserve = Join-Path $flybyResults 'observe-flight.flag'
$flybyState = Join-Path $flybyResults 'flight-state.txt'
function Api([string]$route, [string]$body = '{}') {
  Invoke-RestMethod -Uri "http://127.0.0.1:8866/$route" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 20
}
function Logs { return [string](Api 'log').log }
function State {
  if (-not (Test-Path -LiteralPath $flybyState)) { return @{} }
  $state = @{}
  foreach ($line in (Get-Content -LiteralPath $flybyState)) {
    $pair = $line.Split('=', 2)
    if ($pair.Length -eq 2) { $state[$pair[0]] = $pair[1] }
  }
  return $state
}
function FlightTime($state) { return [double]$state.world - [double]$state.date }
function Wait-State([scriptblock]$predicate, [double]$timeout = 20) {
  $watch = [Diagnostics.Stopwatch]::StartNew()
  while ($watch.Elapsed.TotalSeconds -lt $timeout) {
    $state = State
    if ($state.ContainsKey('world') -and (& $predicate $state)) { return $state }
    Start-Sleep -Milliseconds 20
  }
  throw ('state timeout: ' + ((State | ConvertTo-Json -Compress)))
}
# 普通字符串避免 PowerShell here-string 对 CRLF 的要求。
Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class FlybyMouse { public delegate bool EnumCallback(IntPtr h, IntPtr p); [StructLayout(LayoutKind.Sequential)] public struct Point { public int X; public int Y; } [StructLayout(LayoutKind.Sequential)] public struct Rect { public int L; public int T; public int R; public int B; } [DllImport("user32.dll")] static extern bool EnumWindows(EnumCallback cb, IntPtr p); [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint id); [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h); [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint cmd); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref Point p); [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect r); [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y); [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, IntPtr e); public static IntPtr Find(int id) { IntPtr found=IntPtr.Zero; EnumWindows((h,p)=>{ uint owner; GetWindowThreadProcessId(h,out owner); if(owner==id && GetWindow(h,4)==IntPtr.Zero && GetWindowTextLength(h)>0) { found=h; return false; } return true; },IntPtr.Zero); return found; } }'
function Move-Cursor([double]$x, [double]$y) {
  $point = New-Object FlybyMouse+Point
  $point.X = [int]($x * $flybyCW / $flybyVW)
  $point.Y = [int](($flybyVH - $y) * $flybyCH / $flybyVH)
  [FlybyMouse]::ClientToScreen($flybyHandle, [ref]$point) | Out-Null
  [FlybyMouse]::SetCursorPos($point.X, $point.Y) | Out-Null
}
function Click([double]$x, [double]$y) {
  Move-Cursor $x $y
  Start-Sleep -Milliseconds 20
  [FlybyMouse]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 50
  [FlybyMouse]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
}
function Click-State([double]$x, [double]$y, [scriptblock]$predicate) {
  for ($attempt = 0; $attempt -lt 4; $attempt++) {
    Click $x $y
    try { return Wait-State $predicate 0.65 } catch { }
  }
  throw 'mouse action did not produce expected state'
}
function Pause { return Click-State 149 202 { param($s) $s.paused -eq '1' } }
function Resume { return Click-State 149 202 { param($s) $s.paused -eq '0' } }
$flybyShotId = 0
function Capture([string]$name) {
	if ($ManualEnd) { $name = $name.Replace('flyby-', 'flyby-manual-') }
  $script:flybyShotId++
  Remove-Item -LiteralPath $flybyDone -ErrorAction SilentlyContinue
  $requestTmp = $flybyReq + '.tmp'
  Set-Content -LiteralPath $requestTmp -Value ("$name-$flybyShotId-wait:1") -NoNewline
  [IO.File]::Move($requestTmp, $flybyReq, $true)
  for ($wait = 0; $wait -lt 100; $wait++) {
    Start-Sleep -Milliseconds 25
    if (Test-Path -LiteralPath $flybyDone) {
      $stem = (Get-Content -LiteralPath $flybyDone -Raw).Split(' ')[0]
      $source = Join-Path $flybyResults ($stem + '.tga')
      if (Test-Path -LiteralPath $source) {
        & python -c "from PIL import Image; im=Image.open(r'$source'); im.load(); im.save(r'$flybyResults/$name.png')" 2>$null
        if ($LASTEXITCODE -eq 0) { return }
      }
    }
  }
  throw "capture timeout: $name"
}
try {
  Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
  Get-ChildItem -LiteralPath $flybyResults -Filter 'shot-*.tga' | ForEach-Object { Remove-Item -LiteralPath $_.FullName }
  Remove-Item -LiteralPath $flybyReq,$flybyDone,$flybyState -ErrorAction SilentlyContinue
  Set-Content -LiteralPath $flybyEnter -Value '1@arm:2' -NoNewline
  Set-Content -LiteralPath $flybyObserve -Value 'readonly' -NoNewline
  Start-Process -FilePath $flybyEngine -WorkingDirectory (Split-Path $flybyEngine) -WindowStyle Hidden | Out-Null
  $up = $false
  for ($attempt = 0; $attempt -lt 40; $attempt++) {
    Start-Sleep -Milliseconds 500
    try { $null = Api 'status'; $up = $true; break } catch {}
  }
  if (-not $up) { throw 'Dora API did not start' }
  $flybyHandle = [FlybyMouse]::Find((Get-Process Dora | Select-Object -First 1).Id)
  if ($flybyHandle -eq [IntPtr]::Zero) { throw 'Dora window missing' }
  # 只有真实输入测试需要恢复可见窗口。
  [FlybyMouse]::ShowWindow($flybyHandle, 9) | Out-Null
  [FlybyMouse]::SetForegroundWindow($flybyHandle) | Out-Null
  & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'input-inject/set-window.ps1') -Shape portrait | Out-Null
  Start-Sleep -Milliseconds 600
  $null = Api 'run' (@{ file = "$flybyRoot/Test/SizeProbe"; asProj = $false } | ConvertTo-Json -Compress)
  $size = [regex]::Match((Logs), 'View\.size = ([0-9.]+) x ([0-9.]+)')
  if (-not $size.Success) { throw 'View.size missing' }
  $flybyVW = [double]$size.Groups[1].Value
  $flybyVH = [double]$size.Groups[2].Value
  $rect = New-Object FlybyMouse+Rect
  [FlybyMouse]::GetClientRect($flybyHandle, [ref]$rect) | Out-Null
  $flybyCW = $rect.R - $rect.L; $flybyCH = $rect.B - $rect.T
  if ($flybyCW -le 0 -or $flybyCH -le 0) { throw 'empty client rect' }
  Write-Output "View=$flybyVW x $flybyVH client=$flybyCW x $flybyCH"
  $null = Api 'run' (@{ file = "$flybyRoot/Test/GameShot"; asProj = $false } | ConvertTo-Json -Compress)
  $null = Wait-State { param($s) $s.phase -eq 'Armed' }
  $null = Pause
  $null = Click-State ($flybyVW - 340) 152 { param($s) $s.phase -eq 'Aiming' }
  Capture 'flyby-idle'
  $null = Resume
  $standbyA = State
  Start-Sleep -Milliseconds 600
  $standbyB = State
  $delta = [double]$standbyB.date - [double]$standbyA.date
  if ($delta -lt 0.10 -or $delta -gt 0.20 -or [double]$standbyB.rate -ne 0.25) { throw 'standby not moving at 0.25x' }
  $null = Wait-State { param($s) [double]$s.date -ge 0.99 }
  $null = Pause
  $launchDate = [double](State).date
  if ($launchDate -lt 0.97 -or $launchDate -gt 1.06) { throw "missed nominal date: $launchDate" }
  Write-Output "Observed standby delta=$delta launchDate=$launchDate"
  # 力度 0.875 -> 远地点 471.5；原生鼠标拖动，不能用 Game.launch 代替。
  Move-Cursor ($flybyVW * 0.20) ($flybyVH * 0.5)
  Start-Sleep -Milliseconds 100
  [FlybyMouse]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
  for ($step = 1; $step -le 14; $step++) {
    Move-Cursor ($flybyVW * 0.20 + 380 * 0.875 * $step / 14) ($flybyVH * 0.5)
    Start-Sleep -Milliseconds 35
  }
  [FlybyMouse]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
  $null = Wait-State { param($s) $s.phase -eq 'Armed' }
  if ([Math]::Abs([double](State).date - $launchDate) -gt 0.001) { throw 'armed did not freeze date' }
  Capture 'flyby-planned'
  $null = Click-State ($flybyVW - 82) 252 { param($s) $s.view -eq '3D' }
  Capture 'flyby-before-launch'
  Click ($flybyVW - 134) 152
  Click 149 202
  $ignition = Wait-State { param($s) $s.phase -eq 'Flying' -and $s.paused -eq '1' }
  if ((FlightTime $ignition) -ge 0.30) { throw 'missed actual burn' }
  Capture 'flyby-ignition'
  # 按钮循环机位，暂停期间也应可观察；手动选择不被自动分镜覆盖。
  foreach ($mode in @('Probe', 'Moon', 'Earth', 'Overview', 'Auto')) {
    $null = Click-State 154 295 { param($s) $s.focus -eq $mode }
    Start-Sleep -Milliseconds 700
    if ((State).focus -ne $mode) { throw 'manual camera was overwritten' }
    Capture ('flyby-focus-' + $mode.ToLower())
  }
  $null = Resume
  $null = Wait-State { param($s) (FlightTime $s) -ge 4 }
  $null = Pause
  Capture 'flyby-coast'
  $pausedA = State
  Start-Sleep -Milliseconds 600
  $pausedB = State
  if ($pausedA.world -ne $pausedB.world) { throw 'paused physics continued' }
  if ($ManualEnd) {
    $null = Click-State 154 295 { param($s) $s.focus -eq 'Probe' }
    $null = Resume
    $null = Wait-State { param($s) (FlightTime $s) -ge 11.4 }
    $null = Pause
    if ((State).focus -ne 'Probe') { throw 'automatic moon shot overwrote manual focus' }
    Capture 'flyby-persist'
    foreach ($mode in @('Moon', 'Earth', 'Overview', 'Auto')) {
      $null = Click-State 154 295 { param($s) $s.focus -eq $mode }
      Start-Sleep -Milliseconds 550
    }
  }
  $null = Resume
  $null = Wait-State { param($s) (FlightTime $s) -ge 16.7 }
  $null = Pause
  Capture 'flyby-periapsis'
  if ((State).completed -ne '0') { throw 'mission ended at guidance light' }
  $null = Resume
  $completed = Wait-State { param($s) $s.completed -eq '1' -and $s.phase -eq 'Flying' }
  $null = Pause
  Capture 'flyby-completed-viewing'
  if ((Logs) -notmatch 'flyby completion saved L1') { throw 'completion not saved at milestone' }
  if ($ManualEnd) {
    $null = Click-State ($flybyVW - 134) 152 { param($s) $s.phase -eq 'Result' }
    if ((Logs) -notmatch 'end viewing \(manual\)') { throw 'manual end not delivered' }
  } else {
    $null = Resume
    $null = Wait-State { param($s) (FlightTime $s) -ge 29 }
    $null = Pause
    Capture 'flyby-return'
    $null = Resume
    $null = Wait-State { param($s) $s.phase -eq 'Result' }
  }
  if ((Logs) -notmatch 'result = success') { throw 'flyby result not success' }
  Capture 'flyby-result'
  $null = Click-State ($flybyVW - 80) ($flybyVH - 49) { param($s) $s.phase -eq 'Aiming' }
  $retry = State
  if ($retry.completed -ne '0' -or $retry.focus -ne 'Auto' -or $retry.view -ne '2D') { throw 'retry left stale viewing state' }
  Capture 'flyby-retry'
  $logName = if ($ManualEnd) { 'flyby-manual-input-log.txt' } else { 'flyby-input-log.txt' }
  $log = Logs
  Set-Content -LiteralPath (Join-Path $flybyResults $logName) -Value $log
  Write-Output ($log -split "`n" | Select-String 'flyby planned|mission completed|camera shot|camera focus|completion saved|end viewing|result =|phase ->' | ForEach-Object { $_.Line })
  Write-Output ('RESULT=PASS real standby / drag / launch / pause / five camera modes / flyby / ' + $(if ($ManualEnd) { 'manual end' } else { 'return' }) + ' / retry')
} finally {
  Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
  Remove-Item -LiteralPath $flybyEnter,$flybyReq,$flybyDone,$flybyObserve -ErrorAction SilentlyContinue
}
