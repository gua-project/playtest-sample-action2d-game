$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$deps = Join-Path $root '.deps/ci-godot'
New-Item -ItemType Directory -Force $deps | Out-Null
$base = 'https://github.com/godotengine/godot-builds/releases/download/4.7-stable/'
$assets = @(
    @{Name='Godot_v4.7-stable_win64.exe.zip'; Hash='02a5312236f4e0209c78bcb2f52135b1963e6b8888c873c9cee81459e60bcd71'},
    @{Name='Godot_v4.7-stable_export_templates.tpz'; Hash='9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec'}
)
foreach ($asset in $assets) {
    $path = Join-Path $deps $asset.Name
    Invoke-WebRequest ($base + $asset.Name) -OutFile $path
    if ((Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $asset.Hash) { throw "Godot checksum mismatch: $($asset.Name)" }
}
Expand-Archive (Join-Path $deps $assets[0].Name) -DestinationPath $deps -Force
$templates = Join-Path $deps 'templates'
New-Item -ItemType Directory -Force $templates | Out-Null
$archive = [IO.Compression.ZipFile]::OpenRead((Join-Path $deps $assets[1].Name))
try {
    foreach ($name in @('windows_release_x86_64.exe','windows_release_x86_64_console.exe')) {
        $entry = $archive.GetEntry("templates/$name")
        if ($null -eq $entry) { throw "Missing Windows template $name" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $templates $name),$true)
    }
} finally { $archive.Dispose() }
Write-Host "Godot executable: $(Join-Path $deps 'Godot_v4.7-stable_win64_console.exe')"
