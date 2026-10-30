param([string]$Executable = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Executable) { $Executable = Join-Path $root 'build/windows/DeliveryFactory.exe' }
$directory = Join-Path $root ('output/distribution-smoke/' + (Get-Date -Format 'yyyyMMddTHHmmssfff'))
New-Item -ItemType Directory -Force $directory | Out-Null
$keys = @('FACTORY_SAVE_DIR','GUA_BRIDGE_PORT','APPDATA','LOCALAPPDATA')
$previous = @{}
foreach ($key in $keys) { $previous[$key] = [Environment]::GetEnvironmentVariable($key) }
try {
    if (Get-NetTCPConnection -LocalPort 18244 -State Listen -ErrorAction SilentlyContinue) { throw 'Smoke port 18244 occupied' }
    $env:FACTORY_SAVE_DIR = $directory
    $env:GUA_BRIDGE_PORT = '18244'
    $env:APPDATA = Join-Path $directory 'appdata'
    $env:LOCALAPPDATA = Join-Path $directory 'localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $log = Join-Path $directory 'startup.log'
    # Packaging smoke only: no movement, Goal evaluation, exploration, Run,
    # Trace, Recording, Replay, attach or replacement Playtest runner.
    $process = Start-Process $Executable -ArgumentList @('--headless','--quit-after','30','--log-file',$log) -WindowStyle Hidden -PassThru
    try {
        if (-not $process.WaitForExit(15000)) { throw 'EXE startup smoke did not exit' }
        if ($process.ExitCode -ne 0) { throw "EXE startup smoke exit=$($process.ExitCode)" }
        if (-not (Test-Path $log) -or (Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR:' -Quiet)) { throw 'EXE startup log missing or contains errors' }
        if (-not (Select-String -Path $log -SimpleMatch -Pattern 'FACTORY_READY' -Quiet)) { throw 'EXE did not reach its startup marker' }
        Get-FileHash $Executable -Algorithm SHA256 | Format-List | Out-File (Join-Path $directory 'exe-sha256.txt')
        Write-Host "Distribution startup smoke passed: $directory (not Playtest E2E)"
    } finally {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }
        $process.Dispose()
    }
} finally { foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key]) } }
