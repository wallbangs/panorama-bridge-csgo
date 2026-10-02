$ErrorActionPreference = 'Stop'
$bridgeFolder = $PSScriptRoot

try {
    $configFile = Join-Path $bridgeFolder 'local-settings.json'
    if (-not (Test-Path -LiteralPath $configFile -PathType Leaf)) { throw 'Run Setup.cmd first.' }
    $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
    $gameExe = Join-Path $config.GameFolder 'csgo.exe'
    $injector = Join-Path $bridgeFolder 'panorama-inject32.exe'
    foreach ($file in @($gameExe, $injector, (Join-Path $bridgeFolder 'PanoramaBridge32.dll'), (Join-Path $bridgeFolder 'panorama.my.zip'), (Join-Path $bridgeFolder 'enable-replacement.flag'))) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing file: $file" }
    }
    if (Get-Process csgo -ErrorAction SilentlyContinue) { throw 'Close CS:GO before launching the Bridge.' }
    if (-not (Get-Process steam -ErrorAction SilentlyContinue)) { Write-Warning 'Steam does not appear to be running. Start Steam first if CS:GO does not launch.' }

    Write-Host 'Starting the Bridge injector, then legacy CS:GO...' -ForegroundColor Cyan
    Start-Process -FilePath $injector -ArgumentList 'csgo.exe' -WorkingDirectory $bridgeFolder
    Start-Process -FilePath $gameExe -ArgumentList @('-insecure', '-game', 'migi/csgo', '-console') -WorkingDirectory $config.GameFolder
    Write-Host 'Check the game HUD in a local map. Do not use VAC-protected servers.'
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
