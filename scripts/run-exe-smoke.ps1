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
        $identityLines = @(Get-Content $log | Where-Object { $_.StartsWith('FACTORY_GUA_BUILD_INFO=') })
        if ($identityLines.Count -ne 1) { throw 'Missing or ambiguous compiled Gua identity' }
        $identity = $identityLines[0].Substring('FACTORY_GUA_BUILD_INFO='.Length) | ConvertFrom-Json
        if ($identity.schemaVersion -ne 1 -or $identity.flavor -ne 'development' -or $identity.configuration -ne 'Release' -or
            $identity.remoteEnabled -ne $true -or $identity.remotePermissionCeiling -ne 'debug' -or
            $identity.sourceCommit -ne '2e12fb3cfdf822418f349515027d6f620c5ee63b' -or $identity.buildId -ne $identity.sourceCommit -or
            'websocket' -notin $identity.transports) { throw 'Unexpected compiled Gua variant/source identity' }
        $package = Split-Path -Parent $Executable
        $dll = Join-Path $package 'gua_godot.windows.release.x86_64.dll'
        $officialDll = Join-Path $root 'addons/gua/bin/gua_godot.windows.release.x86_64.dll'
        if ((Get-FileHash $dll).Hash -ne (Get-FileHash $officialDll).Hash) { throw 'Packaged Gua DLL differs from verified addon' }
        $allowed = @('DeliveryFactory.exe','gua_godot.windows.release.x86_64.dll','README.md','OFL-MPLUS1p.txt','LICENSE','sample-build-manifest.json')
        $files = @(Get-ChildItem $package -File | Where-Object Name -ne 'sample-build-manifest.json')
        if (@(Get-ChildItem $package | Where-Object { $_.PSIsContainer -or $_.Name -notin $allowed }).Count) { throw 'Unexpected package contents' }
        # This sample manifest records observed identity and hashes. It is not an
        # upstream Gua distribution manifest or a Playtest Run/Trace attestation.
        [ordered]@{ schemaVersion = 1; purpose = 'QA sample using public Development remote-ON SDK';
            guaVersion = '1.2.0'; addonArchiveSha256 = 'effcad4cfc6083528bee4e469e171047cd9d2d49547a09d16be04845fcda7873';
            gameCommit = (git -C $root rev-parse HEAD); workingTreeDirty = [bool](git -C $root status --porcelain);
            compiledGua = $identity; files = @($files | Sort-Object Name | ForEach-Object {
                @{ path = $_.Name; sha256 = (Get-FileHash $_.FullName).Hash.ToLowerInvariant() }
            }) } | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $package 'sample-build-manifest.json')
        Get-FileHash $Executable -Algorithm SHA256 | Format-List | Out-File (Join-Path $directory 'exe-sha256.txt')
        Write-Host "Distribution startup smoke passed: $directory (not Playtest E2E)"
    } finally {
        if (-not $process.HasExited) { $process.Kill(); $process.WaitForExit(5000) | Out-Null }
        $process.Dispose()
    }
} finally { foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key]) } }
