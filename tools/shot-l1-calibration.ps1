# tools/shot-l1-calibration.ps1
$ErrorActionPreference = "Stop"
$root = "C:\Users\32485\AppData\Roaming\IppClub\DoraSSR\escape-velocity"
$exe = "C:\Users\32485\Downloads\dora-ssr-v1.9.3-windows-x86\Dora.exe"
$api = "http://127.0.0.1:8866"

function Api([string]$path, [string]$json = "{}", [int]$timeoutSec = 10) {
  return Invoke-RestMethod -Uri "$api/$path" -Method Post -Body $json -ContentType "application/json" -TimeoutSec $timeoutSec
}

Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 600

$resultsDir = "$root/.agent/test-results"
$reqFile = "$resultsDir/shot-request.txt"
$doneFile = "$resultsDir/shot-done.txt"

if (Test-Path $reqFile) { Remove-Item $reqFile -Force }
if (Test-Path $doneFile) { Remove-Item $doneFile -Force }

# 启动引擎
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) | Out-Null
$up = $false
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Milliseconds 500
  try { $null = Api "status"; $up = $true; break } catch {}
}
if (-not $up) { Write-Output "ENGINE-FAIL: 8866 起不来"; exit 1 }
Write-Output "engine up (waited $([int]($i / 2))s)"

# 运行 GameShot 驱动器
$fileArg = (($root -replace "\\", "/") + "/Test/GameShot")
$body = @{ file = $fileArg; asProj = $false } | ConvertTo-Json -Compress
try {
  $r = Api "run" $body 180
  Write-Output ("run -> " + ($r | ConvertTo-Json -Compress))
} catch {
  Write-Output "run failed: $($_.Exception.Message)"
}

Start-Sleep -Milliseconds 2000

function RequestShot([string]$cmd, [string]$outPng) {
  if (Test-Path $doneFile) { Remove-Item $doneFile -Force }
  $cmd | Out-File -FilePath $reqFile -Encoding ascii -NoNewline
  Write-Output "Sent cmd: $cmd"

  $captured = $false
  $shotFile = ""
  for ($k = 0; $k -lt 30; $k++) {
    Start-Sleep -Milliseconds 200
    if (Test-Path $doneFile) {
      $txt = Get-Content $doneFile -Raw
      if ($txt -match "(shot-\d+)") {
        $shotFile = $Matches[1]
        $captured = $true
        break
      }
    }
  }

  if ($captured) {
    Start-Sleep -Milliseconds 300
    $tga = "$resultsDir/$shotFile.tga"
    $png = "$resultsDir/$outPng"
    if (Test-Path $tga) {
      python -c "from PIL import Image; Image.open(r'$tga').save(r'$png')"
      Write-Output "SUCCESS: Saved $outPng (from $shotFile.tga)"
    } else {
      Write-Output "FAIL: TGA not found $tga"
    }
  } else {
    Write-Output "FAIL: Timeout waiting for $outPng"
  }
}

# 1. 触发进入 L1（月球·阿波罗任务），在第 15 帧抓取：3D 倒叙入场运镜第 1 幕（月球特写）
RequestShot "enterLevel:0 wait:15" "shot-l1-tour-moon.png"

# 2. 等待运镜推进到第 110 帧（约 1.8 秒）：抓取 3D 倒叙入场运镜第 3 幕（俯冲回地球探测器特写）
RequestShot "wait:95" "shot-l1-tour-earth.png"

# 3. 等待运镜结束（第 200 帧，切入 2D 规划模式）：抓取 2D 规划初始界面
RequestShot "wait:110" "shot-l1-2d-plan-default.png"

# 4. 触发 2D 视口放大（zoomIn）：抓取高精度微距 2D 规划界面
RequestShot "zoomIn" "shot-l1-2d-plan-zoomin.png"

# 5. 触发自适应聚焦（resetView）：抓取重置后的 2D 规划界面
RequestShot "resetView" "shot-l1-2d-plan-reset.png"

# 6. 展示 L1 三星挑战完成卡片
RequestShot "showResult:0" "shot-l1-result-challenge.png"

Stop-Process -Name Dora -Force -ErrorAction SilentlyContinue
Write-Output "Done all L1 calibration shots."

