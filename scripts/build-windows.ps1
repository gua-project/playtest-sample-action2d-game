param([string]$Godot = 'Godot_v4.7-stable_win64_console.exe', [string]$TemplateDirectory = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $TemplateDirectory) { $TemplateDirectory = Join-Path $env:APPDATA 'Godot/export_templates/4.7.stable' }
$template = Join-Path $TemplateDirectory 'windows_release_x86_64.exe'
if (-not (Test-Path $template)) { throw "Existing Godot 4.7 Windows export template required: $template" }
Push-Location $root
$oldApp = $env:APPDATA; $oldLocal = $env:LOCALAPPDATA
$oldTemp = $env:TEMP; $oldTmp = $env:TMP
try {
    New-Item -ItemType Directory -Force output/appdata,output/localappdata,output/temp,build/windows | Out-Null
    $env:APPDATA = (Resolve-Path output/appdata).Path
    $env:LOCALAPPDATA = (Resolve-Path output/localappdata).Path
    $env:TEMP = (Resolve-Path output/temp).Path
    $env:TMP = $env:TEMP
    # Point a disposable preset at existing templates; leave shared Godot settings alone.
    $presets = Get-Content export_presets.cfg -Raw
    $customPresets = $presets.Replace('custom_template/release=""', ('custom_template/release="' + $template.Replace('\','/') + '"'))
    Set-Content export_presets.cfg $customPresets -NoNewline
    try { & $Godot --headless --path . --export-release Windows --log-file output/export.log }
    finally { Set-Content export_presets.cfg $presets -NoNewline }
    if ($LASTEXITCODE -ne 0 -or (Select-String output/export.log -Pattern 'ERROR:|SCRIPT ERROR' -Quiet)) { throw 'Windows export failed' }
    Copy-Item README.md,assets/OFL-MPLUS1p.txt,addons/gua/LICENSE build/windows/
    Get-FileHash build/windows/DeliveryFactory.exe -Algorithm SHA256 | Format-List | Out-File output/build-sha256.txt
    Compress-Archive build/windows/* build/DeliveryFactory-windows.zip -Force
} finally { $env:APPDATA = $oldApp; $env:LOCALAPPDATA = $oldLocal; $env:TEMP=$oldTemp; $env:TMP=$oldTmp; Pop-Location }
