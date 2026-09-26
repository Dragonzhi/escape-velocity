<#
.SYNOPSIS
  合成鼠标"玩一关"：起引擎 → 进关 → 读视口 → 按住时间流 → 点按钮 → 抓帧 → 打印本轮日志。

.DESCRIPTION
  为什么需要它：tools/level-shots.ps1 只抓"进关第一帧"，证明不了**交互**（按住 / 连按 / 相态守卫 /
  "点了有没有反应"）。这一份是时序与命中类行为的验收工具，配合 AGENTS 的纪律：
  判据看**日志行**或**像素差异**，不看"我点过一下"。

  坐标换算（见 tools/input-inject/README.md）：View 坐标是左下原点，
  client_x = view_x · (clientW / viewW)，client_y = (viewH - view_y) · (clientH / viewH)。
  ⚠️ View.size 一律现读（Test/SizeProbe.lua），不写死。
  时间流按钮的布局在 game/Hud.ts：宽 116 高 64，"加速 ▶" 的左边 = viewW - 136、底边 = viewH - 160。
  「发射」按钮：宽 200 高 96、左下角 (viewW - 224, 96)（S3.12 会放大到 220×112，届时同步改默认值）。

.EXAMPLE
  # 进 L4，按住「加速 ▶」2.5 秒：日志里 stepTime dir=1 应连发 ~7 次（第 1 次是按下那一下）
  pwsh tools/level-play.ps1 -Level 4 -HoldWarpMs 2500
  # 进 L4，第 120 帧自动进 Armed（出「发射」按钮），按住加速到 ~180 秒，抓"发射前"一帧，
  # 点一次「发射」，再抓"发射后"一帧 ⇒ 两张图里行星位置必须一致（S3.12 bug①的 A/B 判据）
  pwsh tools/level-play.ps1 -Level 4 -AutoArmFrame 120 -HoldWarpMs 2500 -Taps 1 -ShotBeforeTaps
#>
param(
  [int]$Level = 4,
  # >0 = 进关后第 N 帧自动以 (VX,VY) 发射（走 enter-request 的开发钩子）
  [int]$AutoLaunchFrame = -1,
  # >0 = 进关后第 N 帧自动进 Armed（= 松开瞄准、出「发射」按钮）
  [int]$AutoArmFrame = -1,
  [double]$VX = 0,
  [double]$VY = 0,
  # 瞄准拖动（View 坐标，左下原点）：DragX1 < 0 = 不拖。用于"拖一次 ⇒ 出预测线"这类验收
  [int]$DragX1 = -1,
  [int]$DragY1 = -1,
  [int]$DragX2 = -1,
  [int]$DragY2 = -1,
  # 按住「加速 ▶」多久（毫秒）；<=0 = 不按
  [int]$HoldWarpMs = 0,
  # 连点：View 坐标（左下原点）。TapX < 0 = 不点
  [int]$TapX = -1,
  [int]$TapY = -1,
  [int]$Taps = 0,
  [int]$TapIntervalMs = 1200,
  # 连点之前先抓一张（名字 = <ShotName>-before）
  [switch]$ShotBeforeTaps,
  # 进关后先等多久（秒）—— 进关镜头 1.4 秒，给足
  [int]$SettleSec = 12,
  [string]$ShotName = ""
)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$exe = 'C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe'
$res = Join-Path $root '.agent\test-results'
if (-not (Test-Path $res)) { New-Item -ItemType Directory -Path $res | Out-Null }
$enter = Join-Path $res "enter-request.txt"
$shotReq = Join-Path $res "shot-request.txt"
$shotDone = Join-Path $res "shot-done.txt"
$mc = Join-Path $PSScriptRoot 'input-inject\mousectl.ps1'

function Api([string]$p, [string]$j = "{}") {
  return Invoke-RestMethod -Uri "http://127.0.0.1:8866/$p" -Method Post -Body $j -ContentType "application/json" -TimeoutSec 10
}
# ⚠️ /log 的返回是 { log = "..." }：直接 Out-String 会把它压成一行属性表，正则匹配不到
function Get-LogText() {
  $lg = Api "log"
  if ($lg.log) { return [string]$lg.log }
  if ($lg -is [string]) { return [string]$lg }
  return ($lg | ConvertTo-Json -Depth 4 -Compress)
}
function Take-Shot([string]$name) {
  Remove-Item $shotDone, $shotReq -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $res "shot-*.tga") -ErrorAction SilentlyContinue
  Set-Content -Path $shotReq -Value ($name + "-" + (Get-Date -Format "HHmmss")) -NoNewline
  $tga = $null
  for ($k = 0; $k -lt 30; $k++) {
    Start-Sleep -Milliseconds 500
    $tga = Get-ChildItem (Join-Path $res "shot-*.tga") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($tga -ne $null -and (Test-Path $shotDone)) { break }
  }
  if ($tga -eq $null) { Write-Output ("shot " + $name + ": FAILED (no tga)"); return }
  $dst = Join-Path $res ($name + ".tga")
  Copy-Item $tga.FullName $dst -Force
  $png = [System.IO.Path]::ChangeExtension($dst, ".png")
  python -c "from PIL import Image; Image.open(r'$dst').save(r'$png')" 2>&1 | Out-Null
  Remove-Item $dst -Force
  if (Test-Path $png) { Write-Output ("shot -> " + $name + ".png") } else { Write-Output ("shot " + $name + ": png convert failed") }
}

# ---- 1) 写 enter-request 并起引擎 ----
$spec = "$Level"
if ($AutoLaunchFrame -gt 0) { $spec = "$Level@$AutoLaunchFrame" + ":" + $VX + ":" + $VY }
elseif ($AutoArmFrame -gt 0) { $spec = "$Level@arm:" + $AutoArmFrame }
Set-Content -Path $enter -Value $spec -NoNewline
Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 700
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) | Out-Null
$up = $false
for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 500; try { $null = Api "status"; $up = $true; break } catch {} }
if (-not $up) { Write-Output "engine failed to start"; Remove-Item $enter -ErrorAction SilentlyContinue; exit 1 }
Write-Output "enter-request = $spec"

# ---- 2) 视口几何（现读，不写死）----
$body = @{ file = (($root -replace "\\", "/") + "/Test/SizeProbe"); asProj = $false } | ConvertTo-Json -Compress
try { $null = Api "run" $body } catch { Write-Output "SizeProbe run failed: $($_.Exception.Message)" }
# 截图轮询器装在 Test/GameShot 里 —— 必须 /run 一次它才会去盯 shot-request.txt
$body2 = @{ file = (($root -replace "\\", "/") + "/Test/GameShot"); asProj = $false } | ConvertTo-Json -Compress
try { $null = Api "run" $body2 } catch { Write-Output "GameShot run failed: $($_.Exception.Message)" }
Start-Sleep -Seconds $SettleSec
$viewW = 0; $viewH = 0
$logText = Get-LogText
# ⚠️ 值是浮点（实测 "601.0 x 1066.0"）—— 只写 (\d+) 会匹配不到
$m = [regex]::Match($logText, 'View\.size = ([0-9.]+) x ([0-9.]+)')
if ($m.Success) { $viewW = [int][double]$m.Groups[1].Value; $viewH = [int][double]$m.Groups[2].Value }
if ($viewW -le 0) { Write-Output "View.size not found in log; abort"; Get-Process Dora -EA SilentlyContinue | Stop-Process -Force; exit 1 }
Write-Output "View.size = $viewW x $viewH"

$geo = & powershell -NoProfile -ExecutionPolicy Bypass -File $mc -Action restore | Out-String
Write-Output ($geo.Trim())
$mg = [regex]::Match($geo, 'client=(\d+) x (\d+)')
if (-not $mg.Success) { Write-Output "client rect not found; abort"; Get-Process Dora -EA SilentlyContinue | Stop-Process -Force; exit 1 }
$cw = [int]$mg.Groups[1].Value; $ch = [int]$mg.Groups[2].Value

function To-Client([double]$vx, [double]$vy) {
  return @([int]($vx * $cw / $viewW), [int](($viewH - $vy) * $ch / $viewH))
}

# ⚠️ log.txt 是**跨引擎实例累积**的，而且 /log 返回的是定长尾部（行数不随新增而变）
#    —— 所以判据用**时间戳**（脚本开始那一刻），不用"行数差"。
$runStart = (Get-Date).AddSeconds(-3)
$prefix = if ($ShotName -ne "") { $ShotName } else { "play-L$Level" }

# ---- 2b) 瞄准拖动（如果给了坐标）----
if ($DragX1 -ge 0 -and $DragX2 -ge 0) {
  $c1 = To-Client $DragX1 $DragY1
  $c2 = To-Client $DragX2 $DragY2
  Write-Output ("瞄准拖动 view=(" + $DragX1 + "," + $DragY1 + ") -> (" + $DragX2 + "," + $DragY2 + ") client=(" + $c1[0] + "," + $c1[1] + ")->(" + $c2[0] + "," + $c2[1] + ")")
  & powershell -NoProfile -ExecutionPolicy Bypass -File $mc -Action drag -StartX $c1[0] -StartY $c1[1] -EndX $c2[0] -EndY $c2[1] -Steps 10 -StepMs 40 | Out-Null
  Start-Sleep -Milliseconds 600
}

# ---- 3) 按住「加速 ▶」----
if ($HoldWarpMs -gt 0) {
  $warpX = $viewW - 260 + 116 + 8 + 58
  $warpY = $viewH - 160 + 32
  $c = To-Client $warpX $warpY
  Write-Output ("按 加速▶ 于 view=(" + $warpX + "," + $warpY + ") client=(" + $c[0] + "," + $c[1] + ") 按住 " + $HoldWarpMs + " ms")
  & powershell -NoProfile -ExecutionPolicy Bypass -File $mc -Action press -StartX $c[0] -StartY $c[1] | Out-Null
  Start-Sleep -Milliseconds $HoldWarpMs
  & powershell -NoProfile -ExecutionPolicy Bypass -File $mc -Action release | Out-Null
  Start-Sleep -Milliseconds 500
}

# ---- 4) 连点之前的一帧（A/B 用）----
if ($ShotBeforeTaps) { Take-Shot ($prefix + "-before") }

# ---- 5) 连点（默认目标是「发射」按钮的中心）----
if ($Taps -gt 0) {
  # 「发射」按钮：220×112、左下角 (viewW-244, 96) ⇒ 中心 (viewW-134, 152)
  $tx = if ($TapX -ge 0) { $TapX } else { $viewW - 134 }
  $ty = if ($TapY -ge 0) { $TapY } else { 152 }
  $c = To-Client $tx $ty
  Write-Output ("连点 " + $Taps + " 次于 view=(" + $tx + "," + $ty + ") client=(" + $c[0] + "," + $c[1] + ") 间隔 " + $TapIntervalMs + " ms")
  for ($k = 0; $k -lt $Taps; $k++) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $mc -Action click -StartX $c[0] -StartY $c[1] | Out-Null
    if ($k -lt $Taps - 1) { Start-Sleep -Milliseconds $TapIntervalMs }
  }
  Start-Sleep -Milliseconds 500
}

# ---- 6) 连点之后抓一帧 ----
Take-Shot $prefix

# ---- 7) 日志证据（只打印本轮）----
$all = (Get-LogText) -split "\r?\n"
Write-Output "--- 本轮关键行（按时间戳过滤）---"
foreach ($l in $all) {
  $tm = [regex]::Match($l, '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')
  if (-not $tm.Success) { continue }
  if ([datetime]::ParseExact($tm.Groups[1].Value, 'yyyy-MM-dd HH:mm:ss', $null) -lt $runStart) { continue }
  if ($l -match 'stepTime|time warp|phase ->|result =|auto launch|auto arm|launch button|enter L|date handoff|warp ') { Write-Output $l.Trim() }
}

Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item $enter -ErrorAction SilentlyContinue
Remove-Item $shotReq, $shotDone -ErrorAction SilentlyContinue
Write-Output "done"
