param(
  [string]$Output = "2023.03.27 70mm 1500 0.5 1.ravi"
)

$ErrorActionPreference = 'Stop'
$pattern = "$Output.part*"
$parts   = Get-ChildItem -LiteralPath . -Filter $pattern | Sort-Object Name
if ($parts.Count -eq 0) { throw "No parts matching '$pattern' found in current directory." }

"Merging $($parts.Count) parts -> $Output" | Write-Host
if (Test-Path -LiteralPath $Output) { Remove-Item -LiteralPath $Output -Force }

$out = [IO.File]::Create((Join-Path (Get-Location) $Output))
$bufSize = 8MB
$buffer  = New-Object byte[] $bufSize
$total   = [long]0
$sw      = [Diagnostics.Stopwatch]::StartNew()
try {
  foreach ($p in $parts) {
    $fs = [IO.File]::OpenRead($p.FullName)
    try {
      while (($read = $fs.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $out.Write($buffer, 0, $read)
        $total += $read
      }
    } finally { $fs.Close() }
    "  + {0}  ({1:N2} MB)" -f $p.Name, ($p.Length/1MB) | Write-Host
  }
} finally {
  $out.Flush(); $out.Close()
}
$sw.Stop()
"Done: {0:N2} GB written in {1:N1}s" -f ($total/1GB), $sw.Elapsed.TotalSeconds | Write-Host
