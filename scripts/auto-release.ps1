# sonic170 自动发布脚本
# 用途：post-commit 钩子调用。检测 4 个固件产物（hotswap bin / solder bin / 两个 via json）
#       是否比 GitHub 最新 release 新 —— 有新则：push → 创建/更新 release（4 资产）→
#       同步 latest.json（jsDelivr 源）→ push origin + gitee 镜像。
# 依赖：环境变量 GITHUB_PAT（GitHub API token，需 repo 权限）
# PS5.1 坑：ErrorActionPreference=Stop 时 native 命令（git/curl）写 stderr 会抛 NativeCommandError。
# 用 Continue + $LASTEXITCODE / try-catch 显式判断。
$ErrorActionPreference = 'Continue'
if ($env:SONIC_AUTO_RELEASE_SKIP -eq '1') { exit 0 }   # 防递归：脚本自身 commit 时跳过

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Owner = '709208969'
$Repo  = 'sonic170-v2'
$Pat   = $env:GITHUB_PAT
if (-not $Pat) { Write-Host '[auto-release] 未设置 GITHUB_PAT，跳过'; exit 0 }

$Api  = "https://api.github.com/repos/$Owner/$Repo"
$Up   = "https://uploads.github.com/repos/$Owner/$Repo"
$Hdr  = @{ Authorization = "Bearer $Pat"; 'User-Agent' = 'sonic170-autopublish' }

# 1. 定位 4 个产物文件（按名字倒序取最新一份）
$Globs = @('SONIC170_hotswap_v*.bin', 'SONIC170_solder_v*.bin', 'sonic170_via_hotswap.json', 'sonic170_via_solder.json')
$Files = @()
foreach ($g in $Globs) {
  $f = Get-ChildItem -Path $Root -Filter $g -File | Sort-Object Name -Descending | Select-Object -First 1
  if ($f) { $Files += $f }
}
if ($Files.Count -lt 4) {
  Write-Host ("[auto-release] 产物不全（{0}），跳过" -f (($Files | ForEach-Object Name) -join ', ')); exit 0
}

# 2. 版本号：从 hotswap bin 文件名提取 v4.9.2（兼容 _20260820_1921 老命名）
$HotswapBin = $Files | Where-Object { $_.Name -match '^SONIC170_hotswap_v' } | Select-Object -First 1
$Ver = [regex]::Match($HotswapBin.Name, 'v(\d+\.\d+\.\d+)').Groups[1].Value
if (-not $Ver) { Write-Host '[auto-release] 无法从文件名提取版本号，跳过'; exit 0 }
$Tag = "v$Ver"
Write-Host "[auto-release] 检测版本 $Tag"

# 3. 4 文件最近 git 提交时间（unix 秒）→ 判定"有没有日期变更"
$NewestTs = 0
foreach ($f in $Files) {
  $ts = git log -1 --format=%ct -- $f.Name 2>$null
  if ($ts -match '^\d+$') {
    $tsInt = [int64]$ts
    if ($tsInt -gt $NewestTs) { $NewestTs = $tsInt }
  }
}
if ($NewestTs -eq 0) { Write-Host '[auto-release] 产物无 git 提交记录，跳过'; exit 0 }
$FileTime = [DateTimeOffset]::FromUnixTimeSeconds($NewestTs)

# 4. 查 GitHub 最新 release
$Latest = $null
try { $Latest = Invoke-RestMethod -Uri "$Api/releases/latest" -Headers $Hdr } catch { }
if ($Latest) {
  $RelTime = [DateTimeOffset]::Parse($Latest.published_at)
  if ($RelTime -gt $FileTime) {
    Write-Host "[auto-release] 无新产物（release $($Latest.tag_name) 比产物新），跳过"
    exit 0
  }
}

# 5. push 当前分支（release tag 需指向已推送的 commit）
#    自动化环境无交互：直接用 GITHUB_PAT 认证推送，避免 GCM 弹窗/挂起
Write-Host '[auto-release] push origin...'
$basic = 'x-access-token:' + $Pat
$b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($basic))
git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $b64" push "https://github.com/$Owner/$Repo.git" HEAD 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host '[auto-release] push origin 失败，中止'; exit 1 }

# 6. 创建或更新 release
if ($Latest -and $Latest.tag_name -eq $Tag) {
  $RelId = $Latest.id
  Write-Host "[auto-release] 更新已有 release $Tag"
  $patchBody = @{ body = "sonic170 v$Ver auto release" } | ConvertTo-Json
  try {
    Invoke-RestMethod -Method Patch -Uri "$Api/releases/$RelId" -Headers $Hdr -ContentType 'application/json' -Body $patchBody | Out-Null
  } catch { Write-Host "[auto-release] PATCH release 失败: $_" }
  foreach ($a in $Latest.assets) {
    curl.exe -s -X DELETE -H "Authorization: Bearer $Pat" "$Api/releases/assets/$($a.id)" 2>$null | Out-Null
  }
} else {
  Write-Host "[auto-release] 创建 release $Tag"
  $body = @{
    tag_name         = $Tag
    name             = $Tag
    body             = "sonic170 v$Ver auto release"
    target_commitish = 'main'
    draft            = $false
    prerelease       = $false
  } | ConvertTo-Json
  $Created = Invoke-RestMethod -Method Post -Uri "$Api/releases" -Headers $Hdr -ContentType 'application/json' -Body $body
  $RelId = $Created.id
}

# 7. 上传 4 个资产
foreach ($f in $Files) {
  curl.exe -s -X POST -H "Authorization: Bearer $Pat" -H "Content-Type: application/octet-stream" `
    --data-binary "@$($f.FullName)" "$Up/releases/$RelId/assets?name=$($f.Name)" 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Host "  asset 上传失败: $($f.Name)" }
  else { Write-Host "  asset: $($f.Name) ($($f.Length) B)" }
}

# 8. 同步 latest.json（4 文件 + dfu 驱动包，若存在）
$List = @($Files | ForEach-Object { $_.Name })
$Zip = Get-ChildItem -Path $Root -Filter 'sonic170_dfu_driver.zip' -File | Select-Object -First 1
if ($Zip) { $List += $Zip.Name }
$Lj = @{ version = $Ver; files = $List } | ConvertTo-Json
[System.IO.File]::WriteAllText("$Root\latest.json", $Lj, (New-Object System.Text.UTF8Encoding($false)))

git add latest.json
$env:SONIC_AUTO_RELEASE_SKIP = '1'
git commit -m "chore: latest.json 同步 v$Ver（自动发布）" 2>$null
git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $b64" push "https://github.com/$Owner/$Repo.git" HEAD 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host '[auto-release] push latest.json 失败' }
# gitee 镜像（凭据不可自动化时快速失败，不阻塞主流程）
$env:GCM_INTERACTIVE = 'Never'
git push gitee HEAD 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host '[auto-release] gitee push 失败（忽略）' }
Remove-Item Env:SONIC_AUTO_RELEASE_SKIP
Remove-Item Env:GCM_INTERACTIVE

# 9. jsDelivr purge——发布即刷新 CDN（@main 路径默认缓存 12h，不 purge 则国内用户
#    12h 内检测不到网页/固件更新；公开 purge API 无需 token）
try {
  $PurgeBody = @{ path = @("/gh/$Owner/$Repo@main/sonic170v2-rgb-control.html", "/gh/$Owner/$Repo@main/latest.json") } | ConvertTo-Json
  $PurgeResp = Invoke-RestMethod -Method Post -Uri 'https://purge.jsdelivr.net/' -ContentType 'application/json' -Body $PurgeBody -TimeoutSec 30
  Write-Host "[auto-release] jsDelivr purge 已提交: $($PurgeResp | ConvertTo-Json -Compress)"
} catch {
  Write-Host "[auto-release] jsDelivr purge 失败（忽略）: $_"
}

Write-Host "[auto-release] 完成：$Tag 已发布 + latest.json 已同步"
