# Установка: автозапуск при входе в Windows, ярлык «Разминка» в меню «Пуск»
# и запуск прямо сейчас с открытым окном настроек.
# Install: autostart on sign-in, "Разминка" Start menu shortcut, start now with settings open.

$script = Join-Path $PSScriptRoot 'razminka.ps1'
$icon = Join-Path $PSScriptRoot 'razminka.ico'
$startup = [Environment]::GetFolderPath('Startup')
$vbs = Join-Path $startup 'razminka.vbs'
$lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'Разминка.lnk'

# Останавливаем уже запущенную копию / stop a running copy
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object CommandLine -like '*razminka.ps1*' |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

$psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File ""$script"""

# Автозапуск. conhost --headless: никакого окна консоли, которое можно случайно закрыть
$cmd = "conhost.exe --headless powershell.exe $psArgs"
$line = 'CreateObject("WScript.Shell").Run "' + $cmd.Replace('"', '""') + '", 0, False'
[IO.File]::WriteAllText($vbs, $line, [Text.Encoding]::Unicode)

# Ярлык в «Пуске»: запускает программу, а если она уже работает — открывает настройки
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk)
$s.TargetPath = "$env:WINDIR\System32\conhost.exe"
$s.Arguments = "--headless powershell.exe $psArgs -ShowSettings"
$s.WorkingDirectory = $PSScriptRoot
$s.WindowStyle = 7
if (Test-Path $icon) { $s.IconLocation = $icon }
$s.Description = 'Тихая напоминалка размяться'
$s.Save()

# Запуск через WMI: программа не привязана к этому окну и не закроется вместе с ним
$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
    CommandLine = "conhost.exe --headless powershell.exe $psArgs -ShowSettings"
    CurrentDirectory = $PSScriptRoot
}

if ($r.ReturnValue -eq 0) {
    Write-Host 'Готово / Done. Значок «Разминки» — у часов, окно настроек сейчас откроется.'
    Write-Host 'Настройки потом: клик по значку у часов или «Разминка» в меню «Пуск».'
} else {
    Write-Host "Не удалось запустить (код $($r.ReturnValue)). Попробуй ярлык «Разминка» в меню «Пуск»."
}
