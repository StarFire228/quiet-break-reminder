# Разминка — тихая напоминалка встать и размяться.
# Уведомление в углу экрана + звук, без окон посреди экрана.
# Значок у часов: статус, пауза, настройки. Настройки хранятся в settings.json.
#
# Таймер считает только время, пока ты за компом: трогаешь мышь/клаву ИЛИ на компе
# играет звук (видео, стрим). Если IdleResetMinutes минут нет ни того ни другого —
# считается, что ты отошёл, и отсчёт начинается заново.
param(
    [int]$Minutes = 60,           # значения по умолчанию, пока нет settings.json
    [int]$IdleResetMinutes = 5,
    [switch]$NoAudioCheck,
    [switch]$ShowSettings,        # сразу открыть окно настроек
    [switch]$Test                 # показать уведомление и выйти
)

$root = $PSScriptRoot
$settingsPath = Join-Path $root 'settings.json'
$logPath = Join-Path $root 'razminka.log'
$startupVbs = Join-Path ([Environment]::GetFolderPath('Startup')) 'razminka.vbs'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Drawing; using System.Windows.Forms;

public static class RzIdle {
    [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO p);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
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
    // Текущий уровень звука на устройстве вывода по умолчанию (0..1), -1 при ошибке.
    // Только громкость — содержимое звука не читается.
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

// Тёмное меню у значка в трее
public class RzMenuColors : ProfessionalColorTable {
    static Color Bg = Color.FromArgb(27, 33, 31), Hi = Color.FromArgb(43, 58, 51), Ln = Color.FromArgb(44, 53, 50);
    public override Color ToolStripDropDownBackground { get { return Bg; } }
    public override Color ImageMarginGradientBegin { get { return Bg; } }
    public override Color ImageMarginGradientMiddle { get { return Bg; } }
    public override Color ImageMarginGradientEnd { get { return Bg; } }
    public override Color MenuBorder { get { return Ln; } }
    public override Color MenuItemBorder { get { return Hi; } }
    public override Color MenuItemSelected { get { return Hi; } }
    public override Color MenuItemSelectedGradientBegin { get { return Hi; } }
    public override Color MenuItemSelectedGradientEnd { get { return Hi; } }
    public override Color MenuItemPressedGradientBegin { get { return Hi; } }
    public override Color MenuItemPressedGradientEnd { get { return Hi; } }
    public override Color SeparatorDark { get { return Ln; } }
    public override Color SeparatorLight { get { return Bg; } }
}
"@

# ---------- уведомление ----------

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
$appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'

# Упражнения: что сделать + зачем. Bar = нужен турник. Источники — в README.
$exercises = @(
    @{ Do = 'Пройдись 3–5 минут: по квартире, до кухни, налей воды.'; Why = 'Короткие прогулки между сидением снижают сахар и давление.' }
    @{ Do = '15 приседаний в спокойном темпе.'; Why = 'Самые крупные мышцы тела: разгоняют кровь и забирают сахар из крови.' }
    @{ Do = '1 минута шагов на месте, колени повыше. Есть лестница — 2–3 пролёта бегом.'; Why = 'Короткие «перекусы» нагрузкой в течение дня улучшают выносливость.' }
    @{ Do = '10 отжиманий: от пола, стола или стены.'; Why = 'Грудь, руки, плечи. Выносливость в отжиманиях связана со здоровьем сердца.' }
    @{ Do = '20 подъёмов на носки стоя.'; Why = 'Икры — «второе сердце»: гонят застоявшуюся кровь от ног вверх.' }
    @{ Do = 'Можно не вставая: 30 раз подними пятки, носки на полу.'; Why = 'Работает камбаловидная мышца — её работа сидя помогает обмену сахара.' }
    @{ Do = 'Ягодичный мостик лёжа на спине, 15 раз.'; Why = 'Будит ягодицы, которые «выключаются» от сидения, и разгружает поясницу.' }
    @{ Do = 'Выпад на колено, таз вперёд — по 30 секунд на каждую ногу.'; Why = 'Растягивает мышцы бедра, которые от сидения укорачиваются и тянут поясницу.' }
    @{ Do = 'Планка 30–45 секунд.'; Why = 'Мышцы корпуса держат спину ровной, когда сидишь.' }
    @{ Do = 'Втяни подбородок назад («двойной подбородок»), 10 раз по 3 секунды.'; Why = 'Против «компьютерной шеи», когда голова уезжает вперёд к монитору.' }
    @{ Do = 'Сведи лопатки и подержи 5 секунд, 10 раз.'; Why = 'Укрепляет мышцы между лопатками — против сутулости.' }
    @{ Do = '15 пожиманий плечами, можно с бутылками воды в руках.'; Why = 'Даже пара минут силовых для плеч в день уменьшала боль в шее у офисных работников.' }
    @{ Do = 'Посмотри на что-нибудь дальше 6 метров (в окно) 20 секунд.'; Why = 'Глаза отдыхают от экрана вблизи.' }
    @{ Do = 'Встань, потянись руками вверх, потом наклонись к носкам.'; Why = 'Разгружает спину после долгого сидения в одной позе.' }
    @{ Do = '10 выпадов на каждую ногу.'; Why = 'Ноги и баланс — силовая без всякого инвентаря.' }
    @{ Do = '«Стульчик» у стены 30–45 секунд.'; Why = 'Укрепляет бёдра, не нагружая спину.' }
    @{ Do = 'Разомни запястья: потяни пальцы на себя и от себя по 15 секунд.'; Why = 'Для рук, которые весь день на мышке и клавиатуре.' }
    @{ Do = '10 кругов плечами и руками вперёд и назад.'; Why = 'Разгоняет кровь в плечах и шее, снимает зажатость.' }
    @{ Bar = $true; Do = 'Повисни на турнике 20–40 секунд.'; Why = 'Разгружает позвоночник и развивает хват. Сильный хват связан с долголетием.' }
    @{ Bar = $true; Do = 'Подтянись на турнике 1–5 раз, без надрыва.'; Why = 'Спина и руки — противовес сутулости.' }
    @{ Bar = $true; Do = 'В висе на турнике подтяни колени к груди, 8 раз.'; Why = 'Пресс и хват за один подход.' }
    @{ Bar = $true; Do = 'Повисни и сведи лопатки, не сгибая рук: 5 раз по 3 секунды.'; Why = 'Укрепляет мышцы, которые держат плечи на месте.' }
    @{ Bar = $true; Do = 'Запрыгни наверх турника и медленно опускайся 3–5 секунд, 3 раза.'; Why = 'Лучший путь к первому подтягиванию, если пока не выходит.' }
)

# «Мешок»: упражнения идут по кругу в случайном порядке и не повторяются, пока не кончатся.
# Если есть турник, упражнения на нём кладутся дважды — попадаются примерно в каждом третьем напоминании.
$bag = New-Object System.Collections.ArrayList
function Get-NextExercise([bool]$hasBar) {
    if ($bag.Count -eq 0) {
        $pool = @($exercises | Where-Object { -not $_.Bar })
        if ($hasBar) { $b = @($exercises | Where-Object { $_.Bar }); $pool += $b + $b }
        foreach ($e in ($pool | Sort-Object { Get-Random })) { [void]$bag.Add($e) }
    }
    $e = $bag[0]; $bag.RemoveAt(0)
    $e
}

function Show-Toast([string]$title, [string]$text, [string]$note, [bool]$sound) {
    $t = [Security.SecurityElement]::Escape($title); $x = [Security.SecurityElement]::Escape($text); $n = [Security.SecurityElement]::Escape($note)
    $doc = New-Object Windows.Data.Xml.Dom.XmlDocument
    $doc.LoadXml("<toast duration=""long""><visual><binding template=""ToastGeneric""><text>$t</text><text>$x</text><text>$n</text></binding></visual><audio silent=""true""/></toast>")
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show((New-Object Windows.UI.Notifications.ToastNotification $doc))
    # Звук отдельно — его слышно, даже если Windows спрятала уведомление (игра на весь экран)
    if ($sound) {
        try { (New-Object System.Media.SoundPlayer "$env:WINDIR\Media\Windows Notify Calendar.wav").Play() }
        catch { [System.Media.SystemSounds]::Asterisk.Play() }
    }
}

function Show-Reminder([int]$min, [bool]$sound, [bool]$hasBar) {
    $e = Get-NextExercise $hasBar
    Show-Toast "Пора размяться · ты за компом $min мин" $e.Do $e.Why $sound
}

if ($Test) { Show-Reminder $Minutes $true $true; Start-Sleep 2; exit }

# ---------- один экземпляр ----------
# Повторный запуск (ярлык в «Пуске») не плодит копии, а открывает настройки у уже работающей.

$showEvt = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\RazminkaShowSettings')
$mutex = New-Object System.Threading.Mutex($false, 'Global\RazminkaReminder')
if (-not $mutex.WaitOne(0)) { [void]$showEvt.Set(); exit }

[void][RzIdle]::SetProcessDPIAware()

# ---------- лог и настройки ----------

function Write-Log($msg) {
    try {
        if ((Test-Path $logPath) -and (Get-Item $logPath).Length -gt 200KB) { Remove-Item $logPath }
        Add-Content -Path $logPath -Value ("{0:yyyy-MM-dd HH:mm:ss}  {1}" -f (Get-Date), $msg) -Encoding UTF8
    } catch {}
}

function Read-Settings {
    $c = [ordered]@{ Minutes = $Minutes; IdleResetMinutes = $IdleResetMinutes; AudioCheck = (-not $NoAudioCheck); Sound = $true; PullupBar = $false }
    if (Test-Path $settingsPath) {
        try {
            $j = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($k in @($c.Keys)) { if ($null -ne $j.$k) { $c[$k] = $j.$k } }
        } catch { Write-Log "не удалось прочитать settings.json: $_" }
    }
    $c.Minutes = [Math]::Min(180, [Math]::Max(5, [int]$c.Minutes))
    $c.IdleResetMinutes = [Math]::Min(30, [Math]::Max(1, [int]$c.IdleResetMinutes))
    $c.AudioCheck = [bool]$c.AudioCheck
    $c.Sound = [bool]$c.Sound
    $c.PullupBar = [bool]$c.PullupBar
    $c
}

function Save-Settings {
    try { $S.Cfg | ConvertTo-Json | Set-Content -Path $settingsPath -Encoding UTF8 } catch { Write-Log "не удалось сохранить настройки: $_" }
}

function Test-Autostart { Test-Path $startupVbs }

function Set-Autostart([bool]$on) {
    if ($on) {
        $script = Join-Path $root 'razminka.ps1'
        # conhost --headless: никакого окна консоли, которое можно случайно закрыть
        $cmd = "conhost.exe --headless powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File ""$script"""
        $line = 'CreateObject("WScript.Shell").Run "' + $cmd.Replace('"', '""') + '", 0, False'
        [IO.File]::WriteAllText($startupVbs, $line, [Text.Encoding]::Unicode)
    } elseif (Test-Path $startupVbs) {
        Remove-Item $startupVbs -Force
    }
}

# ---------- состояние ----------

$S = @{
    Cfg = Read-Settings
    Active = 0.0              # секунд за компом с последнего сброса
    LastTick = Get-Date
    LastSound = [DateTime]::MinValue
    WasIdle = $false
    PausedUntil = $null
    LastLoggedMin = 0
    Win = $null
    Ui = $null
}

function Get-Status {
    if ($S.PausedUntil) { return "Пауза до {0:HH:mm}" -f $S.PausedUntil }
    if ($S.WasIdle) { return 'Ты отошёл — отсчёт заново' }
    $left = [Math]::Ceiling(($S.Cfg.Minutes * 60 - $S.Active) / 60)
    "До разминки $([Math]::Max(1, $left)) мин"
}

function Invoke-Remind {
    try { Show-Reminder $S.Cfg.Minutes $S.Cfg.Sound $S.Cfg.PullupBar; Write-Log 'напоминание показано' }
    catch { Write-Log "ошибка показа: $_" }
    $S.Active = 0.0; $S.LastLoggedMin = 0
}

function Switch-Pause {
    if ($S.PausedUntil) { $S.PausedUntil = $null; Write-Log 'пауза снята' }
    else { $S.PausedUntil = (Get-Date).AddHours(1); Write-Log 'пауза на час' }
    Update-View
}

# ---------- окно настроек ----------

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Разминка" Width="440" SizeToContent="Height" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" ShowInTaskbar="True"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="14" Foreground="#E9E4D8" UseLayoutRounding="True">
  <Window.Resources>
    <Style x:Key="SubText" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#9AA69F"/><Setter Property="FontSize" Value="12"/><Setter Property="Margin" Value="0,2,0,0"/>
    </Style>
    <Style x:Key="Toggle" TargetType="CheckBox">
      <Setter Property="Cursor" Value="Hand"/><Setter Property="Focusable" Value="False"/><Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="CheckBox">
          <Border x:Name="b" Width="38" Height="22" CornerRadius="11" Background="#3A4440">
            <Ellipse x:Name="k" Width="16" Height="16" Fill="#C9C4B8" HorizontalAlignment="Left" Margin="3,0,0,0"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsChecked" Value="True">
              <Setter TargetName="b" Property="Background" Value="#9CC5A6"/>
              <Setter TargetName="k" Property="HorizontalAlignment" Value="Right"/>
              <Setter TargetName="k" Property="Margin" Value="0,0,3,0"/>
              <Setter TargetName="k" Property="Fill" Value="#1B211F"/>
            </Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Background" Value="#2B3330"/><Setter Property="Foreground" Value="#E9E4D8"/>
      <Setter Property="Padding" Value="14,8"/><Setter Property="FontSize" Value="13"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Focusable" Value="False"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Button">
          <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="9" Padding="{TemplateBinding Padding}">
            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.85"/></Trigger>
            <Trigger Property="IsPressed" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.7"/></Trigger>
          </ControlTemplate.Triggers>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="RbFill" TargetType="RepeatButton">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="RepeatButton">
          <Grid Background="Transparent" Height="20"><Border Height="4" CornerRadius="2" Background="#9CC5A6"/></Grid>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="RbEmpty" TargetType="RepeatButton">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="RepeatButton"><Grid Background="Transparent" Height="20"/></ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style TargetType="Slider">
      <Setter Property="Width" Value="140"/><Setter Property="IsSnapToTickEnabled" Value="True"/>
      <Setter Property="IsMoveToPointEnabled" Value="True"/><Setter Property="Focusable" Value="False"/>
      <Setter Property="Cursor" Value="Hand"/><Setter Property="VerticalAlignment" Value="Center"/>
      <Setter Property="Template"><Setter.Value>
        <ControlTemplate TargetType="Slider">
          <Grid Height="20">
            <Border Height="4" CornerRadius="2" Background="#323C38" VerticalAlignment="Center"/>
            <Track x:Name="PART_Track">
              <Track.DecreaseRepeatButton><RepeatButton Style="{StaticResource RbFill}"/></Track.DecreaseRepeatButton>
              <Track.IncreaseRepeatButton><RepeatButton Style="{StaticResource RbEmpty}"/></Track.IncreaseRepeatButton>
              <Track.Thumb>
                <Thumb><Thumb.Template><ControlTemplate TargetType="Thumb"><Ellipse Width="16" Height="16" Fill="#E9E4D8"/></ControlTemplate></Thumb.Template></Thumb>
              </Track.Thumb>
            </Track>
          </Grid>
        </ControlTemplate>
      </Setter.Value></Setter>
    </Style>
    <Style x:Key="Row" TargetType="Border">
      <Setter Property="BorderBrush" Value="#2C3532"/><Setter Property="BorderThickness" Value="0,1,0,0"/><Setter Property="Padding" Value="0,11"/>
    </Style>
  </Window.Resources>

  <Border CornerRadius="14" Background="#1B211F" BorderBrush="#2C3532" BorderThickness="1" Padding="24,20,24,22">
    <StackPanel TextElement.Foreground="#E9E4D8" TextElement.FontSize="14">
      <Grid x:Name="Header" Background="Transparent" Margin="0,0,0,18">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Border Width="34" Height="34" CornerRadius="10" Background="#2B3A33">
          <Canvas Width="24" Height="24">
            <Path Data="M5,20 C3.5,10 10,4.5 20,4.5 C20,14 15,20.5 5,20 Z" Fill="#9CC5A6"/>
            <Path Data="M6,19 L15.5,9.5" Stroke="#2B3A33" StrokeThickness="1.4"/>
          </Canvas>
        </Border>
        <StackPanel Grid.Column="1" Margin="10,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="Разминка" FontSize="16" FontWeight="SemiBold"/>
          <TextBlock Text="Тихие напоминания встать и размяться" Style="{StaticResource SubText}"/>
        </StackPanel>
        <Border x:Name="Pill" Grid.Column="2" CornerRadius="11" Background="#2B3A33" Padding="10,3" VerticalAlignment="Center">
          <TextBlock x:Name="PillText" Text="Работает" FontSize="12" Foreground="#9CC5A6"/>
        </Border>
        <Button x:Name="CloseBtn" Grid.Column="3" Content="✕" Style="{StaticResource Btn}" Background="Transparent"
                Foreground="#9AA69F" Padding="8,4" Margin="6,0,-10,0" VerticalAlignment="Center" ToolTip="Закрыть (программа продолжит работать)"/>
      </Grid>

      <Border CornerRadius="12" Background="#232B28" Padding="16,14" Margin="0,0,0,8">
        <StackPanel>
          <Grid>
            <TextBlock x:Name="LeftLabel" Text="До разминки" Foreground="#9AA69F" FontSize="13" VerticalAlignment="Bottom" Margin="0,0,0,3"/>
            <TextBlock x:Name="LeftText" Text="—" FontSize="22" FontWeight="SemiBold" HorizontalAlignment="Right"/>
          </Grid>
          <Grid x:Name="BarTrack" Height="6" Margin="0,10,0,0">
            <Border CornerRadius="3" Background="#323C38"/>
            <Border x:Name="BarFill" CornerRadius="3" Background="#9CC5A6" HorizontalAlignment="Left" Width="0"/>
          </Grid>
        </StackPanel>
      </Border>

      <Border Style="{StaticResource Row}">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock Text="Напоминать каждые" VerticalAlignment="Center"/>
          <StackPanel Grid.Column="1" Orientation="Horizontal">
            <Slider x:Name="IntervalSlider" Minimum="15" Maximum="120" TickFrequency="5"/>
            <TextBlock x:Name="IntervalText" Width="58" TextAlignment="Right" VerticalAlignment="Center"/>
          </StackPanel>
        </Grid>
      </Border>

      <Border Style="{StaticResource Row}">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="Отошёл, если тишина"/>
            <TextBlock Text="нет мыши, клавиатуры и звука" Style="{StaticResource SubText}"/>
          </StackPanel>
          <StackPanel Grid.Column="1" Orientation="Horizontal">
            <Slider x:Name="IdleSlider" Minimum="2" Maximum="20" TickFrequency="1"/>
            <TextBlock x:Name="IdleText" Width="58" TextAlignment="Right" VerticalAlignment="Center"/>
          </StackPanel>
        </Grid>
      </Border>

      <Border Style="{StaticResource Row}">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="Видео считается присутствием"/>
            <TextBlock Text="если играет звук, таймер идёт" Style="{StaticResource SubText}"/>
          </StackPanel>
          <CheckBox x:Name="AudioToggle" Grid.Column="1" Style="{StaticResource Toggle}"/>
        </Grid>
      </Border>

      <Border Style="{StaticResource Row}">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock Text="Звуковой сигнал" VerticalAlignment="Center"/>
          <CheckBox x:Name="SoundToggle" Grid.Column="1" Style="{StaticResource Toggle}"/>
        </Grid>
      </Border>

      <Border Style="{StaticResource Row}">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="Есть турник"/>
            <TextBlock Text="добавить вис и подтягивания в упражнения" Style="{StaticResource SubText}"/>
          </StackPanel>
          <CheckBox x:Name="PullupToggle" Grid.Column="1" Style="{StaticResource Toggle}"/>
        </Grid>
      </Border>

      <Border Style="{StaticResource Row}">
        <Grid>
          <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
          <TextBlock Text="Запускать вместе с Windows" VerticalAlignment="Center"/>
          <CheckBox x:Name="AutoToggle" Grid.Column="1" Style="{StaticResource Toggle}"/>
        </Grid>
      </Border>

      <Grid Margin="0,16,0,0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <Button x:Name="TestBtn" Content="Показать пример" Style="{StaticResource Btn}"/>
        <Button x:Name="PauseBtn" Grid.Column="1" Content="Пауза на час" Style="{StaticResource Btn}" Margin="8,0,0,0"/>
        <Button x:Name="SaveBtn" Grid.Column="3" Content="Сохранить" Style="{StaticResource Btn}"
                Background="#9CC5A6" Foreground="#1B211F" FontWeight="SemiBold"/>
      </Grid>

      <TextBlock Margin="0,14,0,0" Style="{StaticResource SubText}" TextWrapping="Wrap"
                 Text="Программа живёт значком у часов. Не видно значка — нажми стрелку ^ рядом с часами."/>
    </StackPanel>
  </Border>
</Window>
'@

$bc = New-Object System.Windows.Media.BrushConverter
function Brush([string]$hex) { $bc.ConvertFromString($hex) }

function Update-View {
    $status = Get-Status
    $tip = "Разминка · $status"
    if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 63) }
    $S.Tray.Text = $tip
    $S.MiStatus.Text = $status
    $S.MiPause.Text = if ($S.PausedUntil) { 'Продолжить' } else { 'Пауза на час' }

    $u = $S.Ui
    if (-not $u) { return }
    $total = $S.Cfg.Minutes * 60
    if ($S.PausedUntil) { $u.LeftLabel.Text = 'Пауза до'; $u.LeftText.Text = '{0:HH:mm}' -f $S.PausedUntil }
    else { $u.LeftLabel.Text = 'До разминки'; $u.LeftText.Text = "$([Math]::Max(1, [Math]::Ceiling(($total - $S.Active) / 60))) мин" }
    $frac = [Math]::Min(1.0, $S.Active / $total)
    $u.BarFill.Width = [Math]::Max(0, $u.BarTrack.ActualWidth * $frac)
    if ($S.PausedUntil) {
        $u.PillText.Text = 'Пауза'; $u.PillText.Foreground = Brush '#E6C99A'; $u.Pill.Background = Brush '#3A3427'
        $u.PauseBtn.Content = 'Продолжить'
    } elseif ($S.WasIdle) {
        $u.PillText.Text = 'Ты отошёл'; $u.PillText.Foreground = Brush '#9AA69F'; $u.Pill.Background = Brush '#2B3330'
        $u.PauseBtn.Content = 'Пауза на час'
    } else {
        $u.PillText.Text = 'Работает'; $u.PillText.Foreground = Brush '#9CC5A6'; $u.Pill.Background = Brush '#2B3A33'
        $u.PauseBtn.Content = 'Пауза на час'
    }
}

function Open-Settings {
    if ($S.Win) { $S.Win.Activate(); return }
    $w = [Windows.Markup.XamlReader]::Parse($xaml)
    $u = @{}
    foreach ($n in 'Header','Pill','PillText','LeftLabel','LeftText','BarTrack','BarFill','IntervalSlider','IntervalText','IdleSlider','IdleText',
                   'AudioToggle','SoundToggle','PullupToggle','AutoToggle','TestBtn','PauseBtn','SaveBtn','CloseBtn') { $u[$n] = $w.FindName($n) }
    $S.Win = $w

    $w.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($S.Icon.Handle, [System.Windows.Int32Rect]::Empty,
        [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())

    $u.IntervalSlider.Add_ValueChanged({ $S.Ui.IntervalText.Text = "$([int]$S.Ui.IntervalSlider.Value) мин" })
    $u.IdleSlider.Add_ValueChanged({ $S.Ui.IdleText.Text = "$([int]$S.Ui.IdleSlider.Value) мин" })
    $u.IntervalSlider.Value = $S.Cfg.Minutes
    $u.IdleSlider.Value = $S.Cfg.IdleResetMinutes
    $u.IntervalText.Text = "$($S.Cfg.Minutes) мин"
    $u.IdleText.Text = "$($S.Cfg.IdleResetMinutes) мин"
    $u.AudioToggle.IsChecked = $S.Cfg.AudioCheck
    $u.SoundToggle.IsChecked = $S.Cfg.Sound
    $u.PullupToggle.IsChecked = $S.Cfg.PullupBar
    $u.AutoToggle.IsChecked = (Test-Autostart)

    $u.Header.Add_MouseLeftButtonDown({ try { $S.Win.DragMove() } catch {} })
    $u.CloseBtn.Add_Click({ $S.Win.Close() })
    $u.TestBtn.Add_Click({ Show-Reminder ([int]$S.Ui.IntervalSlider.Value) ([bool]$S.Ui.SoundToggle.IsChecked) ([bool]$S.Ui.PullupToggle.IsChecked) })
    $u.PauseBtn.Add_Click({ Switch-Pause })
    $u.SaveBtn.Add_Click({
        $S.Cfg.Minutes = [int]$S.Ui.IntervalSlider.Value
        $S.Cfg.IdleResetMinutes = [int]$S.Ui.IdleSlider.Value
        $S.Cfg.AudioCheck = [bool]$S.Ui.AudioToggle.IsChecked
        $S.Cfg.Sound = [bool]$S.Ui.SoundToggle.IsChecked
        if ($S.Cfg.PullupBar -ne [bool]$S.Ui.PullupToggle.IsChecked) { $bag.Clear() }   # пересобрать список упражнений
        $S.Cfg.PullupBar = [bool]$S.Ui.PullupToggle.IsChecked
        Save-Settings
        try { Set-Autostart ([bool]$S.Ui.AutoToggle.IsChecked) } catch { Write-Log "автозапуск: $_" }
        Write-Log ("настройки: каждые {0} мин, отошёл через {1} мин, звук как присутствие: {2}, сигнал: {3}, турник: {4}, автозапуск: {5}" -f
            $S.Cfg.Minutes, $S.Cfg.IdleResetMinutes, $S.Cfg.AudioCheck, $S.Cfg.Sound, $S.Cfg.PullupBar, (Test-Autostart))
        $S.Win.Close()
    })
    $w.Add_KeyDown({ if ($_.Key -eq 'Escape') { $S.Win.Close() } })
    $w.Add_ContentRendered({ Update-View })
    $w.Add_Closed({ $S.Win = $null; $S.Ui = $null })

    $S.Ui = $u
    Update-View
    $w.Show()
    [void]$w.Activate()
}

# ---------- значок в трее ----------

function New-LeafIcon {
    $size = 32
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $bg = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = 12
    $bg.AddArc(0, 0, $d, $d, 180, 90); $bg.AddArc($size - $d - 1, 0, $d, $d, 270, 90)
    $bg.AddArc($size - $d - 1, $size - $d - 1, $d, $d, 0, 90); $bg.AddArc(0, $size - $d - 1, $d, $d, 90, 90)
    $bg.CloseFigure()
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(43, 58, 51))), $bg)
    $leaf = New-Object System.Drawing.Drawing2D.GraphicsPath
    $leaf.AddBezier([single]6, [single]27, [single]3, [single]12, [single]13, [single]5, [single]27, [single]5)
    $leaf.AddBezier([single]27, [single]5, [single]27, [single]19, [single]20, [single]28, [single]6, [single]27)
    $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(156, 197, 166))), $leaf)
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(43, 58, 51)), 2
    $g.DrawLine($pen, [single]7, [single]26, [single]20, [single]13)
    $g.Dispose()
    [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$S.Icon = New-LeafIcon
$cream = [System.Drawing.Color]::FromArgb(233, 228, 216)

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Renderer = New-Object System.Windows.Forms.ToolStripProfessionalRenderer (New-Object RzMenuColors)
$menu.ShowImageMargin = $false
$menu.BackColor = [System.Drawing.Color]::FromArgb(27, 33, 31)
$menu.Font = New-Object System.Drawing.Font 'Segoe UI', 9.5

$S.MiStatus = $menu.Items.Add('…'); $S.MiStatus.Enabled = $false
[void]$menu.Items.Add('-')
$miNow = $menu.Items.Add('Напомнить сейчас'); $miNow.ForeColor = $cream; $miNow.Add_Click({ Invoke-Remind; Update-View })
$S.MiPause = $menu.Items.Add('Пауза на час'); $S.MiPause.ForeColor = $cream; $S.MiPause.Add_Click({ Switch-Pause })
$miSet = $menu.Items.Add('Настройки…'); $miSet.ForeColor = $cream; $miSet.Add_Click({ Open-Settings })
[void]$menu.Items.Add('-')
$miExit = $menu.Items.Add('Выход'); $miExit.ForeColor = [System.Drawing.Color]::FromArgb(227, 169, 160)
$miExit.Add_Click({
    Write-Log 'выход по кнопке'
    $S.Tray.Visible = $false
    if ($S.Win) { $S.Win.Close() }
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
})

$S.Tray = New-Object System.Windows.Forms.NotifyIcon
$S.Tray.Icon = $S.Icon
$S.Tray.Text = 'Разминка'
$S.Tray.ContextMenuStrip = $menu
$S.Tray.Add_MouseClick({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Open-Settings } })
$S.Tray.Visible = $true

# ---------- основной цикл ----------

function Invoke-Tick {
    $now = Get-Date
    $dt = ($now - $S.LastTick).TotalSeconds
    $S.LastTick = $now

    if ($showEvt.WaitOne(0)) { Open-Settings }

    # Раз в секунду смотрим громкость: тихие места в видео не сбивают таймер
    if ($S.Cfg.AudioCheck -and [RzAudio]::Peak() -gt 0.001) { $S.LastSound = $now }
    $inputIdle = [double][RzIdle]::Seconds()
    $idle = $inputIdle
    if ($S.Cfg.AudioCheck) { $idle = [Math]::Min($inputIdle, ($now - $S.LastSound).TotalSeconds) }
    if ($dt -gt 60) { $idle = [double]::MaxValue }   # комп спал

    if ($S.PausedUntil -and $now -ge $S.PausedUntil) { $S.PausedUntil = $null; Write-Log 'пауза закончилась' }

    if ($idle -ge $S.Cfg.IdleResetMinutes * 60) {
        if (-not $S.WasIdle) {
            Write-Log "простой без ввода и звука — таймер сброшен (было $([int]($S.Active / 60)) мин)"
        }
        $S.WasIdle = $true; $S.Active = 0.0; $S.LastLoggedMin = 0
    } else {
        $S.WasIdle = $false
        if (-not $S.PausedUntil) {
            $S.Active += $dt
            $min = [int][Math]::Floor($S.Active / 60)
            if ($min -gt 0 -and $min % 10 -eq 0 -and $min -ne $S.LastLoggedMin) {
                $S.LastLoggedMin = $min
                $why = if ($inputIdle -lt $S.Cfg.IdleResetMinutes * 60) { 'ввод' } else { 'звук' }
                Write-Log "активно $min мин ($why)"
            }
            if ($S.Active -ge $S.Cfg.Minutes * 60) { Invoke-Remind }
        }
    }
    Update-View
}

$dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
$dispatcher.Add_UnhandledException({ Write-Log "ошибка: $($_.Exception.Message)"; $_.Handled = $true })

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({ try { Invoke-Tick } catch { Write-Log "ошибка таймера: $_" } })
$timer.Start()

Write-Log ("старт (PID {0}): каждые {1} мин, отошёл через {2} мин, звук как присутствие: {3}" -f $PID, $S.Cfg.Minutes, $S.Cfg.IdleResetMinutes, $S.Cfg.AudioCheck)
Update-View
if ($ShowSettings) { Open-Settings }

[System.Windows.Threading.Dispatcher]::Run()

$timer.Stop()
$S.Tray.Visible = $false
$S.Tray.Dispose()
