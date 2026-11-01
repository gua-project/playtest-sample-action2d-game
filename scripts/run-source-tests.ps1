param([string]$Godot = '', [switch]$Restore)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = (Get-Command Godot_v4.7-stable_win64.exe -ErrorAction Stop).Source }
$keys = @('GODOT_EXECUTABLE','FACTORY_PROJECT_DIR','NUGET_PACKAGES','DOTNET_CLI_HOME','DOTNET_GENERATE_ASPNET_CERTIFICATE','DOTNET_CLI_TELEMETRY_OPTOUT')
$previous = @{}
foreach ($key in $keys) { $previous[$key] = [Environment]::GetEnvironmentVariable($key) }
Push-Location $root
try {
    $env:GODOT_EXECUTABLE = $Godot
    $env:FACTORY_PROJECT_DIR = $root
    $env:NUGET_PACKAGES = Join-Path $root '.deps/nuget'
    $env:DOTNET_CLI_HOME = Join-Path $root 'output/dotnet-home'
    $env:DOTNET_GENERATE_ASPNET_CERTIFICATE = 'false'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
    if (Get-NetTCPConnection -LocalPort 18241 -State Listen -ErrorAction SilentlyContinue) { throw 'Source regression port 18241 is occupied.' }
    $project = 'tests/dotnet/Factory.Regression.Tests.csproj'
    if ($Restore) {
        dotnet restore $project --configfile NuGet.Config --locked-mode
        if ($LASTEXITCODE -ne 0) { throw 'Pinned Gua/NUnit restore failed' }
    }
    # Public test SDK packages intentionally contain Development/remote-ON natives.
    foreach ($id in @('gua.core','gua.testing','gua.testing.godot')) {
        [xml]$metadata = Get-Content (Join-Path $env:NUGET_PACKAGES "$id/1.2.0/$id.nuspec") -Raw
        $repository = $metadata.SelectSingleNode('//*[local-name()="repository"]')
        if ($repository.commit -ne '2e12fb3cfdf822418f349515027d6f620c5ee63b') { throw "Unexpected NuGet source: $id" }
    }
    $native = Join-Path $env:NUGET_PACKAGES 'gua.core/1.2.0/runtimes/win-x64/native'
    $manifest = Get-Content (Join-Path $native 'gua-core-build-manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.build.flavor -ne 'development' -or $manifest.build.remoteEnabled -ne $true -or
        $manifest.build.remotePermissionCeiling -ne 'debug' -or $manifest.build.sourceCommit -ne '2e12fb3cfdf822418f349515027d6f620c5ee63b') { throw 'Unexpected NuGet compiled build manifest' }
    $coreEntry = @($manifest.files | Where-Object path -eq 'gua.dll')
    if ($coreEntry.Count -ne 1 -or (Get-FileHash (Join-Path $native 'gua.dll')).Hash.ToLowerInvariant() -ne $coreEntry[0].sha256) { throw 'NuGet core native hash mismatch' }
    $results = 'output/source-regression-results/' + (Get-Date -Format 'yyyyMMddTHHmmssfff')
    dotnet test $project --no-restore --filter TestCategory=SourceRegression --logger 'trx;LogFileName=source-regression.trx' --results-directory $results
    if ($LASTEXITCODE -ne 0) { throw 'Source-scene Gua regression failed' }
} finally {
    Pop-Location
    foreach ($key in $keys) { [Environment]::SetEnvironmentVariable($key, $previous[$key]) }
}
