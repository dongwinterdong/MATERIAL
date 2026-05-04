<#
.SYNOPSIS
  一键把当前仓库（含 LFS 大文件）推送到 GitHub，带进度指示。

.DESCRIPTION
  - 临时把 PAT 注入 origin URL 用作身份验证；推送结束（无论成功/失败/Ctrl-C）会在 finally 里还原
    URL，保证 token 不会残留在 .git/config 里。
  - 分两步：先 git lfs push --all 上传 LFS 对象，再 git push 推送提交，方便看进度。
  - 用 Start-Process -NoNewWindow 让 git 直接绑定到当前 console，LFS / push 的进度条
    （'\r' 重写）能正常显示。

.PARAMETER Token
  GitHub Personal Access Token（需要 repo 写权限）。也可以通过 $env:GITHUB_TOKEN 提供。

.PARAMETER Branch
  分支名，默认 main。

.PARAMETER RepoUrl
  仓库 HTTPS URL（不含 token），默认 dongwinterdong/MATERIAL。

.EXAMPLE
  .\Push-Repo.ps1 -Token ghp_xxxxxxxxxxxxxxxxxxxx

.EXAMPLE
  $env:GITHUB_TOKEN = 'ghp_xxxx'
  .\Push-Repo.ps1
#>
[CmdletBinding()]
param(
  [string]$Token   = $env:GITHUB_TOKEN,
  [string]$Branch  = 'main',
  [string]$RepoUrl = 'https://github.com/dongwinterdong/MATERIAL.git'
)

$ErrorActionPreference = 'Stop'

function Invoke-GitInline {
  param(
    [Parameter(Mandatory)][string[]]$GitArgs,
    [Parameter(Mandatory)][string]$Title
  )
  Write-Host "`n>>> $Title" -ForegroundColor Cyan
  Write-Host ("    git " + ($GitArgs -join ' ')) -ForegroundColor DarkGray
  $p = Start-Process -FilePath 'git' -ArgumentList $GitArgs -NoNewWindow -PassThru -Wait
  if ($p.ExitCode -ne 0) {
    throw ("git {0} 失败 (exit {1})" -f $GitArgs[0], $p.ExitCode)
  }
}

if (-not $Token) {
  throw '缺少 token。请用 -Token <PAT>，或先 $env:GITHUB_TOKEN = "<PAT>"。'
}
if (-not (Test-Path -LiteralPath '.git')) {
  throw '当前目录不是 git 仓库根（找不到 .git）。'
}

Write-Host '== 待推送的 LFS 对象 ==' -ForegroundColor Cyan
$lfsLines = git lfs ls-files --size
$lfsLines | ForEach-Object { Write-Host "  $_" }

$totalBytes = [long]0
foreach ($line in $lfsLines) {
  if ($line -match '\(([\d.]+)\s*([KMGT]?B)\)') {
    $val = [double]$Matches[1]
    $bytes = switch ($Matches[2]) {
      'B'  { $val }
      'KB' { $val * 1KB }
      'MB' { $val * 1MB }
      'GB' { $val * 1GB }
      'TB' { $val * 1TB }
      default { 0 }
    }
    $totalBytes += [long]$bytes
  }
}
Write-Host ("  -> 总计约 {0:N2} GB" -f ($totalBytes/1GB)) -ForegroundColor Cyan

if ($totalBytes -gt 1GB) {
  Write-Warning "GitHub 免费 LFS 配额是 1 GB 存储 + 1 GB/月带宽。本次约 $([math]::Round($totalBytes/1GB,2)) GB，超出后服务器会拒绝。请确认账户已购买 LFS 数据包，或先去 GitHub Billing 检查配额。"
}

$tokenUrl = $RepoUrl -replace '^https://', "https://x-access-token:$Token@"

Write-Host "`n临时把带 token 的 URL 写入 origin ..." -ForegroundColor DarkGray
$origExists = $true
try { $null = git remote get-url origin 2>$null } catch { $origExists = $false }
if ($origExists -and $LASTEXITCODE -eq 0) {
  git remote set-url origin $tokenUrl | Out-Null
} else {
  git remote add origin $tokenUrl | Out-Null
}

try {
  $env:GIT_LFS_PROGRESS = '1'

  Invoke-GitInline `
    -GitArgs @('lfs','push','--all','origin',$Branch) `
    -Title  ("Step 1/2: 上传 LFS 对象（约 {0:N2} GB）" -f ($totalBytes/1GB))

  Invoke-GitInline `
    -GitArgs @('push','-u','origin',$Branch,'--progress') `
    -Title  'Step 2/2: 推送 git 提交历史'

  Write-Host "`n推送完成。仓库：$RepoUrl" -ForegroundColor Green
}
finally {
  git remote set-url origin $RepoUrl | Out-Null
  Write-Host "(已还原 origin URL，token 不再保存在 .git/config 中)" -ForegroundColor DarkGray
}
