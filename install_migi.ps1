param(
    [Parameter(Mandatory = $true)][string]$GameFolder,
    [string]$SourceFile
)

$ErrorActionPreference = 'Stop'
$commit = '8811529ee5a919f481119ee8f131368e82081c1f'
$expectedHash = '091C500A3915A00219843026B7E33C287B1DFC1381230D51E427372FE61587D3'
$url = "https://raw.githubusercontent.com/ZooLSmith/MIGI3/$commit/migi.exe"
$destination = Join-Path ([IO.Path]::GetFullPath($GameFolder)) 'migi.exe'
if (Test-Path -LiteralPath $destination) { throw "Refusing to overwrite existing MIGI: $destination" }

$temporaryDownload = $null
try {
    if (-not $SourceFile) {
        $temporaryDownload = Join-Path $env:TEMP ("migi-" + [guid]::NewGuid().ToString('N') + '.exe')
        Write-Host "Downloading pinned MIGI directly from $url"
        Invoke-WebRequest -Uri $url -OutFile $temporaryDownload -UseBasicParsing
        $SourceFile = $temporaryDownload
    }
    $actualHash = (Get-FileHash -LiteralPath $SourceFile -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) { throw "MIGI download hash mismatch; refusing to install: $actualHash" }
    [IO.File]::Copy($SourceFile, $destination, $false)
    Write-Host "Installed official MIGI at $destination" -ForegroundColor Green
    Write-Host 'Run migi.exe as administrator once to initialize links, then run it normally and rerun Setup.cmd.' -ForegroundColor Yellow
} finally {
    if ($temporaryDownload -and (Test-Path -LiteralPath $temporaryDownload -PathType Leaf)) {
        Remove-Item -LiteralPath $temporaryDownload -Force
    }
}
