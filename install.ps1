# Установка: автозапуск при входе в Windows + запуск прямо сейчас.
# Install: autostart on Windows sign-in + start right now.
param(
    [int]$Minutes = 60,
    [int]$IdleResetMinutes = 5
)

$script = Join-Path $PSScriptRoot 'razminka.ps1'
$vbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'razminka.vbs'

# Останавливаем уже запущенную копию / stop a running copy
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*razminka.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# conhost --headless: никакого окна консоли, которое можно случайно закрыть
$scriptArgs = "-Minutes $Minutes -IdleResetMinutes $IdleResetMinutes"
$cmd = "conhost.exe --headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$script"" $scriptArgs"
$line = 'CreateObject("WScript.Shell").Run "' + $cmd.Replace('"', '""') + '", 0, False'
[IO.File]::WriteAllText($vbs, $line, [Text.Encoding]::Unicode)

Start-Process wscript.exe -ArgumentList "`"$vbs`""

Write-Host "Готово / Done: напоминание каждые $Minutes мин активной работы."
Write-Host "Автозапуск / Autostart: $vbs"
