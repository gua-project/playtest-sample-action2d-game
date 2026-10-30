param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$archive = Join-Path $root '.deps/gua-godot-addon-v1.1.2.zip'
$sha = '19f89058ca60e48c74a7327da31c0e011b4c053acfda8e5b8e2e2b1fc90ae8c4'
New-Item -ItemType Directory -Force (Split-Path $archive) | Out-Null
if (-not (Test-Path $archive)) {
    Invoke-WebRequest 'https://github.com/gua-project/gua/releases/download/gua-v1.1.2/gua-godot-addon-v1.1.2.zip' -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne $sha) { throw 'Gua 1.1.2 checksum mismatch' }
$expanded = Join-Path $root '.deps/verified-gua-1.1.2'
Expand-Archive -LiteralPath $archive -DestinationPath $expanded -Force
New-Item -ItemType Directory -Force (Join-Path $root 'addons') | Out-Null
Copy-Item (Join-Path $expanded 'addons/gua') (Join-Path $root 'addons') -Recurse -Force
Set-Content (Join-Path $root 'addons/gua/.gua-version') '1.1.2'
Write-Host 'Official Gua 1.1.2 installed inside this checkout.'
