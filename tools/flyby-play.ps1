# L1 真实鼠标验收：0.25× 待机 -> 拖动/发射 -> 暂停 -> 手动机位 -> 掠月 -> 返回/手动结束 -> 重试。
# GameShot 只读状态用于等实际时机；所有玩法动作都走窗口中的鼠标命中。
param([switch]$ManualEnd, [ValidateRange(1,3)][int]$Level = 1, [ValidateSet('','LowPower','WrongDate')][string]$RejectCase = '')
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
  $readState = $null
  for ($readAttempt = 0; $readAttempt -lt 20; $readAttempt++) {
    try { $readState = Get-Content -LiteralPath $flybyState; break } catch { Start-Sleep -Milliseconds 10 }
  }
  if ($null -eq $readState) { return @{} }
  foreach ($line in $readState) {
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
    if ($state.ContainsKey('phase') -and (& $predicate $state)) { return $state }
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
	if ($Level -gt 1) { $name = $name.Replace('flyby-', "orbital-L$Level-") }
	if ($ManualEnd) { $name = $name.Replace('flyby-', 'flyby-manual-') }
  if ($RejectCase -ne '') { $name += '-' + $RejectCase.ToLower() }
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
  Set-Content -LiteralPath $flybyEnter -Value "$Level@arm:2" -NoNewline
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
  $null = Click-State ($flybyVW - 132) 132 { param($s) $s.phase -eq 'Aiming' }
  Capture 'flyby-idle'
  $null = Resume
  $standbyA = State
  Start-Sleep -Milliseconds 600
  $standbyB = State
  $delta = [double]$standbyB.date - [double]$standbyA.date
  if ($delta -lt 0.10 -or $delta -gt 0.20 -or [double]$standbyB.rate -ne 0.25) { throw 'standby not moving at 0.25x' }
  $nominalDate = if ($RejectCase -eq 'WrongDate') { 3.0 } else { 1.0 }
  $null = Wait-State { param($s) [double]$s.date -ge ($nominalDate - 0.01) }
  $null = Pause
  $launchDate = [double](State).date
  if ($launchDate -lt ($nominalDate - 0.03) -or $launchDate -gt ($nominalDate + 0.06)) { throw "missed nominal date: $launchDate" }
  Write-Output "Observed standby delta=$delta launchDate=$launchDate"
  $nominalPower = if ($Level -eq 1) { 0.875 } elseif ($Level -eq 2) { 11.0 / 14.0 } else { 0.5 }
  if ($RejectCase -eq 'LowPower') { $nominalPower = 0.04 }
  # 基准力度；原生鼠标拖动，不能用 Game.launch 代替。
  Move-Cursor ($flybyVW * 0.20) ($flybyVH * 0.5)
  Start-Sleep -Milliseconds 100
  [FlybyMouse]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
  for ($step = 1; $step -le 14; $step++) {
    Move-Cursor ($flybyVW * 0.20 + 380 * $nominalPower * $step / 14) ($flybyVH * 0.5)
    Start-Sleep -Milliseconds 35
  }
  [FlybyMouse]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
  $null = Wait-State { param($s) $s.phase -eq 'Armed' }
  if ([Math]::Abs([double](State).date - $launchDate) -gt 0.001) { throw 'armed did not freeze date' }
  Capture 'flyby-planned'
  $null = Click-State ($flybyVW - 60) 212 { param($s) $s.view -eq '3D' }
  Capture 'flyby-before-launch'
  Click ($flybyVW - 60) 132
  Click 149 202
  $ignition = Wait-State { param($s) $s.phase -eq 'Flying' -and $s.paused -eq '1' }
  if ((FlightTime $ignition) -ge 1.5) { throw 'launch pause arrived too late for camera regression' }
  Capture 'flyby-ignition'
  if ($RejectCase -ne '') {
    $null = Resume
    $null = Wait-State { param($s) $s.phase -eq 'Result' } 40
    if ((State).completed -ne '0' -or (Logs) -match 'result = success') { throw 'negative input completed mission' }
    Capture ('flyby-rejected-' + $RejectCase.ToLower())
    Set-Content -LiteralPath (Join-Path $flybyResults "L$Level-$RejectCase-input-log.txt") -Value (Logs)
    Write-Output "RESULT=PASS real input rejects $RejectCase"
    return
  }
  # 按钮循环机位，暂停期间也应可观察；手动选择不被自动分镜覆盖。
  # Rotate from the current automatic frame while paused. A HUD click must not take over.
  Capture 'flyby-auto-before-drag'
  $beforeDrag = State
  Move-Cursor ($flybyVW * 0.5) ($flybyVH * 0.45)
  [FlybyMouse]::mouse_event(2, 0, 0, 0, [IntPtr]::Zero)
  for ($drag = 1; $drag -le 12; $drag++) { Move-Cursor ($flybyVW * 0.5 + $drag * 8) ($flybyVH * 0.45 + $drag * 2); Start-Sleep -Milliseconds 25 }
  [FlybyMouse]::mouse_event(4, 0, 0, 0, [IntPtr]::Zero)
  $null = Wait-State { param($s) $s.focus -eq 'Probe' }
  Start-Sleep -Milliseconds 700
  if ((State).world -ne $beforeDrag.world) { throw 'camera drag changed paused physics' }
  if ((Logs) -notmatch 'camera takeover -> Probe') { throw 'drag did not take over camera' }
  Capture 'flyby-manual-drag'
  $focusModes = if ($Level -eq 1) { @('Moon', 'Earth', 'Overview', 'Auto') } elseif ($Level -eq 2) { @('Venus', 'Mercury', 'Sun', 'Overview', 'Auto') } else { @('Jupiter', 'Saturn', 'Sun', 'Overview', 'Auto') }
  foreach ($mode in $focusModes) {
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
  if ($ManualEnd -and $Level -eq 1) {
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
  $firstPeri = if ($Level -eq 1) { 16.7 } elseif ($Level -eq 2) { 13.7 } else { 7.4 }
  $null = Wait-State { param($s) (FlightTime $s) -ge $firstPeri }
  $null = Pause
  Capture 'flyby-periapsis'
  if ((State).phase -ne 'Flying') { throw 'viewing ended before near flyby' }
  if ($Level -eq 2) {
    $null = Resume
    $null = Wait-State { param($s) (FlightTime $s) -ge 19.2 }
    $null = Pause
    Capture 'flyby-mercury-periapsis'
    if ((State).phase -ne 'Flying') { throw 'viewing ended before Mercury flyby' }
    if ((Logs) -notmatch 'camera shot -> Auto:Mercury') { throw 'Mercury encounter camera missing' }
  }
  if ($Level -eq 3) {
    $null = Resume
    $null = Wait-State { param($s) (FlightTime $s) -ge 14.2 }
    $null = Pause
    Capture 'flyby-saturn-periapsis'
    if ((State).completed -ne '0') { throw 'mission completed before target region' }
  }
  if ($ManualEnd -and $Level -gt 1) { $null = Click-State 154 295 { param($s) $s.focus -eq 'Probe' } }
  $null = Resume
  $completed = Wait-State { param($s) $s.completed -eq '1' -and $s.phase -eq 'Flying' }
  if ([double]$completed.marker -lt 0 -or [double]$completed.marker -gt 0.6) { throw 'success effect progress invalid' }
  $null = Pause
  $effectPaused = State
  Capture 'flyby-completed-viewing'
  $null = Wait-State { param($s) [double]$s.marker -ge 0.6 }
  Capture 'flyby-marker-faded'
  $null = Click-State ($flybyVW - 60) 212 { param($s) $s.view -eq '2D' }
  Capture 'flyby-marker-faded-2d'
  if ([double](State).marker -ne 0.6) { throw 'view toggle replayed success effect' }
  $null = Click-State ($flybyVW - 60) 212 { param($s) $s.view -eq '3D' }
  if ((State).world -ne $effectPaused.world) { throw 'effect changed paused physical time' }
  if (([regex]::Matches((Logs), 'success marker triggered once')).Count -ne 1) { throw 'success effect triggered more than once' }
  if ($ManualEnd -and $Level -gt 1 -and (State).focus -ne 'Probe') { throw 'completion changed manual focus' }
  if ((Logs) -notmatch "flyby completion saved L$Level") { throw 'completion not saved at milestone' }
  if ($ManualEnd) {
    $null = Click-State ($flybyVW - 60) 132 { param($s) $s.phase -eq 'Result' }
    if ((Logs) -notmatch 'end viewing \(manual\)') { throw 'manual end not delivered' }
  } else {
    $null = Resume
    $viewTime = if ($Level -eq 1) { 29 } elseif ($Level -eq 2) { 24 } else { 20 }
    $null = Wait-State { param($s) (FlightTime $s) -ge $viewTime }
    $null = Pause
    Capture 'flyby-return'
    $null = Resume
    $null = Wait-State { param($s) $s.phase -eq 'Result' }
  }
  if ((Logs) -notmatch 'result = success') { throw 'flyby result not success' }
  Capture 'flyby-result'
  # Result card: fixed72 buttons,540 card height; back is lower than retry.
  $null = Click-State ($flybyVW / 2) (($flybyVH - 540) / 2 + 82) { param($s) $s.phase -eq 'LevelSelect' }
  Capture 'flyby-back-hub'
  $dockX = ($flybyVW - 448) / 2 + ($Level - 1) * 152 + 72
  $briefCount = ([regex]::Matches((Logs), "hub brief L$Level")).Count
  for ($pick = 0; $pick -lt 4; $pick++) {
    Click $dockX 112
    Start-Sleep -Milliseconds 650
    if (([regex]::Matches((Logs), "hub brief L$Level")).Count -gt $briefCount) { break }
  }
  if ((State).phase -ne 'LevelSelect') { throw 'brief click accidentally entered level' }
  Capture 'flyby-brief'
  $cardW = [Math]::Min(540, [Math]::Max(340, $flybyVW * 0.92))
  $null = Click-State ($flybyVW / 2 + $cardW / 2 - 88) 98 { param($s) $s.phase -eq 'Aiming' }
  Capture 'flyby-reenter'
  $null = Click-State ($flybyVW - 80) ($flybyVH - 49) { param($s) $s.phase -eq 'Aiming' }
  $retry = State
  if ($retry.completed -ne '0' -or $retry.focus -ne 'Auto' -or $retry.view -ne '2D' -or [double]$retry.marker -ne -1) { throw 'retry left stale viewing state' }
  Capture 'flyby-retry'
  $logName = if ($ManualEnd) { 'flyby-manual-input-log.txt' } else { 'flyby-input-log.txt' }
  if ($Level -gt 1) { $logName = if ($ManualEnd) { "orbital-L$Level-manual-input-log.txt" } else { "orbital-L$Level-input-log.txt" } }
  $log = Logs
  Set-Content -LiteralPath (Join-Path $flybyResults $logName) -Value $log
  Write-Output ($log -split "`n" | Select-String 'flyby planned|mission completed|camera shot|camera focus|completion saved|end viewing|result =|phase ->' | ForEach-Object { $_.Line })
  Write-Output ('RESULT=PASS real standby / drag / launch / pause / camera modes / flyby / ' + $(if ($ManualEnd) { 'manual end' } else { 'return' }) + ' / retry')
} finally {
  Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
  Remove-Item -LiteralPath $flybyEnter,$flybyReq,$flybyDone,$flybyObserve -ErrorAction SilentlyContinue
}
