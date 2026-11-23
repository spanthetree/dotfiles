<#
Wallpaper picker: searches Wallhaven (wallhaven.cc, safe-for-work only, no account), shows thumbnails, and sets the one you
click as the desktop wallpaper (Fill). Downloads go to Pictures\Wallpapers and stay there.
Start: the "Wallpapers" Start-menu shortcut (Ctrl-Alt-W), made by install.ps1. Linux (COSMIC): skwd-wall on Super-W.
Enter searches, Esc closes. An empty search lists Wallhaven's toplist.
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   # Windows PowerShell 5.1 default is older

Add-Type -Namespace Dotfiles -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
[DllImport("user32.dll")] public static extern int GetSystemMetrics(int index);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
'@
[Dotfiles.Native]::SetProcessDPIAware() | Out-Null   # real pixels below, not scaled ones
$Screen = '{0}x{1}' -f [Dotfiles.Native]::GetSystemMetrics(0), [Dotfiles.Native]::GetSystemMetrics(1)

$Api = 'https://wallhaven.cc/api/v1/search'
$Dir = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Wallpapers'

# SynthWave '84, as linux/kitty/theme.conf
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Wallpapers" Width="1120" Height="760" WindowStartupLocation="CenterScreen" Background="#111018">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#262335"/><Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="BorderBrush" Value="#6A5A7A"/><Setter Property="Padding" Value="12,4"/><Setter Property="Cursor" Value="Hand"/>
    </Style>
  </Window.Resources>
  <DockPanel Margin="12">
    <DockPanel DockPanel.Dock="Top" Margin="0,0,0,10">
      <Button x:Name="Go" DockPanel.Dock="Right" Content="Search" Margin="8,0,0,0"/>
      <ComboBox x:Name="Sort" DockPanel.Dock="Right" Width="110" Margin="8,0,0,0" SelectedIndex="0">
        <ComboBoxItem Content="relevance"/><ComboBoxItem Content="toplist"/><ComboBoxItem Content="date_added"/>
        <ComboBoxItem Content="favorites"/><ComboBoxItem Content="random"/>
      </ComboBox>
      <CheckBox x:Name="Purple" DockPanel.Dock="Right" Content="purple" Foreground="#FF7EDB" VerticalAlignment="Center" Margin="8,0,0,0"/>
      <TextBox x:Name="Query" FontSize="16" Padding="6,3" Background="#262335" Foreground="#FFFFFF" CaretBrush="#FF7EDB"
               BorderBrush="#FF7EDB" Text="synthwave"/>
    </DockPanel>
    <TextBlock x:Name="Status" DockPanel.Dock="Bottom" Foreground="#36F9F6" Margin="0,8,0,0"/>
    <ScrollViewer VerticalScrollBarVisibility="Auto">
      <StackPanel>
        <WrapPanel x:Name="Grid"/>
        <Button x:Name="More" Content="More" HorizontalAlignment="Center" Margin="0,8" Visibility="Collapsed"/>
      </StackPanel>
    </ScrollViewer>
  </DockPanel>
</Window>
'@
$win = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($xaml))
$ui = @{}
foreach ($n in 'Query', 'Go', 'Sort', 'Purple', 'Status', 'Grid', 'More') { $ui[$n] = $win.FindName($n) }
$state = @{ Page = 1; Last = 1 }

function Set-Status([string]$Text) {
  $ui.Status.Text = $Text
  $win.Dispatcher.Invoke([Action] {}, [Windows.Threading.DispatcherPriority]::Render)   # show it before blocking work
}

function Search([int]$Page) {
  $q = $ui.Query.Text.Trim()
  $sort = $ui.Sort.SelectedItem.Content
  if (-not $q -and $sort -eq 'relevance') { $sort = 'toplist' }
  $params = @{ q = $q; purity = '100'; categories = '111'; atleast = $Screen; sorting = $sort; page = "$Page" }
  if ($ui.Purple.IsChecked) { $params.colors = '663399' }
  $query = ($params.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, [Uri]::EscapeDataString($_.Value) }) -join '&'
  Set-Status 'Searching...'
  try { $r = Invoke-RestMethod "$Api`?$query" -TimeoutSec 20 }
  catch { Set-Status "Search failed: $($_.Exception.Message)"; return }
  if ($Page -eq 1) { $ui.Grid.Children.Clear() }
  $state.Page = $Page; $state.Last = [int]$r.meta.last_page
  foreach ($w in $r.data) {
    $img = [Windows.Controls.Image]@{ Width = 256; Height = 144; Stretch = 'UniformToFill' }
    $img.Source = [Windows.Media.Imaging.BitmapImage]::new([Uri]$w.thumbs.small)   # loads in the background
    $b = [Windows.Controls.Button]@{ Content = $img; Margin = 4; Padding = 0; Tag = $w; ToolTip = "$($w.resolution)  $($w.id)" }
    $b.Add_Click({ param($s) Set-Wallpaper $s.Tag })
    $ui.Grid.Children.Add($b) | Out-Null
  }
  $ui.More.Visibility = if ($state.Page -lt $state.Last) { 'Visible' } else { 'Collapsed' }
  Set-Status ("{0} wallpapers at {1} or larger. Click one to set it." -f $r.meta.total, $Screen)
}

function Set-Wallpaper($w) {
  $file = Join-Path $Dir ([IO.Path]::GetFileName(([Uri]$w.path).AbsolutePath))
  try {
    if (-not (Test-Path $file)) {
      Set-Status "Downloading $($w.resolution)..."
      New-Item -ItemType Directory -Force $Dir | Out-Null
      Invoke-WebRequest $w.path -OutFile "$file.part" -UseBasicParsing -TimeoutSec 120
      Move-Item -Force "$file.part" $file
    }
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' WallpaperStyle '10'   # Fill
    Set-ItemProperty 'HKCU:\Control Panel\Desktop' TileWallpaper '0'
    # SPI_SETDESKWALLPAPER, saved (SPIF_UPDATEINIFILE) and announced to running apps (SPIF_SENDCHANGE)
    if (-not [Dotfiles.Native]::SystemParametersInfo(20, 0, $file, 3)) { throw 'Windows refused the image' }
    Set-Status "Wallpaper set: $file"
  } catch {
    Remove-Item -Force -ErrorAction SilentlyContinue "$file.part"
    Set-Status "Failed: $($_.Exception.Message)"
  }
}

$ui.Go.Add_Click({ Search 1 })
$ui.More.Add_Click({ Search ($state.Page + 1) })
$ui.Query.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Return') { Search 1 } })
$win.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $win.Close() } })
$win.Add_ContentRendered({ $ui.Query.Focus() | Out-Null; $ui.Query.SelectAll(); Search 1 })
$win.ShowDialog() | Out-Null
