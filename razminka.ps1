# Напоминалка размяться: уведомление в углу экрана + звук, без окон.
# Таймер считает только время, пока ты за компом. Если не трогал мышь/клаву
# IdleResetMinutes минут (отошёл) — отсчёт начинается заново.
param(
    [int]$Minutes = 60,           # через сколько минут напоминать
    [int]$IdleResetMinutes = 5,   # сколько минут простоя считать «отошёл»
    [switch]$Test                 # показать уведомление сразу и выйти
)

# Только один экземпляр
$mutex = New-Object System.Threading.Mutex($false, 'Global\RazminkaReminder')
if (-not $Test -and -not $mutex.WaitOne(0)) { exit }

Add-Type @"
using System; using System.Runtime.InteropServices;
public static class RzIdle {
    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO p);
    public static uint Seconds() {
        var l = new LASTINPUTINFO(); l.cbSize = (uint)Marshal.SizeOf(l);
        GetLastInputInfo(ref l);
        return ((uint)Environment.TickCount - l.dwTime) / 1000;
    }
}
"@

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

$tips = @(
    'Встань, потянись вверх, покрути плечами.',
    'Пройдись пару минут, налей воды.',
    '10 приседаний и наклоны в стороны.',
    'Разомни шею: медленные наклоны вперёд и в стороны.',
    'Посмотри вдаль 20 секунд, дай глазам отдохнуть.',
    'Встань, потянись к носкам, прогни спину.'
)

function Show-Reminder {
    $tip = Get-Random -InputObject $tips
    $xml = @"
<toast duration="long">
  <visual><binding template="ToastGeneric">
    <text>Пора размяться</text>
    <text>Ты сидишь уже $Minutes мин. $tip</text>
  </binding></visual>
  <audio silent="true"/>
</toast>
"@
    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml($xml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $doc
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    # Звук отдельно — его слышно, даже если Windows спрятала уведомление (игра на весь экран)
    try {
        (New-Object System.Media.SoundPlayer "$env:WINDIR\Media\Windows Notify Calendar.wav").Play()
    } catch { [System.Media.SystemSounds]::Asterisk.Play() }
}

if ($Test) { Show-Reminder; Start-Sleep 2; exit }

$log = Join-Path $PSScriptRoot 'razminka.log'
function Write-Log($msg) {
    try {
        if ((Test-Path $log) -and (Get-Item $log).Length -gt 200KB) { Remove-Item $log }
        Add-Content -Path $log -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg) -Encoding UTF8
    } catch {}
}
Write-Log "старт (PID $PID), интервал $Minutes мин, сброс после $IdleResetMinutes мин простоя"

$step = 30
$active = 0
$wasIdle = $false
while ($true) {
    Start-Sleep -Seconds $step
    $idle = [RzIdle]::Seconds()
    if ($idle -ge $IdleResetMinutes * 60) {
        if (-not $wasIdle) { Write-Log "простой $([int]($idle/60)) мин — таймер сброшен (было $([int]($active/60)) мин)" }
        $wasIdle = $true; $active = 0; continue
    }
    $wasIdle = $false
    $active += $step
    if ($active % 600 -eq 0) { Write-Log "активно $([int]($active/60)) мин" }
    if ($active -ge $Minutes * 60) {
        try { Show-Reminder; Write-Log 'напоминание показано' } catch { Write-Log "ошибка показа: $_" }
        $active = 0
    }
}
