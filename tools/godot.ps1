# Trả về đường dẫn Godot console exe. Dùng: $godot = & .\tools\godot.ps1
$g = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages", "C:\Program Files\Godot" -Recurse -Filter "Godot_v4*console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $g) { throw "Chưa cài Godot 4. Chạy: winget install GodotEngine.GodotEngine" }
$g.FullName
