<#
.SYNOPSIS
  逐关截图：每关重启一次引擎、用 enter-request 钩子进关、GameShot 抓帧、TGA→PNG。

.DESCRIPTION
  为什么要每关重启：enter-request.txt 只在 init 启动时解析一次（init.ts 的钩子），
  同一进程里换关要么走合成鼠标点选关、要么重启。重启一次 ≈ 20 秒，六关两分钟搞定，
  比合成鼠标可靠（同一坐标两次进 L6 的坑踩过）。

  产物：.agent/test-results/level-N.tga + level-N.png（并清理 shot-001.tga）。
  截图前会删掉 enter-request.txt —— 它**会劫持玩家自己的启动**（AGENTS.md 的坑）。
.EXAMPLE
  pwsh tools/level-shots.ps1 -Levels 1,2,3
#>
param(
  # ⚠️ 用 string 而不是 [int[]]：pwsh -File 传参时 "1,2,3" 是**一个字符串**，
  #    [int[]] 会把它强行转成数字 123456（实测：六关写成了一关 L123456）。
  [string]$Levels = "1,2,3,4,5,6",
  [int]$SettleSec = 14,
  [switch]$KeepTga
)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$exe = 'C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe'
$res = Join-Path $root '.agent\test-results'
if (-not (Test-Path $res)) { New-Item -ItemType Directory -Path $res | Out-Null }
$enter = Join-Path $res "enter-request.txt"
$shotReq = Join-Path $res "shot-request.txt"
$shotDone = Join-Path $res "shot-done.txt"

function Api([string]$p, [string]$j = "{}") {
  return Invoke-RestMethod -Uri "http://127.0.0.1:8866/$p" -Method Post -Body $j -ContentType "application/json" -TimeoutSec 10
}

# 解析关卡号：支持 "1,2,3" 与 "123"（后者按位拆）
$list = @()
foreach ($tok in ($Levels -split ',')) {
  $t = $tok.Trim()
  if ($t -match '^[1-6]$') { $list += [int]$t }
  elseif ($t -match '^[1-6]{2,}$') { foreach ($ch in $t.ToCharArray()) { $list += [int]([string]$ch) } }
}
if ($list.Count -eq 0) { Write-Output "no valid level in '$Levels'"; exit 1 }
Write-Output ("levels: " + ($list -join ','))

$made = @()
foreach ($n in $list) {
  Set-Content -Path $enter -Value "$n" -NoNewline
  Remove-Item $shotDone, $shotReq -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $res "shot-*.tga") -ErrorAction SilentlyContinue
  Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Milliseconds 700
  Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) | Out-Null
  $up = $false
  for ($i = 0; $i -lt 40; $i++) { Start-Sleep -Milliseconds 500; try { $null = Api "status"; $up = $true; break } catch {} }
  if (-not $up) { Write-Output "L${n}: engine failed to start"; continue }
  $body = @{ file = (($root -replace "\\", "/") + "/Test/GameShot"); asProj = $false } | ConvertTo-Json -Compress
  try { $null = Api "run" $body } catch { Write-Output "L${n}: /run failed $($_.Exception.Message)"; continue }
  Start-Sleep -Seconds $SettleSec
  Set-Content -Path $shotReq -Value ("L" + $n + "-" + (Get-Date -Format "HHmmss")) -NoNewline
  $tga = $null
  for ($k = 0; $k -lt 30; $k++) {
    Start-Sleep -Milliseconds 500
    $tga = Get-ChildItem (Join-Path $res "shot-*.tga") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($tga -ne $null -and (Test-Path $shotDone)) { break }
  }
  if ($tga -eq $null) { Write-Output "L${n}: no screenshot produced"; continue }
  $dst = Join-Path $res ("level-" + $n + ".tga")
  Copy-Item $tga.FullName $dst -Force
  $made += $dst
  Write-Output ("L" + $n + ": captured " + $tga.Name + " -> " + (Split-Path $dst -Leaf))
  try { $null = Api "stop" } catch {}
}
Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item $enter -ErrorAction SilentlyContinue       # ⚠️ 必须删：否则会劫持玩家的启动
Remove-Item $shotReq, $shotDone -ErrorAction SilentlyContinue

# TGA -> PNG（引擎截图未压缩，PIL 一行转）
foreach ($t in $made) {
  $p = [System.IO.Path]::ChangeExtension($t, ".png")
  python -c "from PIL import Image; Image.open(r'$t').save(r'$p')" 2>&1 | Out-Null
  if (Test-Path $p) {
    Write-Output ("png: " + (Split-Path $p -Leaf))
    if (-not $KeepTga) { Remove-Item $t -Force }
  } else { Write-Output ("png FAILED for " + $t) }
}
Write-Output "done"
