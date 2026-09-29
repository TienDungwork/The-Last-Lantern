# Chạy game gốc ẩn theo tuyến tests/parity/fixtures/<name>_route.json, ghi <name>_trace.jsonl (lệnh R của AutoPlay) cạnh file tuyến.
# Dùng: .\tools\record_parity.ps1 level00_box     rồi: .\tools\test.ps1 parity
# Cần df2_desktop\qa (classes, test\AutoPlay có lệnh R, S_base.rms, L.rms.bak). Thư mục chạy: qa\parity\NN (ngoài repo).
param([string]$name = 'level00')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$qa = Join-Path (Split-Path $root) 'df2_desktop\qa'
$jdk = (Get-ChildItem 'C:\Program Files\Eclipse Adoptium' -Directory | Select-Object -First 1).FullName
$route = Get-Content "$root\tests\parity\fixtures\${name}_route.json" -Raw | ConvertFrom-Json
$level = [int]$route.level
$trace = "$root\tests\parity\fixtures\${name}_trace.jsonl"
Remove-Item $trace -ErrorAction SilentlyContinue

$w = Join-Path $qa "parity\$name"
Remove-Item -Recurse -Force $w -ErrorAction SilentlyContinue
$store = New-Item -ItemType Directory -Force "$w\appdata\DarkestFear2"
Copy-Item "$qa\L.rms.bak" "$store\L.rms"
# Save gốc: byte 8, 9, 10 của file = x, y, level (xem df2_desktop\test\levels.ps1)
$s = [IO.File]::ReadAllBytes("$qa\S_base.rms")
$s[8] = [byte]$route.spawn[0]; $s[9] = [byte]$route.spawn[1]; $s[10] = [byte]$level
[IO.File]::WriteAllBytes("$store\S.rms", $s)

# Menu -> Chơi tiếp, đóng thoại mở màn, ghi trạng thái; mỗi bước: giữ phím 250 ms (= 1 ô), đóng thoại nếu tuyến báo, ghi.
$keys = @{ 1 = -4; 2 = -2; 3 = -3; 4 = -1 }
$cmds = @('w1500', 'k-6', 'w3000', 'k-6', 'w1500', 'k-5', 'w4000')
for ($i = 0; $i -lt $route.intro_dismiss; $i++) { $cmds += 'k-5', 'w700' }
$cmds += "R$trace"
for ($i = 0; $i -lt $route.steps.Count; $i++) {
    if ([int]$route.steps[$i] -eq 5) { $cmds += 'k-5', 'w600' }   # 5 = phím bắn (nhặt/đặt đèn)
    else { $cmds += "h$($keys[[int]$route.steps[$i]]):250", 'w600' }
    $n = $route.dismiss_after."$i"
    for ($j = 0; $j -lt $n; $j++) { $cmds += 'k-5', 'w700' }
    $cmds += "R$trace", ('s{0:d2}' -f $i)
}
$cmds += 'q'

$old = $env:APPDATA
$env:APPDATA = "$w\appdata"
try {
    $p = Start-Process "$jdk\bin\java.exe" -WorkingDirectory $w -NoNewWindow -PassThru -Wait `
        -ArgumentList (@('-Ddf2.hidden=true', '-Dout=shots', '-Derr=err.txt', '-cp', "`"$qa\classes;$qa\test`"", 'AutoPlay') + $cmds) `
        -RedirectStandardOutput "$w\out.txt" -RedirectStandardError "$w\jvm.txt"
} finally { $env:APPDATA = $old }
$lines = @(Get-Content $trace -ErrorAction SilentlyContinue).Count
Write-Host "exit $($p.ExitCode), trace: $trace ($lines dòng, cần $($route.steps.Count + 1)), ảnh: $w\shots"
if ($lines -ne $route.steps.Count + 1) { exit 1 }
