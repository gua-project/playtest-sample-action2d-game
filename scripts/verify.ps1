param([string]$Godot = 'Godot_v4.7-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
$oldApp = $env:APPDATA; $oldLocal = $env:LOCALAPPDATA
function Run-Godot([string[]]$Arguments) {
    $executable = (Get-Command $Godot -ErrorAction Stop).Source
    & $executable --disable-crash-handler @Arguments
    $engineExit = $LASTEXITCODE
    Write-Host "Godot exit=$engineExit args=$Arguments"
    if ($engineExit -ne 0) { throw "Godot failed: exit=$engineExit args=$Arguments" }
}
try {
    New-Item -ItemType Directory -Force output/appdata,output/localappdata,output/save | Out-Null
    $env:APPDATA = (Resolve-Path output/appdata).Path
    $env:LOCALAPPDATA = (Resolve-Path output/localappdata).Path
    Run-Godot -Arguments @('--headless','--path','.', '--editor','--import','--quit','--log-file','output/import.log')
    Run-Godot -Arguments @('--headless','--path','.', '--script','res://tests/model_tests.gd','--log-file','output/model-tests.log')
    Run-Godot -Arguments @('--headless','--path','.', '--script','res://tests/ui_tests.gd','--log-file','output/ui-tests.log')
    Run-Godot -Arguments @('--headless','--path','.', '--quit-after','5','--log-file','output/smoke.log')
    foreach ($log in @('output/import.log','output/model-tests.log','output/ui-tests.log','output/smoke.log')) {
        if (Select-String -Path $log -Pattern 'SCRIPT ERROR|ERROR:' -Quiet) { throw "Godot error in $log" }
    }
} finally { $env:APPDATA = $oldApp; $env:LOCALAPPDATA = $oldLocal; Pop-Location }
