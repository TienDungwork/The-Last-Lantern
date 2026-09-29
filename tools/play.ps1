# Mở game để chơi thử. Dùng: .\tools\play.ps1            (chơi)
#                             .\tools\play.ps1 -editor    (mở Godot editor, bấm F5 để chạy)
param([switch]$editor)
$godot = (& "$PSScriptRoot\godot.ps1") -replace '_console\.exe$', '.exe'   # bản không console: không bật cửa sổ đen
$root = Split-Path $PSScriptRoot
if ($editor) { Start-Process $godot -ArgumentList '--editor', '--path', "`"$root`"" }
else { Start-Process $godot -ArgumentList '--path', "`"$root`"" }
