param([string]$Executable = '', [switch]$Source, [switch]$Visible)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$oldApp = $env:APPDATA; $oldLocal = $env:LOCALAPPDATA; $oldSave = $env:FACTORY_SAVE_DIR
$oldEvidence=$env:FACTORY_EVIDENCE
try {
    New-Item -ItemType Directory -Force output/appdata,output/localappdata,output/acceptance-save | Out-Null
    $env:APPDATA = (Resolve-Path output/appdata).Path
    $env:LOCALAPPDATA = (Resolve-Path output/localappdata).Path
    $env:FACTORY_SAVE_DIR = (Resolve-Path output/acceptance-save).Path
    $env:GUA_BRIDGE_PORT = '18241'
    $env:GUA_BRIDGE_URL = 'ws://127.0.0.1:18241'
    if (Get-NetTCPConnection -LocalPort 18241 -State Listen -ErrorAction SilentlyContinue) { throw 'Dedicated port 18241 is already occupied; stop only your own previous host.' }
    $arguments = @('--log-file',(Join-Path $root 'output/acceptance-host.log'))
    if (-not $Visible) { $arguments = @('--headless') + $arguments }
    if ($Source) { $Executable = (Get-Command Godot_v4.7-stable_win64_console.exe).Source; $arguments += @('--path',$root) }
    elseif (-not $Executable) { $Executable = Join-Path $root 'build/windows/DeliveryFactory.exe' }
    $kind = if ($Source) { 'source' } else { 'exe' }
    $env:FACTORY_EVIDENCE = Join-Path $root ('output/runs/' + (Get-Date -Format 'yyyyMMddTHHmmssfff') + '-' + $kind)
    $env:FACTORY_BUILD_SHA256 = if ($Source) { 'source' } else { (Get-FileHash $Executable -Algorithm SHA256).Hash.ToLowerInvariant() }
    $env:FACTORY_COMMIT = (git rev-parse --verify HEAD 2>$null)
    $env:FACTORY_SOURCE_SHA256 = (Get-FileHash scripts/main.gd -Algorithm SHA256).Hash.ToLowerInvariant() + ':' + (Get-FileHash scripts/factory.gd -Algorithm SHA256).Hash.ToLowerInvariant()
    $arguments += @('--','--fixed-clock')
    $hostArgs = @{FilePath=$Executable; ArgumentList=$arguments; PassThru=$true}
    if (-not $Visible) { $hostArgs.WindowStyle='Hidden' }
    $process = Start-Process @hostArgs
    try {
        Start-Sleep -Seconds 2
        node tests/exe-acceptance.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Gua acceptance failed' }
        node tests/exploration.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Gua exploratory and B03 comparison failed' }
        node tests/boundaries.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Gua edge/death-pause boundary checks failed' }
    } finally { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
    $process = Start-Process @hostArgs
    try {
        Start-Sleep -Seconds 2
        node tests/restart-check.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Save restore after restart failed' }
    } finally { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
    $hostArgs.ArgumentList = $arguments | Where-Object { $_ -ne '--fixed-clock' }
    $process = Start-Process @hostArgs
    try {
        Start-Sleep -Seconds 2
        node tests/realtime.mjs
        if ($LASTEXITCODE -ne 0) { throw 'Real-time EXE route failed' }
    } finally { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
} finally { $env:APPDATA=$oldApp; $env:LOCALAPPDATA=$oldLocal; $env:FACTORY_SAVE_DIR=$oldSave; $env:FACTORY_EVIDENCE=$oldEvidence; Pop-Location }
