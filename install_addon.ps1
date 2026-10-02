param(
    [Parameter(Mandatory = $true)][string]$GameFolder,
    [Parameter(Mandatory = $true)][string]$PythonExe,
    [string]$ArchivePath,
    [string]$ResourceArchivePath
)

$ErrorActionPreference = 'Stop'
$commit = '2c45e6b269e5b1c0a37f46b433749b12ede0744e'
$expectedHash = 'E6C14FE8F04C0E961A488FEF99C56D511ED79D2E64DE7388AD2547167ED63446'
$url = "https://codeload.github.com/awfeel7/Scaleform-UI-CSGO/zip/$commit"
$prefix = "Scaleform-UI-CSGO-$commit/"
$addonsDir = [IO.Path]::GetFullPath((Join-Path $GameFolder 'migi\csgo\addons'))
$destination = Join-Path $addonsDir 'p_scaleform'

if (-not (Test-Path -LiteralPath $addonsDir -PathType Container)) {
    throw "MIGI addons folder not found: $addonsDir. Open MIGI once first."
}
if (Test-Path -LiteralPath $destination) {
    throw "The addon folder already exists; refusing to overwrite it: $destination"
}

$temporaryDownload = $null
try {
    if (-not $ArchivePath) {
        $temporaryDownload = Join-Path $env:TEMP ("scaleform-addon-" + [guid]::NewGuid().ToString('N') + '.zip')
        Write-Host "Downloading the pinned UI addon directly from $url"
        Invoke-WebRequest -Uri $url -OutFile $temporaryDownload -UseBasicParsing
        $ArchivePath = $temporaryDownload
    }
    $actualHash = (Get-FileHash -LiteralPath $ArchivePath -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) { throw "Addon download hash mismatch; refusing to install: $actualHash" }
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $selected = @($archive.Entries | Where-Object {
            $_.FullName.StartsWith($prefix, [StringComparison]::Ordinal) -and
            ($_.FullName.Substring($prefix.Length).StartsWith('panorama/', [StringComparison]::Ordinal) -or
             $_.FullName.Substring($prefix.Length).StartsWith('materials/', [StringComparison]::Ordinal)) -and
            -not $_.FullName.EndsWith('/')
        })
        $panoramaCount = @($selected | Where-Object { $_.FullName.Substring($prefix.Length).StartsWith('panorama/') }).Count
        $materialsCount = $selected.Count - $panoramaCount
        if ($panoramaCount -lt 700 -or $materialsCount -lt 100) {
            throw "Addon archive is incomplete ($panoramaCount Panorama files, $materialsCount material files)."
        }

        $staging = Join-Path $addonsDir ("p_scaleform-install-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $staging | Out-Null
        $stagingRoot = [IO.Path]::GetFullPath($staging) + [IO.Path]::DirectorySeparatorChar
        foreach ($entry in $selected) {
            $relative = $entry.FullName.Substring($prefix.Length)
            $parts = $relative.Split('/')
            if ($parts | Where-Object { $_ -in @('', '.', '..') -or $_.Contains(':') }) {
                throw "Unsafe path in addon archive: $relative"
            }
            $target = [IO.Path]::GetFullPath((Join-Path $staging ($relative.Replace('/', '\'))))
            if (-not $target.StartsWith($stagingRoot, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Unsafe extraction target: $target"
            }
            $parent = Split-Path -Parent $target
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
            $inputStream = $entry.Open()
            try {
                $outputStream = [IO.File]::Create($target)
                try { $inputStream.CopyTo($outputStream) }
                finally { $outputStream.Dispose() }
            } finally { $inputStream.Dispose() }
        }
        foreach ($part in @('layout', 'scripts', 'styles')) {
            if (-not (Test-Path -LiteralPath (Join-Path $staging "panorama\$part") -PathType Container)) {
                throw "Downloaded addon is missing panorama/$part. Staging folder: $staging"
            }
        }
        $pythonArgs = if ([IO.Path]::GetFileName($PythonExe) -ieq 'py.exe') { @('-3') } else { @() }
        & $PythonExe @pythonArgs (Join-Path $PSScriptRoot 'apply_addon_patch.py') --addon (Join-Path $staging 'panorama') --patch (Join-Path $PSScriptRoot 'addon-patch.json')
        if ($LASTEXITCODE -ne 0) { throw "Addon compatibility patch failed. Staging folder: $staging" }
        & (Join-Path $PSScriptRoot 'install_resources.ps1') -StagingFolder $staging -ArchivePath $ResourceArchivePath
        '{"name":"Scaleform-style UI (Panorama Bridge)","author":"awfeel7; based on abandonedpools; local bridge patches"}' |
            Set-Content -LiteralPath (Join-Path $staging 'addon.json') -Encoding ASCII
        if (Test-Path -LiteralPath $destination) { throw "Addon appeared during install; staging folder: $staging" }
        Rename-Item -LiteralPath $staging -NewName 'p_scaleform'
        Write-Host "Installed $panoramaCount Panorama files and $materialsCount material files from awfeel7's pinned addon." -ForegroundColor Green
        Write-Host 'No HLAE folder or original game ZIP from that repository was installed.'
        Write-Host 'Open MIGI and click Build / Update Build before launching CS:GO.' -ForegroundColor Yellow
    } finally { $archive.Dispose() }
} finally {
    if ($temporaryDownload -and (Test-Path -LiteralPath $temporaryDownload -PathType Leaf)) {
        Remove-Item -LiteralPath $temporaryDownload -Force
    }
}
