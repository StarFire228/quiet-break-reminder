# quiet-break-reminder

**RU** | [EN](#english)

Тихая напоминалка размяться для Windows. Раз в час активной работы показывает обычное уведомление в углу экрана и играет короткий звук. Никаких окон посреди экрана и обязательных 5-минутных перерывов: можно спокойно доиграть катку или дописать код, а размяться чуть позже.

## Как работает

- Считает только время, когда ты за компьютером. Если на компьютере играет звук (смотришь видео или стрим), это тоже считается: таймер не сбрасывается, даже если мышь лежит без дела. Отсчёт начинается заново, только если 5 минут нет ни мыши с клавиатурой, ни звука (отошёл). Чтобы не учитывать звук, запусти `razminka.ps1` с ключом `-NoAudioCheck`.
- Уведомление само пропадает примерно через 25 секунд. В тексте каждый раз новый совет: присесть, размять шею, посмотреть вдаль и т.п.
- Звук играет отдельно от уведомления, поэтому его слышно, даже когда Windows прячет уведомления во время полноэкранной игры.
- Работает в фоне без окна консоли. Чистый PowerShell, ничего ставить не нужно.
- Ведёт лог `razminka.log` рядом со скриптом: когда сбрасывался таймер и когда показывалось напоминание.

## Нагрузка и приватность

**На FPS в играх не влияет.** Замер на 12-поточном процессоре во время работы: около 30 мс процессорного времени за 20 секунд, то есть примерно **0,01% CPU**. Память — около 85 МБ, почти всё это сам PowerShell.

Что программа делает на самом деле:

| Как часто | Что | Как |
|---|---|---|
| раз в секунду | узнаёт, играет ли сейчас звук | спрашивает у Windows текущий уровень громкости на выходе — одно число, то же, что показывает индикатор в микшере |
| раз в 30 секунд | узнаёт, когда последний раз двигалась мышь или нажималась клавиша | `GetLastInputInfo` — Windows хранит только время последнего ввода |
| раз в час | показывает уведомление и играет звук | стандартные уведомления Windows |

Остальное время программа спит.

Чего программа **не** делает:

- не смотрит на экран и не делает скриншотов;
- не записывает и не слушает звук и микрофон — знает только громкость на выходе, без содержимого;
- не знает, какие клавиши нажимались, — только время последнего нажатия;
- не ходит в интернет;
- не требует прав администратора.

Весь код — около сотни строк в одном файле [`razminka.ps1`](razminka.ps1), его легко проверить самому.

Проверить нагрузку у себя (PowerShell):

```powershell
$p = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | ? CommandLine -like '*razminka.ps1*' | select -First 1
$pr = Get-Process -Id $p.ProcessId; $a = $pr.TotalProcessorTime; sleep 20; $pr.Refresh()
"CPU: {0:N3}%" -f (($pr.TotalProcessorTime - $a).TotalMilliseconds / 20000 / [Environment]::ProcessorCount * 100)
```

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

- Only time you actually spend at the computer counts. Sound playing on the PC (watching a video or a stream) counts as being there too, so the timer keeps going even when the mouse sits still. The timer resets only after 5 minutes with neither input nor sound (you walked away). Run `razminka.ps1` with `-NoAudioCheck` to ignore sound.
- The notification disappears on its own after about 25 seconds and shows a random stretching tip (texts are in Russian; edit `$tips` in `razminka.ps1` to change them).
- The sound plays separately from the notification, so you hear it even when Windows hides notifications during fullscreen games.
- Runs in the background with no console window. Pure PowerShell, nothing to install.
- Writes a log to `razminka.log` next to the script: timer resets and reminders shown.

### Performance and privacy

**No effect on in-game FPS.** Measured on a 12-thread CPU while running: about 30 ms of CPU time per 20 seconds, roughly **0.01% CPU**. Memory is about 85 MB, almost all of it the PowerShell runtime itself.

What it actually does:

| How often | What | How |
|---|---|---|
| every second | checks whether sound is playing | asks Windows for the current output peak level — a single number, the same one the volume mixer meter shows |
| every 30 seconds | checks when the mouse/keyboard was last used | `GetLastInputInfo` — Windows only stores the time of the last input |
| every hour | shows a notification and plays a sound | standard Windows notifications |

The rest of the time it sleeps.

What it does **not** do:

- no screen capture or screenshots;
- no audio or microphone recording — it only reads the output level, not the content;
- no keylogging — only the time of the last input;
- no network access;
- no admin rights required.

All the code is about a hundred lines in a single file, [`razminka.ps1`](razminka.ps1), easy to review yourself. The PowerShell snippet in the Russian section above measures CPU usage on your machine.

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
