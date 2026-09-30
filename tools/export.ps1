# Xuat ban Windows: export\TheLastLantern2-2.5D.exe (mot file, PCK nhung trong exe).
# Dung: .\tools\export.ps1 [duong_dan_export_templates.tpz]
# Chua co template thi giai nen rieng template Windows tu file .tpz (tai tu github.com/godotengine/godot/releases).
param([string]$Tpz = "$env:TEMP\godot_tpl\t.tpz")
$root = Split-Path $PSScriptRoot -Parent
$godot = & "$PSScriptRoot\godot.ps1"
$ver = ((& $godot --version) -split '\.')[0..3] -join '.'   # 4.7.2.stable.official.xxx -> 4.7.2.stable
$tpl = "$env:APPDATA\Godot\export_templates\$ver"
if (-not (Test-Path "$tpl\windows_release_x86_64.exe")) {
    if (-not (Test-Path $Tpz)) { throw "Thieu export templates $ver. Tai Godot_v$($ver -replace '\.stable','')-stable_export_templates.tpz roi chay lai voi duong dan file." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force $tpl | Out-Null
    $zip = [IO.Compression.ZipFile]::OpenRead($Tpz)
    try {
        foreach ($name in "version.txt", "windows_release_x86_64.exe", "windows_debug_x86_64.exe") {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry("templates/$name"), "$tpl\$name", $true)
        }
    } finally { $zip.Dispose() }
}
New-Item -ItemType Directory -Force "$root\export" | Out-Null
& $godot --headless --path $root --import 2>&1 | Out-Null
& $godot --headless --path $root --export-release "Windows Desktop" "$root\export\TheLastLantern2-2.5D.exe" 2>&1 | ForEach-Object { "$_" }
$exe = Get-Item "$root\export\TheLastLantern2-2.5D.exe" -ErrorAction Stop
"xong: $($exe.FullName) ($([math]::Round($exe.Length / 1MB)) MB)"
