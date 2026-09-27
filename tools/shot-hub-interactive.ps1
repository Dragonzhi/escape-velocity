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
RequestShot "pano" "shot-hub-v5-pano.png"
Start-Sleep -Milliseconds 500

# 2) 特写 L1 月球
RequestShot "focus:0" "shot-hub-v5-l1.png"
Start-Sleep -Milliseconds 500

# 3) 启动 L1 任务进入关卡
RequestShot "launch" "shot-hub-v5-l1-launched.png"
Start-Sleep -Milliseconds 500

# 停掉引擎
try { $null = Api "stop" } catch {}
Start-Sleep -Milliseconds 300
Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Output "All shots captured and engine stopped"
