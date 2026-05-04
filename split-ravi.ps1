param(
  [string]$Source = "2023.03.27 70mm 1500 0.5 1.ravi",
  [long]$ChunkSize = 1800MB
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Source)) {
  throw "Source not found: $Source"
}
$srcFull = (Resolve-Path -LiteralPath $Source).Path
$dir     = Split-Path -Parent $srcFull
$leaf    = Split-Path -Leaf   $srcFull
$total   = (Get-Item -LiteralPath $srcFull).Length
$totalGB = [math]::Round($total/1GB, 2)
"Source : $leaf  ($totalGB GB)" | Write-Host
"Chunk  : $([math]::Round($ChunkSize/1MB,0)) MB" | Write-Host

$bufSize = 8MB
$buffer  = New-Object byte[] $bufSize
$fs      = [IO.File]::OpenRead($srcFull)
$idx     = 1
$swAll   = [Diagnostics.Stopwatch]::StartNew()
try {
  while ($fs.Position -lt $fs.Length) {
    $partName = Join-Path $dir ("{0}.part{1:D2}" -f $leaf, $idx)
    $out = [IO.File]::Create($partName)
    $sw  = [Diagnostics.Stopwatch]::StartNew()
    $written = [long]0
    try {
      while ($written -lt $ChunkSize -and $fs.Position -lt $fs.Length) {
        $remainChunk = $ChunkSize - $written
        $toRead = [Math]::Min([long]$buffer.Length, $remainChunk)
        $toRead = [Math]::Min($toRead, $fs.Length - $fs.Position)
        $read   = $fs.Read($buffer, 0, [int]$toRead)
        if ($read -le 0) { break }
        $out.Write($buffer, 0, $read)
        $written += $read
      }
    } finally {
      $out.Flush()
      $out.Close()
    }
    $sw.Stop()
    $mb = [math]::Round($written/1MB, 2)
    $sec= [math]::Round($sw.Elapsed.TotalSeconds,1)
    "  part{0:D2}: {1} MB in {2}s ({3} MB/s)  -> {4}" -f `
      $idx, $mb, $sec, ([math]::Round($mb/[math]::Max($sec,0.001),1)),
      (Split-Path -Leaf $partName) | Write-Host
    $idx++
  }
} finally {
  $fs.Close()
}
$swAll.Stop()
"Done in {0:N1}s, {1} parts." -f $swAll.Elapsed.TotalSeconds, ($idx-1) | Write-Host
