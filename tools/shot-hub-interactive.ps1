# tools/shot-hub-interactive.ps1
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

# 运行 GameShot
$fileArg = (($root -replace "\\", "/") + "/Test/GameShot")
$body = @{ file = $fileArg; asProj = $false } | ConvertTo-Json -Compress
try {
  $r = Api "run" $body 180
  Write-Output ("run -> " + ($r | ConvertTo-Json -Compress))
} catch {
  Write-Output "run failed: $($_.Exception.Message)"
}

# 等待游戏跑起来（2 秒）
Start-Sleep -Milliseconds 2000

function RequestShot([string]$cmd, [string]$outPng) {
  if (Test-Path $doneFile) { Remove-Item $doneFile -Force }
  $cmd | Out-File -FilePath $reqFile -Encoding ascii -NoNewline
  Write-Output "Sent cmd: $cmd"

  $captured = $false
  $shotFile = ""
  for ($k = 0; $k -lt 25; $k++) {
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

  if (-not $captured) {
    Write-Output "FAIL: shot for $cmd timed out"
    return
  }

  $tga = "$resultsDir/$shotFile.tga"
  $targetPng = "$resultsDir/$outPng"
  python -c "from PIL import Image; Image.open(r'$tga').save(r'$targetPng')"
  Write-Output "Saved $outPng (from $shotFile)"
}

# 1) 全景沙盘
RequestShot "pano" "shot-hub-pano.png"
Start-Sleep -Milliseconds 500

# 2) 特写 L1 月球 (阿波罗/嫦娥)
RequestShot "focus:0" "shot-hub-l1-moon.png"
Start-Sleep -Milliseconds 600

# 3) 特写 L2 水星 (水手10号)
RequestShot "focus:1" "shot-hub-l2-mercury.png"
Start-Sleep -Milliseconds 600

# 4) 特写 L3 太阳 (帕克号)
RequestShot "focus:2" "shot-hub-l3-sun.png"
Start-Sleep -Milliseconds 600

# 5) 特写 L4 木星 (伽利略号)
RequestShot "focus:3" "shot-hub-l4-jupiter.png"
Start-Sleep -Milliseconds 600

# 6) 特写 L6 海王星 (旅行者2号)
RequestShot "focus:5" "shot-hub-l6-neptune.png"
Start-Sleep -Milliseconds 600

# 7) L1 月球任务三枚火箭结算卡片
RequestShot "showResult:0" "shot-result-l1-moon.png"
Start-Sleep -Milliseconds 600

# 8) L2 水手10号水星任务三枚火箭结算卡片
RequestShot "showResult:1" "shot-result-l2-mercury.png"
Start-Sleep -Milliseconds 600

# 9) L4 伽利略号木星任务三枚火箭结算卡片
RequestShot "showResult:3" "shot-result-l4-galileo.png"
Start-Sleep -Milliseconds 600

# 10) L4 伽利略号木星制动窗口激活（慢动作透镜 + 逆喷按钮高能高亮）
RequestShot "brakeWindow:3" "shot-l4-brake-window.png"
Start-Sleep -Milliseconds 600

# 11) L4 伽利略号按下逆喷制动入轨（状态变为已捕获入轨）
RequestShot "brakePress" "shot-l4-braked-orbit.png"
Start-Sleep -Milliseconds 600

# 停掉引擎
try { $null = Api "stop" } catch {}
Start-Sleep -Milliseconds 300
Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Output "All shots captured and engine stopped"
