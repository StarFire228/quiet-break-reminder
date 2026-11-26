# quiet-break-reminder

**RU** | [EN](#english)

Тихая напоминалка размяться для Windows. Раз в час активной работы показывает обычное уведомление в углу экрана и играет короткий звук. Никаких окон посреди экрана и обязательных 5-минутных перерывов: можно спокойно доиграть катку или дописать код, а размяться чуть позже.

<p align="center"><img src="docs/settings.png" width="440" alt="Окно настроек"></p>

## Как работает

- Живёт значком с листиком у часов. Наведи мышь — увидишь, сколько осталось до разминки. Клик — окно настроек. Правый клик — меню: «Напомнить сейчас», «Пауза на час» (рейтинговая катка, созвон), «Настройки», «Выход».
- В окне настроек: интервал напоминаний, через сколько минут тишины считать, что ты отошёл, учитывать ли звук от видео, звуковой сигнал и запуск вместе с Windows.
- Считает только время, когда ты за компьютером. Если на компьютере играет звук (смотришь видео или стрим), это тоже считается: таймер не сбрасывается, даже если мышь лежит без дела. Отсчёт начинается заново, только если несколько минут (по умолчанию 5) нет ни мыши с клавиатурой, ни звука — значит, отошёл.
- Уведомление само пропадает примерно через 25 секунд. В нём одно конкретное упражнение и одной строкой — зачем оно. Упражнения идут по кругу в случайном порядке и не повторяются, пока не пройдёшь все.
- Звук играет отдельно от уведомления, поэтому его слышно, даже когда Windows прячет уведомления во время полноэкранной игры.
- Работает в фоне без окна консоли. Чистый PowerShell и встроенный в Windows WPF, ничего ставить не нужно.
- Ведёт лог `razminka.log` рядом со скриптом: когда сбрасывался таймер и когда показывалось напоминание.

## Упражнения и откуда они

23 коротких упражнения на 1–5 минут, без инвентаря: прогулка, приседания, отжимания от стола, подъёмы на носки, ягодичный мостик, растяжка бедра, планка, упражнения для шеи и лопаток, разминка запястий, отдых для глаз. Есть и такое, что можно сделать не вставая, например посреди катки.

Если включить в настройках **«Есть турник»**, добавятся вис, подтягивания, подъём коленей в висе, «активный вис» с лопатками и негативные подтягивания для тех, кто пока не подтягивается. Они попадаются примерно в каждом третьем напоминании.

На чём основан список:

- **Частые короткие перерывы с ходьбой.** В опыте Колумбийского университета (Diaz и др., 2023) 5 минут ходьбы каждые 30 минут сидения снижали скачки сахара после еды на 58% и давление на 4–5 мм рт. ст. Ходьба раз в 60 минут в этом опыте сахар не снижала, так что если есть возможность — ставь интервал 30–45 минут. Опыт маленький (11 человек), выводы предварительные. [Columbia](https://www.cuimc.columbia.edu/node/25711)
- **«Перекусы» нагрузкой.** Три коротких подъёма по лестнице в день, 3 раза в неделю, за 6 недель улучшили выносливость у малоподвижных людей (Jenkins и др., 2019). [PubMed](https://pubmed.ncbi.nlm.nih.gov/30649897/)
- **Силовые для шеи и плеч.** В рандомизированных исследованиях с офисными работниками (Andersen и др.) силовые упражнения для шеи и плеч уменьшали боль в шее, а всего 2 минуты в день с резинкой — частоту головных болей. [PubMed](https://pubmed.ncbi.nlm.nih.gov/18461010/), [DOAJ](https://doaj.org/article/970327ba8c484449b144b0fecbb6e0ec)
- **Силовые хотя бы 2 дня в неделю.** ВОЗ (2020) советует взрослым силовые на все крупные группы мышц минимум 2 дня в неделю и меньше сидеть. [Рекомендации ВОЗ](https://pmc.ncbi.nlm.nih.gov/articles/PMC7719906/)
- **Подъёмы пяток сидя.** Работа камбаловидной мышцы сидя улучшала обмен сахара (Hamilton и др., 2022). В исследовании технику ставили по датчикам, так что дома эффект может быть меньше. [PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC9404652)
- **Отжимания и хват.** У мужчин, которые могли отжаться больше 40 раз, за 10 лет было намного меньше болезней сердца (Yang и др., 2019); слабый хват связан с более ранней смертностью. Это наблюдения, а не доказательство причины. [Harvard](https://hsph.harvard.edu/news/push-up-capacity-cardiovascular-disease-events-men)

Это не медицинская программа. Если что-то болит или есть травмы — посоветуйся с врачом. Текст упражнений лежит в начале [`razminka.ps1`](razminka.ps1) в списке `$exercises`, его легко поменять под себя.

## Нагрузка и приватность

**На FPS в играх не влияет.** Замер на 12-поточном процессоре во время работы: около 125 мс процессорного времени за 30 секунд, то есть примерно **0,03% CPU**. Память — до ~180 МБ: это сам PowerShell и графическая библиотека Windows для окна настроек.

Что программа делает на самом деле:

| Как часто | Что | Как |
|---|---|---|
| раз в секунду | узнаёт, играет ли сейчас звук | спрашивает у Windows текущий уровень громкости на выходе — одно число, то же, что показывает индикатор в микшере |
| раз в секунду | узнаёт, когда последний раз двигалась мышь или нажималась клавиша | `GetLastInputInfo` — Windows хранит только время последнего ввода |
| раз в час | показывает уведомление и играет звук | стандартные уведомления Windows |

Остальное время программа спит.

Чего программа **не** делает:

- не смотрит на экран и не делает скриншотов;
- не записывает и не слушает звук и микрофон — знает только громкость на выходе, без содержимого;
- не знает, какие клавиши нажимались, — только время последнего нажатия;
- не ходит в интернет;
- не требует прав администратора.

Весь код — в одном файле [`razminka.ps1`](razminka.ps1), его легко проверить самому.

Проверить нагрузку у себя (PowerShell):

```powershell
$p = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | ? CommandLine -like '*razminka.ps1*' | select -First 1
$pr = Get-Process -Id $p.ProcessId; $a = $pr.TotalProcessorTime; sleep 20; $pr.Refresh()
"CPU: {0:N3}%" -f (($pr.TotalProcessorTime - $a).TotalMilliseconds / 20000 / [Environment]::ProcessorCount * 100)
```

## Установка

1. Скачай репозиторий (**Code → Download ZIP**) и распакуй в постоянную папку.
2. Запусти `install.cmd`.

Готово: напоминалка запущена, у часов появился значок с листиком, и откроется окно настроек. В меню «Пуск» появится ярлык «Разминка» — он открывает настройки. Программа будет стартовать сама при входе в Windows (это можно выключить в настройках).

Если значка у часов не видно, нажми стрелку ^ рядом с часами. Чтобы значок был виден всегда, перетащи его оттуда на панель задач.

Проверить, как выглядит уведомление: кнопка «Показать пример» в настройках или

```powershell
powershell -ExecutionPolicy Bypass -File .\razminka.ps1 -Test
```

## Удаление

Запусти `uninstall.cmd`. Он уберёт автозапуск и ярлык из «Пуска» и остановит напоминалку. Потом можно удалить папку.

## Требования

Windows 10/11 и встроенный Windows PowerShell 5.1.

---

## English

A quiet stretch-break reminder for Windows. After every hour of active computer use it shows a regular notification in the corner of the screen and plays a short sound. No window in the middle of your screen and no forced 5-minute breaks: finish your match or your task, then stretch.

<p align="center"><img src="docs/settings.png" width="440" alt="Settings window"></p>

The interface and notifications are in Russian.

### How it works

- Lives as a leaf icon next to the clock. Hover to see how long until the next break. Click to open settings. Right-click for a menu: remind now, pause for an hour (ranked match, a call), settings, exit.
- Settings: reminder interval, how many quiet minutes mean you walked away, whether video sound counts as presence, the reminder sound, and starting with Windows.
- Only time you actually spend at the computer counts. Sound playing on the PC (watching a video or a stream) counts as being there too, so the timer keeps going even when the mouse sits still. The timer resets only after a few minutes (5 by default) with neither input nor sound — you walked away.
- The notification disappears on its own after about 25 seconds. It suggests one specific exercise with a one-line reason why. 23 short exercises (walking, squats, push-ups, calf raises, glute bridge, hip-flexor stretch, plank, neck and shoulder-blade work, wrists, eye rest) rotate in random order without repeats. Turn on "Есть турник" (pull-up bar) in settings to add dead hangs, pull-ups, hanging knee raises, scapular hangs and negatives. The list is `$exercises` in `razminka.ps1`; the research behind it is listed in the Russian section above (Diaz 2023, Jenkins 2019, Andersen et al., WHO 2020, Hamilton 2022, Yang 2019). Not medical advice.
- The sound plays separately from the notification, so you hear it even when Windows hides notifications during fullscreen games.
- Runs in the background with no console window. Pure PowerShell plus the WPF built into Windows, nothing to install.
- Writes a log to `razminka.log` next to the script: timer resets and reminders shown.

### Performance and privacy

**No effect on in-game FPS.** Measured on a 12-thread CPU while running: about 125 ms of CPU time per 30 seconds, roughly **0.03% CPU**. Memory is up to ~180 MB: the PowerShell runtime plus the Windows UI library for the settings window.

What it actually does:

| How often | What | How |
|---|---|---|
| every second | checks whether sound is playing | asks Windows for the current output peak level — a single number, the same one the volume mixer meter shows |
| every second | checks when the mouse/keyboard was last used | `GetLastInputInfo` — Windows only stores the time of the last input |
| every hour | shows a notification and plays a sound | standard Windows notifications |

The rest of the time it sleeps.

What it does **not** do:

- no screen capture or screenshots;
- no audio or microphone recording — it only reads the output level, not the content;
- no keylogging — only the time of the last input;
- no network access;
- no admin rights required.

All the code is in a single file, [`razminka.ps1`](razminka.ps1), easy to review yourself. The PowerShell snippet in the Russian section above measures CPU usage on your machine.

### Install

1. Download the repo (**Code → Download ZIP**) and extract it to a permanent folder.
2. Run `install.cmd`.

That's it: the reminder is running, a leaf icon appears next to the clock, and the settings window opens. A Start menu shortcut named "Разминка" opens settings later. It starts automatically when you sign in to Windows (you can turn that off in settings).

If you don't see the icon, click the ^ arrow next to the clock; drag the icon to the taskbar to keep it visible.

Preview the notification with the "Показать пример" button in settings, or:

```powershell
powershell -ExecutionPolicy Bypass -File .\razminka.ps1 -Test
```

### Uninstall

Run `uninstall.cmd`. It removes autostart and the Start menu shortcut and stops the reminder. Then you can delete the folder.

### Requirements

Windows 10/11 with the built-in Windows PowerShell 5.1.

## License

[MIT](LICENSE)
