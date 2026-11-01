param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $root '.deps/gua-godot-addon-v1.2.0.zip'
$sha = 'effcad4cfc6083528bee4e469e171047cd9d2d49547a09d16be04845fcda7873'
New-Item -ItemType Directory -Force (Split-Path $archive) | Out-Null
if (-not (Test-Path $archive)) {
    Invoke-WebRequest 'https://github.com/gua-project/gua/releases/download/gua-v1.2.0/gua-godot-addon-v1.2.0.zip' -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha) { throw 'Gua 1.2.0 checksum mismatch' }
$expanded = Join-Path $root '.deps/verified-gua-1.2.0'
Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
New-Item -ItemType Directory -Force (Join-Path $root 'addons') | Out-Null
Copy-Item (Join-Path $expanded 'addons/gua') (Join-Path $root 'addons') -Recurse -Force
Set-Content (Join-Path $root 'addons/gua/.gua-version') '1.2.0'
Write-Host 'Official Gua 1.2.0 installed inside this checkout.'
