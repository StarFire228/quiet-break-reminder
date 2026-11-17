# Удаление: убирает автозапуск и останавливает напоминалку.
# Uninstall: removes autostart and stops the reminder.

$vbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'razminka.vbs'
if (Test-Path $vbs) { Remove-Item $vbs -Force }

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*razminka.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Write-Host 'Удалено / Removed.'
