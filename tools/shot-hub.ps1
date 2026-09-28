# tools/shot-hub.ps1
param(
  [string]$OutName = "shot-hub-v4.png"
)

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
$tgaFile = "$resultsDir/shot-001.tga"
$pngFile = "$resultsDir/$OutName"

if (Test-Path $reqFile) { Remove-Item $reqFile -Force }
if (Test-Path $doneFile) { Remove-Item $doneFile -Force }
if (Test-Path $tgaFile) { Remove-Item $tgaFile -Force }

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

# 等待游戏跑起来（2.5 秒，让所有 UI 布局和行星位置就绪）
Start-Sleep -Milliseconds 2500

# 发送截图请求
"hub-shot" | Out-File -FilePath $reqFile -Encoding ascii -NoNewline
Write-Output "shot-request written"

# 等待截图完成
$captured = $false
for ($i = 0; $i -lt 20; $i++) {
  if (Test-Path $doneFile) {
    $captured = $true
    break
  }
  Start-Sleep -Milliseconds 500
}

# 停掉引擎
try { $null = Api "stop" } catch {}
Start-Sleep -Milliseconds 300
Get-Process Dora -ErrorAction SilentlyContinue | Stop-Process -Force
Write-Output "engine stopped"

if (-not $captured -or -not (Test-Path $tgaFile)) {
  Write-Output "Screenshot capture failed: captured=$captured tgaExist=$(Test-Path $tgaFile)"
  exit 1
}

# 转 PNG
python -c "from PIL import Image; Image.open(r'$tgaFile').save(r'$pngFile')"
Write-Output "Captured $pngFile successfully"

