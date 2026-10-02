$ErrorActionPreference = 'Stop'
$bridgeFolder = $PSScriptRoot

try {
    $configFile = Join-Path $bridgeFolder 'local-settings.json'
    if (-not (Test-Path -LiteralPath $configFile -PathType Leaf)) { throw 'Run Setup.cmd first.' }
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    $gameExe = Join-Path $config.GameFolder 'csgo.exe'
    $injector = Join-Path $bridgeFolder 'panorama-inject32.exe'
    foreach ($file in @($gameExe, $injector, (Join-Path $bridgeFolder 'PanoramaBridge32.dll'), (Join-Path $bridgeFolder 'enable-replacement.flag'))) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing file: $file" }
    }
    if (Get-Process csgo -ErrorAction SilentlyContinue) { throw 'Close CS:GO before launching the Bridge.' }
    if (-not (Get-Process steam -ErrorAction SilentlyContinue)) { Write-Warning 'Steam does not appear to be running. Start Steam first if CS:GO does not launch.' }

    $output = Join-Path $bridgeFolder 'panorama.my.zip'
    if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
        if (Test-Path -LiteralPath $config.OriginalZip -PathType Leaf) {
            Write-Host 'Original archive found. Building the classic UI now...' -ForegroundColor Cyan
            & (Join-Path $bridgeFolder 'setup.ps1') -GameFolder $config.GameFolder -OriginalZip $config.OriginalZip -AddonFolder $config.AddonFolder -PythonExe $config.PythonExe
            if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $output -PathType Leaf)) { throw 'UI archive build failed. Run Setup.cmd to see the error.' }
        } else {
            Write-Host 'First launch: capturing the original archive from your own game.' -ForegroundColor Yellow
            Write-Host 'This launch uses the normal UI. Close CS:GO, then run Launch.cmd again.'
        }
    }

    Write-Host 'Starting the Bridge injector, then legacy CS:GO...' -ForegroundColor Cyan
    Start-Process -FilePath $injector -ArgumentList 'csgo.exe' -WorkingDirectory $bridgeFolder
    Start-Process -FilePath $gameExe -ArgumentList @('-insecure', '-game', 'migi/csgo', '-console') -WorkingDirectory $config.GameFolder
    Write-Host 'Check the game HUD in a local map. Do not use VAC-protected servers.'
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
