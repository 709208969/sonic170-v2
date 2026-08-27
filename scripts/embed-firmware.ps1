# sonic170 固件内嵌脚本（v47.70 新增，替代手改）
# 用途：把最新 hotswap/solder bin 内嵌为网页 FW_DL_B64 / FW_DL_B64_SOLDER，
#       并同步 EMBED_FW_VERSION + 下载名(a.download) + HTML fallback 按钮文字 + i18n(en/zh) 五处。
# 用法：scripts\embed-firmware.ps1   （固件编译后运行一次）
# 校验：base64 解码逐字节长度一致
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$Html = Join-Path $Root 'sonic170v2-rgb-control.html'

# 1. 按名倒序取最新 bin（与 auto-release.ps1 同规则）
function Get-LatestBin([string]$pat) {
  $f = Get-ChildItem -Path $Root -Filter $pat -File | Sort-Object Name -Descending | Select-Object -First 1
  if (-not $f) { throw "[embed-fw] 未找到 $pat" }
  return $f
}
$Hot = Get-LatestBin 'SONIC170_hotswap_v*.bin'
$Sol = Get-LatestBin 'SONIC170_solder_v*.bin'
$Ver = [regex]::Match($Hot.Name, 'v(\d+\.\d+\.\d+)').Groups[1].Value
if (-not $Ver) { throw "[embed-fw] 无法从 $($Hot.Name) 提取版本号" }
Write-Host "[embed-fw] hotswap=$($Hot.Name) solder=$($Sol.Name) 版本 $Ver"

# 2. base64 编码 + 解码校验
function New-B64([string]$path) {
  $raw = [IO.File]::ReadAllBytes($path)
  $b64 = [Convert]::ToBase64String($raw)
  if ([Convert]::FromBase64String($b64).Length -ne $raw.Length) { throw "[embed-fw] $path base64 校验失败" }
  Write-Host ("[embed-fw] {0} {1} B -> base64 {2} chars（校验一致）" -f (Split-Path $path -Leaf), $raw.Length, $b64.Length)
  return $b64
}
$b64Hot = New-B64 $Hot.FullName
$b64Sol = New-B64 $Sol.FullName

# 3. 读 HTML 并替换五处
$text = [IO.File]::ReadAllText($Html, (New-Object Text.UTF8Encoding($false)))
$newHot  = "const FW_DL_B64 = '$b64Hot';"
$newSol  = "const FW_DL_B64_SOLDER = '$b64Sol';"
$text = [regex]::Replace($text, "const FW_DL_B64 = '[^']*';?", $newHot)
$text = [regex]::Replace($text, "const FW_DL_B64_SOLDER = '[^']*';?", $newSol)
$text = [regex]::Replace($text, "const EMBED_FW_VERSION = '[^']*'", "const EMBED_FW_VERSION = '$Ver'")
$text = [regex]::Replace($text, "a\.download = 'SONIC170_hotswap_v[^']*\.bin'", "a.download = 'SONIC170_hotswap_v$Ver.bin'")
$text = [regex]::Replace($text, "a\.download = 'SONIC170_solder_v[^']*\.bin'", "a.download = 'SONIC170_solder_v$Ver.bin'")
# HTML fallback 按钮文字（无 i18n 时的默认）
$text = $text.Replace('Download Firmware (4.9.2)', "Download Firmware ($Ver)").Replace('Download Solder Firmware (4.9.3)', "Download Solder Firmware ($Ver)")
$text = $text.Replace('下载热插拔固件 (4.9.2)', "下载热插拔固件 ($Ver)").Replace('下载焊接固件 (4.9.3)', "下载焊接固件 ($Ver)")

# 4. 写回（UTF-8 无 BOM）
[IO.File]::WriteAllText($Html, $text, (New-Object Text.UTF8Encoding($false)))
Write-Host "[embed-fw] 内嵌完成：FW_DL_B64/FW_DL_B64_SOLDER/EMBED_FW_VERSION/下载名/按钮文字 已同步 v$Ver"
