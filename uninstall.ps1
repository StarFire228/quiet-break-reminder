# Удаление: убирает автозапуск и ярлык из «Пуска», останавливает напоминалку.
# Uninstall: removes autostart and the Start menu shortcut, stops the reminder.

foreach ($f in (Join-Path ([Environment]::GetFolderPath('Startup')) 'razminka.vbs'),
               (Join-Path ([Environment]::GetFolderPath('Programs')) 'Разминка.lnk')) {
    if (Test-Path $f) { Remove-Item $f -Force }
}

Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*razminka.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Write-Host 'Удалено / Removed. Файл settings.json с настройками остался в папке — можно удалить вместе с ней.'
