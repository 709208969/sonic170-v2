# sonic170 驱动包内嵌脚本
# 用途：把 sonic170_dfu_driver.zip 转 base64 内嵌为网页 FW_DL_DRV_B64 常量
#       （与固件 FW_DL_B64 同机制——file:// 离线可下载，不依赖网络/CDN 文件存在）
# 用法：scripts\embed-dfu-driver.ps1   （驱动包更新后运行一次）
# 校验：base64 解码逐字节长度一致 + 替换前后 HTML 标签配对不变
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Html = Join-Path $Root 'sonic170v2-rgb-control.html'
$Zip  = Join-Path $Root 'sonic170_dfu_driver.zip'
if (-not (Test-Path -LiteralPath $Zip)) { Write-Host "[embed] 未找到 $Zip，跳过"; exit 0 }

# 1. base64 编码 + 解码逐字节校验
$raw = [IO.File]::ReadAllBytes($Zip)
$b64 = [Convert]::ToBase64String($raw)
$back = [Convert]::FromBase64String($b64)
if ($back.Length -ne $raw.Length) { throw "[embed] base64 解码长度不一致: $($back.Length) != $($raw.Length)" }
Write-Host ("[embed] zip {0} B -> base64 {1} chars（校验一致）" -f $raw.Length, $b64.Length)

# 2. 读 HTML（保持原换行/编码，UTF-8 无 BOM）
$text = [IO.File]::ReadAllText($Html, (New-Object Text.UTF8Encoding($false)))
$newLine = "const FW_DL_DRV_B64 = '$b64';"

if ($text -match "const FW_DL_DRV_B64 = '[^']*';") {
  # 已存在 → 整体替换
  $text = [regex]::Replace($text, "const FW_DL_DRV_B64 = '[^']*';", $newLine)
  Write-Host '[embed] 已替换现有 FW_DL_DRV_B64'
} else {
  # 不存在 → 插到 FW_DL_B64_SOLDER 行后（两行间可能无换行符歧义，按行处理）
  $lines = $text -split "`r`n|`n"
  $idx = -1
  for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match "^const FW_DL_B64_SOLDER ") { $idx = $i; break }
  }
  if ($idx -lt 0) { throw '[embed] 未找到 FW_DL_B64_SOLDER 锚点行' }
  $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
  $lines = $lines[0..$idx] + $newLine + $lines[($idx + 1)..($lines.Length - 1)]
  $text = $lines -join $nl
  Write-Host '[embed] 已在 FW_DL_B64_SOLDER 后插入 FW_DL_DRV_B64'
}

# 3. 写回（UTF-8 无 BOM）
[IO.File]::WriteAllText($Html, $text, (New-Object Text.UTF8Encoding($false)))
Write-Host '[embed] 内嵌完成'
