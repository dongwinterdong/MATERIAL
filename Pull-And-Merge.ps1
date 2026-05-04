<#
.SYNOPSIS
  一键克隆仓库 + 拉取 LFS 对象 + 合并 .ravi 分片。带进度指示。

.PARAMETER RepoUrl
  仓库 HTTPS URL，默认 dongwinterdong/MATERIAL。

.PARAMETER DestDir
  本地目标目录，默认 MATERIAL。

.PARAMETER SkipClone
  在已经 clone 好的仓库内运行，跳过 clone 步骤，只做 lfs pull + 合并。

.EXAMPLE
  # 在空目录里跑：
  .\Pull-And-Merge.ps1

.EXAMPLE
  # 已经 clone 过了，只想拉 LFS + 合并：
  cd MATERIAL
  ..\Pull-And-Merge.ps1 -SkipClone
#>
[CmdletBinding()]
param(
  [string]$RepoUrl = 'https://github.com/dongwinterdong/MATERIAL.git',
  [string]$DestDir = 'MATERIAL',
  [switch]$SkipClone
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

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw 'git 未安装或不在 PATH 中。请先安装 https://git-scm.com/'
}
if (-not (Get-Command git-lfs -ErrorAction SilentlyContinue)) {
  throw 'git-lfs 未安装。请先安装 https://git-lfs.com/ ，再 git lfs install。'
}

if (-not $SkipClone) {
  Invoke-GitInline -GitArgs @('lfs','install') -Title 'Step 1/4: 启用 Git LFS hooks'

  if (Test-Path -LiteralPath $DestDir) {
    throw "目标目录 $DestDir 已存在；删除它，或在该目录里加 -SkipClone 参数运行。"
  }

  Invoke-GitInline `
    -GitArgs @('clone','--progress',$RepoUrl,$DestDir) `
    -Title  ("Step 2/4: 克隆 {0} -> {1}（仅拉指针，<10 MB）" -f $RepoUrl, $DestDir)

  Set-Location -LiteralPath $DestDir
} else {
  Write-Host '跳过 clone（-SkipClone）。' -ForegroundColor DarkGray
  if (-not (Test-Path -LiteralPath '.git')) {
    throw '当前目录不是 git 仓库根（找不到 .git）。'
  }
}

Invoke-GitInline `
  -GitArgs @('lfs','pull') `
  -Title  'Step 3/4: 下载 LFS 对象（约 10 GB）'

Write-Host "`n>>> Step 4/4: 合并 .ravi 分片" -ForegroundColor Cyan
$mergeScript = Join-Path (Get-Location) 'merge-ravi.ps1'
if (-not (Test-Path -LiteralPath $mergeScript)) {
  throw "未找到 $mergeScript"
}
& powershell -NoProfile -ExecutionPolicy Bypass -File $mergeScript
if ($LASTEXITCODE -ne 0) { throw "merge-ravi.ps1 失败 (exit $LASTEXITCODE)" }

$mergedFile = '2023.03.27 70mm 1500 0.5 1.ravi'
if (Test-Path -LiteralPath $mergedFile) {
  $size = (Get-Item -LiteralPath $mergedFile).Length
  Write-Host ("`n全部完成。合并文件：{0}（{1:N2} GB）" -f $mergedFile, ($size/1GB)) -ForegroundColor Green
} else {
  Write-Warning "合并完成但找不到输出文件 $mergedFile"
}
