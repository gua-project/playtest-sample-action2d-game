$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$deps = Join-Path $root '.deps/ci-godot'
New-Item -ItemType Directory -Force $deps | Out-Null
# The editor and addon are installed by the released gua-tester components.
$engineArchive = Join-Path $env:RUNNER_TEMP 'Godot_v4.7-stable_win64.exe.zip'
if ((Get-FileHash $engineArchive -Algorithm SHA256).Hash.ToLowerInvariant() -ne '02a5312236f4e0209c78bcb2f52135b1963e6b8888c873c9cee81459e60bcd71') { throw 'Godot editor checksum mismatch' }
$archivePath = Join-Path $deps 'Godot_v4.7-stable_export_templates.tpz'
Invoke-WebRequest 'https://github.com/godotengine/godot-builds/releases/download/4.7-stable/Godot_v4.7-stable_export_templates.tpz' -OutFile $archivePath
if ((Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne '9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec') { throw 'Godot templates checksum mismatch' }
$templates = Join-Path $deps 'templates'
New-Item -ItemType Directory -Force $templates | Out-Null
$archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($name in @('windows_release_x86_64.exe','windows_release_x86_64_console.exe')) {
        $entry = $archive.GetEntry("templates/$name")
        if ($null -eq $entry) { throw "Missing Windows template $name" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,(Join-Path $templates $name),$true)
    }
} finally { $archive.Dispose() }
