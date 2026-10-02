param(
    [Parameter(Mandatory = $true)][string]$StagingFolder,
    [string]$ArchivePath
)

$ErrorActionPreference = 'Stop'
$commit = '3e4c1f244351844a6236d952356ea087f59ad29e'
$expectedHash = 'E2215E9D8745A763CF058F3D1820EE937563E6A1DD459D0D940267DF82F1FD73'
$url = "https://codeload.github.com/abandonedpools/scaleform/zip/$commit"
$prefix = "scaleform-$commit/p_scaleform/resource/"
$staging = [IO.Path]::GetFullPath($StagingFolder)
if (-not (Test-Path -LiteralPath $staging -PathType Container)) { throw "Staging folder not found: $staging" }
$stagingRoot = $staging + [IO.Path]::DirectorySeparatorChar

$temporaryDownload = $null
try {
    if (-not $ArchivePath) {
        $temporaryDownload = Join-Path $env:TEMP ("scaleform-resources-" + [guid]::NewGuid().ToString('N') + '.zip')
        Write-Host "Downloading pinned original Scaleform resources from $url"
        Invoke-WebRequest -Uri $url -OutFile $temporaryDownload -UseBasicParsing
        $ArchivePath = $temporaryDownload
    }
    $actualHash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) { throw "Resource archive hash mismatch; refusing to install: $actualHash" }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $selected = @($archive.Entries | Where-Object {
            $_.FullName.StartsWith($prefix, [StringComparison]::Ordinal) -and -not $_.FullName.EndsWith('/')
        })
        if ($selected.Count -ne 68) { throw "Expected 68 Scaleform resource files; found $($selected.Count)" }
        foreach ($entry in $selected) {
            $relative = $entry.FullName.Substring($prefix.Length)
            $parts = $relative.Split('/')
            if ($parts | Where-Object { $_ -in @('', '.', '..') -or $_.Contains(':') }) {
                throw "Unsafe resource path: $relative"
            }
            $target = [IO.Path]::GetFullPath((Join-Path $staging ("resource\" + $relative.Replace('/', '\'))))
            if (-not $target.StartsWith($stagingRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Unsafe resource target: $target"
            }
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            $inputStream = $entry.Open()
            try {
                $outputStream = [IO.File]::Create($target)
                try { $inputStream.CopyTo($outputStream) }
                finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
        }
        Write-Host "Installed $($selected.Count) resource files from the original Scaleform addon." -ForegroundColor Green
    } finally { $archive.Dispose() }
} finally {
    if ($temporaryDownload -and (Test-Path -LiteralPath $temporaryDownload -PathType Leaf)) {
        Remove-Item -LiteralPath $temporaryDownload -Force
    }
}
