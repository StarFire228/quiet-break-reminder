# Напоминалка размяться: уведомление в углу экрана + звук, без окон.
# Таймер считает только время, пока ты за компом. «За компом» — это когда
# трогаешь мышь/клаву ИЛИ на компе играет звук (смотришь видео, стрим).
# Если IdleResetMinutes минут нет ни ввода, ни звука (отошёл) — отсчёт заново.
param(
    [int]$Minutes = 60,           # через сколько минут напоминать
    [int]$IdleResetMinutes = 5,   # сколько минут тишины и простоя считать «отошёл»
    [switch]$NoAudioCheck,        # не считать звук присутствием
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

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class RzMMDeviceEnumerator {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IRzMMDeviceEnumerator {
    int EnumAudioEndpoints(int dataFlow, int stateMask, out IntPtr devices);
    [PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IRzMMDevice device);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IRzMMDevice {
    [PreserveSig] int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface);
}
[Guid("C02216F6-8C67-4B5B-9D00-D008E73E0064"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IRzAudioMeter { [PreserveSig] int GetPeakValue(out float peak); }

public static class RzAudio {
    // Текущий уровень звука на устройстве вывода по умолчанию (0..1), -1 при ошибке
    public static float Peak() {
        try {
            var en = (IRzMMDeviceEnumerator)new RzMMDeviceEnumerator();
            IRzMMDevice dev;
            if (en.GetDefaultAudioEndpoint(0, 1, out dev) != 0 || dev == null) return -1;
            Guid iid = typeof(IRzAudioMeter).GUID;
            object o;
            if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) return -1;
            float p; ((IRzAudioMeter)o).GetPeakValue(out p);
            Marshal.ReleaseComObject(o); Marshal.ReleaseComObject(dev); Marshal.ReleaseComObject(en);
            return p;
        } catch { return -1; }
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
$audioMode = if ($NoAudioCheck) { 'без учёта звука' } else { 'звук считается присутствием' }
Write-Log "старт (PID $PID), интервал $Minutes мин, сброс после $IdleResetMinutes мин простоя, $audioMode"

$step = 30
$active = 0
$wasIdle = $false
$lastSound = [DateTime]::MinValue
while ($true) {
    # Раз в секунду слушаем звук: тихие места в видео не должны сбивать таймер
    for ($i = 0; $i -lt $step; $i++) {
        Start-Sleep -Seconds 1
        if (-not $NoAudioCheck -and [RzAudio]::Peak() -gt 0.001) { $lastSound = Get-Date }
    }
    $inputIdle = [RzIdle]::Seconds()
    $soundIdle = ((Get-Date) - $lastSound).TotalSeconds
    $idle = [Math]::Min($inputIdle, $soundIdle)

    if ($idle -ge $IdleResetMinutes * 60) {
        if (-not $wasIdle) { Write-Log "простой $([int]($idle/60)) мин без ввода и звука — таймер сброшен (было $([int]($active/60)) мин)" }
        $wasIdle = $true; $active = 0; continue
    }
    $wasIdle = $false
    $active += $step
    if ($active % 600 -eq 0) {
        $why = if ($inputIdle -lt $IdleResetMinutes * 60) { 'ввод' } else { 'звук' }
        Write-Log "активно $([int]($active/60)) мин ($why)"
    }
    if ($active -ge $Minutes * 60) {
        try { Show-Reminder; Write-Log 'напоминание показано' } catch { Write-Log "ошибка показа: $_" }
        $active = 0
    }
}
