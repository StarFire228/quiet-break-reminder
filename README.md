# quiet-break-reminder

**RU** | [EN](#english)

Тихая напоминалка размяться для Windows. Раз в час активной работы показывает обычное уведомление в углу экрана и играет короткий звук. Никаких окон посреди экрана и обязательных 5-минутных перерывов: можно спокойно доиграть катку или дописать код, а размяться чуть позже.

## Как работает

- Считает только время, когда ты за компьютером. Если 5 минут не трогать мышь и клавиатуру (отошёл), отсчёт начинается заново.
- Уведомление само пропадает примерно через 25 секунд. В тексте каждый раз новый совет: присесть, размять шею, посмотреть вдаль и т.п.
- Звук играет отдельно от уведомления, поэтому его слышно, даже когда Windows прячет уведомления во время полноэкранной игры.
- Работает в фоне без окна консоли. Чистый PowerShell, ничего ставить не нужно.
- Ведёт лог `razminka.log` рядом со скриптом: когда сбрасывался таймер и когда показывалось напоминание.

## Установка

1. Скачай репозиторий (**Code → Download ZIP**) и распакуй в постоянную папку.
2. Запусти `install.cmd`.

Готово: напоминалка запущена и будет стартовать сама при входе в Windows.

Свой интервал и порог простоя:

```powershell
.\install.cmd -Minutes 45 -IdleResetMinutes 10
```

Проверить, как выглядит уведомление:

```powershell
powershell -ExecutionPolicy Bypass -File .\razminka.ps1 -Test
```

## Удаление

Запусти `uninstall.cmd`. Он уберёт автозапуск и остановит напоминалку.

## Требования

Windows 10/11 и встроенный Windows PowerShell 5.1.

---

## English

A quiet stretch-break reminder for Windows. After every hour of active computer use it shows a regular notification in the corner of the screen and plays a short sound. No window in the middle of your screen and no forced 5-minute breaks: finish your match or your task, then stretch.

### How it works

- Only time you actually spend at the computer counts. After 5 minutes without mouse/keyboard input (you walked away), the timer resets.
- The notification disappears on its own after about 25 seconds and shows a random stretching tip (texts are in Russian; edit `$tips` in `razminka.ps1` to change them).
- The sound plays separately from the notification, so you hear it even when Windows hides notifications during fullscreen games.
- Runs in the background with no console window. Pure PowerShell, nothing to install.
- Writes a log to `razminka.log` next to the script: timer resets and reminders shown.

### Install

1. Download the repo (**Code → Download ZIP**) and extract it to a permanent folder.
2. Run `install.cmd`.

That's it: the reminder is running and will start automatically when you sign in to Windows.

Custom interval and idle threshold:

```powershell
.\install.cmd -Minutes 45 -IdleResetMinutes 10
```

Preview the notification:

```powershell
powershell -ExecutionPolicy Bypass -File .\razminka.ps1 -Test
```

### Uninstall

Run `uninstall.cmd`. It removes autostart and stops the reminder.

### Requirements

Windows 10/11 with the built-in Windows PowerShell 5.1.

## License

[MIT](LICENSE)
