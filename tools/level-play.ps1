<#
.SYNOPSIS
  合成鼠标"玩一关"：起引擎 → 进关 → 读视口 → 按住时间流按钮 → 抓帧 → 打印日志证据。

.DESCRIPTION
  为什么需要它：tools/level-shots.ps1 只抓"进关第一帧"，证明不了**交互**（按住 / 连按 / 相态守卫）。
  这一份是"按一次、按住"这类时序行为的验收工具，配合 AGENTS 的纪律：
  判据看**日志行**或**像素差异**，不看"我点过一下"。

  坐标换算（见 tools/input-inject/README.md）：View 坐标是左下原点，
  client_x = view_x · (clientW / viewW)，client_y = (viewH - view_y) · (clientH / viewH)。
  ⚠️ View.size 一律现读（Test/SizeProbe.lua），不写死。
  时间流按钮的布局在 game/Hud.ts：宽 116 高 64，"加速 ▶" 的左边 = viewW - 136、底边 = viewH - 160。

.EXAMPLE
  # 进 L4，按住「加速 ▶」2.5 秒：日志里 stepTime dir=1 应该出现 ~7 次（第 1 次是按下那一下）
  pwsh tools/level-play.ps1 -Level 4 -HoldWarpMs 2500
  # 进 L4 并在第 90 帧自动发射，然后按住「加速」：应该只有 stepTime ignored（相态守卫）
  pwsh tools/level-play.ps1 -Level 4 -AutoLaunchFrame 90 -VX 0 -VY 34 -HoldWarpMs 1500
#>
param(
  [int]$Level = 4,
  # >0 = 进关后第 N 帧自动以 (VX,VY) 发射（走 enter-request 的开发钩子）
  [int]$AutoLaunchFrame = -1,
  [double]$VX = 0,
  [double]$VY = 0,
  # 按住「加速 ▶」多久（毫秒）；<=0 = 不按
  [int]$HoldWarpMs = 0,
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
# ⚠️ /log 的返回是 { log = "..." }：直接 Out-String 会把它压成一行属性表，
#    正则匹配不到 —— 照 tools/engine-run.ps1 的读法（它踩过同样的坑）。
function Get-LogText() {
  $lg = Api "log"
  if ($lg.log) { return [string]$lg.log }
  if ($lg -is [string]) { return [string]$lg }
  return ($lg | ConvertTo-Json -Depth 4 -Compress)
}

# ---- 1) 写 enter-request 并起引擎 ----
$spec = "$Level"
if ($AutoLaunchFrame -gt 0) { $spec = "$Level@$AutoLaunchFrame" + ":" + $VX + ":" + $VY }
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
# 截图轮询器装在 Test/GameShot 里 —— **必须 /run 一次**它才会去盯 shot-request.txt
$body2 = @{ file = (($root -replace "\\", "/") + "/Test/GameShot"); asProj = $false } | ConvertTo-Json -Compress
try { $null = Api "run" $body2 } catch { Write-Output "GameShot run failed: $($_.Exception.Message)" }
Start-Sleep -Seconds $SettleSec
$viewW = 0; $viewH = 0
$logText = Get-LogText
# ⚠️ 值是浮点（实测 "601.0 x 1066.0"）—— 只写 (\d+) 会匹配不到，正则要把小数点算进去
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

# ⚠️ log.txt 是**跨引擎实例累积**的（同一个文件一直在追加），而且 /log 返回的是定长尾部
#    （行数不随新增而变）—— 所以判据用**时间戳**（脚本开始那一刻），不用"行数差"。
$runStart = (Get-Date).AddSeconds(-3)

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

# ---- 4) 抓帧 ----
$prefix = if ($ShotName -ne "") { $ShotName } else { "play-L$Level" }
Remove-Item $shotDone, $shotReq -ErrorAction SilentlyContinue
Remove-Item (Join-Path $res "shot-*.tga") -ErrorAction SilentlyContinue
Set-Content -Path $shotReq -Value ($prefix + "-" + (Get-Date -Format "HHmmss")) -NoNewline
$tga = $null
for ($k = 0; $k -lt 30; $k++) {
  Start-Sleep -Milliseconds 500
  $tga = Get-ChildItem (Join-Path $res "shot-*.tga") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
  if ($tga -ne $null -and (Test-Path $shotDone)) { break }
}
if ($tga -ne $null) {
  $dst = Join-Path $res ($prefix + ".tga")
  Copy-Item $tga.FullName $dst -Force
  $png = [System.IO.Path]::ChangeExtension($dst, ".png")
  python -c "from PIL import Image; Image.open(r'$dst').save(r'$png')" 2>&1 | Out-Null
  Remove-Item $dst -Force
  if (Test-Path $png) { Write-Output ("shot -> " + $prefix + ".png") } else { Write-Output "png convert failed" }
} else { Write-Output "no screenshot produced" }

# ---- 5) 日志证据（只看这一轮刚起引擎的日志）----
$all = (Get-LogText) -split "\r?\n"
$tailN = 40
Write-Output ("--- 日志尾部 " + [Math]::Min($tailN, $all.Length) + " 行 ---")
if ($all.Length -gt 0) { $all[([Math]::Max(0, $all.Length - $tailN))..($all.Length - 1)] | ForEach-Object { $_.Trim() } }
Write-Output "--- 本轮关键行（按时间戳过滤）---"
foreach ($l in $all) {
  $tm = [regex]::Match($l, '^\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})')
  if (-not $tm.Success) { continue }
  if ([datetime]::ParseExact($tm.Groups[1].Value, 'yyyy-MM-dd HH:mm:ss', $null) -lt $runStart) { continue }
  if ($l -match 'stepTime|time warp|phase ->|result =|auto launch|enter L|size-probe') { Write-Output $l.Trim() }
}

Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item $enter -ErrorAction SilentlyContinue
Remove-Item $shotReq, $shotDone -ErrorAction SilentlyContinue
Write-Output "done"
