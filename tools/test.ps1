# Chạy test. Dùng: .\tools\test.ps1            (tất cả)
#                  .\tools\test.ps1 unit       (chỉ tests/unit; tương tự integration, parity)
param([Parameter(ValueFromRemainingArguments)][string[]]$groups = @())
$godot = & "$PSScriptRoot\godot.ps1"
$root = Split-Path $PSScriptRoot
& $godot --headless --path $root --import 2>&1 | Out-Null
$userArgs = if ($groups.Count) { @('--') + $groups } else { @() }
& $godot --headless --path $root -s res://tests/run.gd @userArgs 2>&1 | ForEach-Object { "$_" } |
    Where-Object { $_ -match '^(PASS|FAIL|\s{4}\S|\d+ passed)|SCRIPT ERROR|Parse Error' }
exit $LASTEXITCODE
