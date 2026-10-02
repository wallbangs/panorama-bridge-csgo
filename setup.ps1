param(
    [string]$GameFolder,
    [string]$OriginalZip,
    [string]$AddonFolder,
    [string]$PythonExe
)

$ErrorActionPreference = 'Stop'
$bridgeFolder = $PSScriptRoot
$configFile = Join-Path $bridgeFolder 'local-settings.json'

function Ask-ForPath([string]$label, [string]$suggestion) {
    Write-Host "`n$label"
    $answer = Read-Host "Path (Enter for $suggestion)"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $suggestion }
    return $answer.Trim('"')
}

try {
    Write-Host 'Panorama Bridge - first-time setup' -ForegroundColor Cyan
    Write-Host 'Only your local game/addon files are used. No game files are uploaded.'

    if (-not $GameFolder) {
        $steamRoot = 'C:\Program Files (x86)\Steam'
        try {
            $steamKey = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop
            if ($steamKey.SteamPath) { $steamRoot = $steamKey.SteamPath }
        } catch { }
        $guess = Join-Path $steamRoot 'steamapps\common\Counter-Strike Global Offensive'
        $GameFolder = Ask-ForPath 'Folder containing legacy csgo.exe:' $guess
    }
    $GameFolder = [IO.Path]::GetFullPath($GameFolder)
    $gameExe = Join-Path $GameFolder 'csgo.exe'
    $migiExe = Join-Path $GameFolder 'migi.exe'
    if (-not (Test-Path -LiteralPath $gameExe -PathType Leaf)) { throw "Legacy csgo.exe not found: $gameExe" }
    if (-not (Test-Path -LiteralPath $migiExe -PathType Leaf)) { throw "MIGI is missing beside csgo.exe: $migiExe" }

    if (-not $AddonFolder) {
        $guess = Join-Path $GameFolder 'migi\csgo\addons\p_scaleform\panorama'
        $AddonFolder = Ask-ForPath 'Scaleform addon panorama folder (contains layout, scripts, styles):' $guess
    }
    $AddonFolder = [IO.Path]::GetFullPath($AddonFolder)
    foreach ($part in @('layout', 'scripts', 'styles')) {
        if (-not (Test-Path -LiteralPath (Join-Path $AddonFolder $part) -PathType Container)) {
            throw "Addon folder is incomplete: $AddonFolder (missing $part)"
        }
    }

    if (-not $OriginalZip) {
        $localOriginal = Join-Path $bridgeFolder 'panorama.org.zip'
        $hlaeOriginal = Join-Path $env:APPDATA 'HLAE\panorama.org.zip'
        $guess = if (Test-Path -LiteralPath $localOriginal -PathType Leaf) { $localOriginal }
                 elseif (Test-Path -LiteralPath $hlaeOriginal -PathType Leaf) { $hlaeOriginal }
                 else { $localOriginal }
        $OriginalZip = Ask-ForPath 'Original Panorama ZIP (captured locally on first launch; existing HLAE ZIP also works):' $guess
    }
    $OriginalZip = [IO.Path]::GetFullPath($OriginalZip)

    $pythonArgs = @()
    if (-not $PythonExe) {
        foreach ($candidate in @('py.exe', 'python.exe')) {
            $command = Get-Command $candidate -ErrorAction SilentlyContinue
            if (-not $command) { continue }
            $versionArgs = if ($candidate -eq 'py.exe') { @('-3', '--version') } else { @('--version') }
            $version = & $command.Source @versionArgs 2>$null
            if ($LASTEXITCODE -eq 0 -and $version -match '^Python 3\.') {
                $PythonExe = $command.Source
                if ($candidate -eq 'py.exe') { $pythonArgs = @('-3') }
                break
            }
        }
    }
    if (-not $PythonExe) { throw 'Python 3 not found. Install Python 3, then run Setup.cmd again.' }
    if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) { throw "Python executable not found: $PythonExe" }
    if ([IO.Path]::GetFileName($PythonExe) -ieq 'py.exe') { $pythonArgs = @('-3') }
    $version = & $PythonExe @pythonArgs --version
    if ($LASTEXITCODE -ne 0 -or $version -notmatch '^Python 3\.') { throw 'A working Python 3 executable is required.' }

    $builder = Join-Path $bridgeFolder 'build_archive.py'
    $output = Join-Path $bridgeFolder 'panorama.my.zip'
    foreach ($name in @('PanoramaBridge32.dll', 'panorama-inject32.exe', 'enable-replacement.flag')) {
        if (-not (Test-Path -LiteralPath (Join-Path $bridgeFolder $name) -PathType Leaf)) {
            throw "Bridge file missing: $name"
        }
    }
    @{ GameFolder = $GameFolder; OriginalZip = $OriginalZip; AddonFolder = $AddonFolder; PythonExe = $PythonExe } |
        ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding UTF8
    if (-not (Test-Path -LiteralPath $OriginalZip -PathType Leaf)) {
        Write-Host "`nNo original ZIP yet. Run Launch.cmd once to capture it from your game." -ForegroundColor Yellow
        Write-Host 'The first launch uses the normal UI. Close the game, then run Launch.cmd again for the classic UI.'
        exit 0
    }
    Write-Host "`nBuilding your local archive..." -ForegroundColor Cyan
    & $PythonExe @pythonArgs $builder --original $OriginalZip --addon $AddonFolder --output $output
    if ($LASTEXITCODE -ne 0) { throw 'Archive builder failed. Check the paths and run Setup.cmd again.' }
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) { throw 'Builder did not create panorama.my.zip.' }

    Write-Host "`nReady! Run Launch.cmd after MIGI Build / Update Build." -ForegroundColor Green
    Write-Host 'Keep local-settings.json and panorama.my.zip on your PC; do not upload them.'
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
