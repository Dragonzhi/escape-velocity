<#
.SYNOPSIS
  在活引擎里跑一次入口（单测 / 探针 / 真游戏 + 截图），跑完把引擎停掉。

.DESCRIPTION
  为什么要有这个脚本：pwsh 工具的一次调用结束后，它派生的进程会被一起收走
  （实测 Start-Process 起的引擎在下一次调用里就"积极拒绝"了）。所以「起引擎 → /run →
  等标记文件 → 读结果 → /stop」必须在**同一次调用**里完成 —— 这个脚本就是那一串。

  两个必须的细节：
  1) 引擎的**工作目录必须是引擎目录**：用项目目录当 cwd 启动，引擎会去跑项目的 init.lua，
     报 `module lualib_bundle not found` 然后死在半路（实测）。
  2) 每次跑之前先清干净 Dora 进程：残留实例会占着 8866（实测：一个崩了 Lua 的残留进程
     让后续所有 /status 都连接被拒）。

.PARAMETER Run
  入口文件，相对项目根（如 Test/UnitRunner、Test/GameShot）。空 = 只启动引擎。
.PARAMETER WaitFile
  要等的标记文件，相对项目根（先删掉再等它出现）。
.PARAMETER SettleSec
  /run 之后再空等几秒（给游戏自己跑起来用）。
.PARAMETER LogTail
  结束后打印引擎日志最后 N 行（0 = 不打印）。
.PARAMETER KeepAlive
  结束后不停引擎（调试用；默认停）。
.EXAMPLE
  pwsh tools/engine-run.ps1 -Run Test/UnitRunner -WaitFile .agent/test-results/unit-summary.txt
.EXAMPLE
  pwsh tools/engine-run.ps1 -Run Test/GameShot -SettleSec 12 -LogTail 20
#>
param(
  [string]$Run = '',
  [string]$WaitFile = '',
  [int]$TimeoutSec = 240,
  [int]$SettleSec = 0,
  [int]$LogTail = 0,
  [switch]$KeepAlive
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$exe = 'C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe'
$api = "http://127.0.0.1:8866"

# ⚠️ /run 会**同步执行**整个入口（单测批跑十几秒）后才回包 —— 超时给短了会误报失败。
function Api([string]$path, [string]$json = "{}", [int]$timeoutSec = 10) {
  return Invoke-RestMethod -Uri "$api/$path" -Method Post -Body $json -ContentType "application/json" -TimeoutSec $timeoutSec
}

# 1) 清干净残留实例（占着 8866 的崩态进程会让后面全部连接被拒）
Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600

# 2) 启动引擎（cwd 必须是引擎目录，见 .DESCRIPTION）
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) | Out-Null
$up = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  try { $null = Api "status"; $up = $true; break } catch {}
}
if (-not $up) { Write-Output "ENGINE-FAIL: 8866 起不来"; exit 1 }
Write-Output "engine up (waited $([int]($i / 2))s)"

# 3) 跑入口（⚠️ 标记文件必须**在 /run 之前**删：入口一开始就会写一次 phase=running，
#    在 /run 之后删会把这次写入吃掉，而它跑完的第二次写入实测**不会重新建文件** ——
#    结果就是永远等不到 phase=done，白白等到超时。2026-09-26 踩过。）
$abs = ""
if ($WaitFile -ne "") {
  $abs = Join-Path $root $WaitFile
  if (Test-Path $abs) { Remove-Item $abs -Force }
}
if ($Run -ne "") {
  $body = @{ file = (($root -replace "\\", "/") + "/" + $Run); asProj = $false } | ConvertTo-Json -Compress
  try { $r = Api "run" $body 180; Write-Output ("run -> " + ($r | ConvertTo-Json -Compress)) }
  catch { Write-Output ("run -> 请求超时/失败（标记文件仍会照常写，继续等）: " + $_.Exception.Message) }
}

if ($SettleSec -gt 0) { Start-Sleep -Seconds $SettleSec }

# 4) 等标记文件
if ($WaitFile -ne "") {
  # ⚠️ 标记文件通常**一开始就写一次**（内容 phase=running），跑完才改写成 phase=done —— 
  #    只看"文件出现"会在测试还没跑完时就返回（踩过：读到的是 phase=running 的半成品）。
  $got = $false
  for ($k = 0; $k -lt $TimeoutSec; $k++) {
    Start-Sleep -Seconds 1
    if (Test-Path $abs) {
      $c = Get-Content $abs -Raw
      if ($c -match 'phase=done' -or $c -match 'RESULT=') { $got = $true; break }
    }
  }
  Write-Output "marker settled after $($k)s"
  if ($got) { Write-Output "--- $WaitFile ---"; Get-Content $abs -Raw }
  else { Write-Output "MARKER-TIMEOUT: $WaitFile 在 $TimeoutSec 秒内没出现" }
}

# 5) 引擎日志尾部
if ($LogTail -gt 0) {
  try {
    $lg = Api "log"
    $txt = if ($lg.log) { $lg.log } elseif ($lg -is [string]) { $lg } else { $lg | ConvertTo-Json -Depth 4 -Compress }
    $arr = $txt -split "`n"
    Write-Output "--- log (last $LogTail) ---"
    $arr[([Math]::Max(0, $arr.Length - $LogTail))..($arr.Length - 1)] | ForEach-Object { $_ }
  } catch { Write-Output ("log fetch failed: " + $_.Exception.Message) }
}

# 6) 收尾
if (-not $KeepAlive) {
  try { $null = Api "stop" } catch {}
  Start-Sleep -Milliseconds 300
  Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
  Write-Output "engine stopped"
} else {
  Write-Output "engine left running (KeepAlive)"
}
