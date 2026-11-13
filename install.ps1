<#
Windows bootstrap: Windows Terminal, VS Code, Git, YASB (config from this repo), WSL2 + a chosen
Debian/Ubuntu distro, then clones this repo inside WSL and runs install.sh --packages.

Fresh machine (any PowerShell window):
  irm https://raw.githubusercontent.com/spanthetree/dotfiles/main/install.ps1 -OutFile $env:TEMP\dotfiles.ps1
  powershell -ExecutionPolicy Bypass -File $env:TEMP\dotfiles.ps1

Re-running is safe. If enabling WSL needs a reboot, setup resumes after you sign in again.
#>
param([string]$Distro)

$ErrorActionPreference = 'Stop'
$RepoUrl   = 'https://github.com/spanthetree/dotfiles.git'
$WinClone  = Join-Path $env:USERPROFILE 'dotfiles'
$RunOnce   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'
$env:WSL_UTF8 = '1'   # wsl.exe prints UTF-16 otherwise

function Log([string]$m) { Write-Host "==> $m" -ForegroundColor Magenta }

function Test-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Update-SessionPath {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Install-WingetPackage([string]$Id) {
  winget list -e --id $Id --accept-source-agreements *> $null
  if ($LASTEXITCODE -eq 0) { Log "$Id already installed"; return }
  Log "installing $Id"
  winget install -e --id $Id --silent --accept-source-agreements --accept-package-agreements
  if ($LASTEXITCODE -ne 0) { Write-Warning "$Id install failed (winget exit $LASTEXITCODE); install it by hand" }
}

# Parses `wsl --list --online`; keeps Debian/Ubuntu only, since install.sh uses apt.
function ConvertFrom-WslOnline([string[]]$Lines) {
  $table = $false
  foreach ($l in $Lines) {
    if ($l -match '^\s*NAME\s+FRIENDLY NAME') { $table = $true; continue }
    if ($table -and $l -match '^\s*(\S+)\s+(.+?)\s*$') {
      $row = [pscustomobject]@{ Name = $Matches[1]; FriendlyName = $Matches[2] }
      if ($row.Name -match '^(Ubuntu|Debian)') { $row }
    }
  }
}

# Index of the newest "Ubuntu-NN.NN ... LTS" entry; 0 if there is none.
function Get-LatestLtsIndex($List) {
  $best = -1; $bestVer = [version]'0.0'
  for ($i = 0; $i -lt $List.Count; $i++) {
    if ($List[$i].FriendlyName -notmatch '\bLTS\b') { continue }
    if ($List[$i].Name -match '^Ubuntu-(\d+\.\d+)$') {   # last -match, so $Matches is this one
      $v = [version]$Matches[1]
      if ($v -gt $bestVer) { $best = $i; $bestVer = $v }
    }
  }
  return [Math]::Max(0, $best)
}

function Select-Distro {
  $list = @(ConvertFrom-WslOnline (wsl --list --online 2>$null))
  if ($list.Count -eq 0) {   # offline or old wsl.exe
    $list = @(
      [pscustomobject]@{ Name = 'Ubuntu-24.04'; FriendlyName = 'Ubuntu 24.04 LTS' },
      [pscustomobject]@{ Name = 'Ubuntu-22.04'; FriendlyName = 'Ubuntu 22.04 LTS' },
      [pscustomobject]@{ Name = 'Debian';       FriendlyName = 'Debian GNU/Linux' })
  }
  $default = Get-LatestLtsIndex $list
  Write-Host "`nLinux distribution to install (Debian/Ubuntu; install.sh needs apt):"
  for ($i = 0; $i -lt $list.Count; $i++) {
    $mark = if ($i -eq $default) { ' (default)' } else { '' }
    Write-Host ("  {0,2}) {1}{2}" -f ($i + 1), $list[$i].FriendlyName, $mark)
  }
  while ($true) {
    $answer = Read-Host "Choose 1-$($list.Count) [$($default + 1)]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $list[$default].Name }
    $n = 0
    if ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $list.Count) { return $list[$n - 1].Name }
  }
}

function Test-WslReady { wsl --status *> $null; return ($LASTEXITCODE -eq 0) }

function Test-DistroInstalled([string]$Name) {
  return @(wsl --list --quiet 2>$null | ForEach-Object { $_.Trim() }) -contains $Name
}

function Main {
  if (-not (Test-Admin)) {
    Log 'relaunching as administrator (needed to enable WSL)'
    $argList = @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($Distro) { $argList += @('-Distro', $Distro) }
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    return
  }

  # 1. Windows apps
  foreach ($id in 'Microsoft.WindowsTerminal', 'Microsoft.VisualStudioCode', 'Git.Git', 'AmN.yasb', 'DEVCOM.JetBrainsMonoNerdFont') {
    Install-WingetPackage $id
  }
  Update-SessionPath

  # 2. Windows-side clone (YASB reads its config from here)
  if (Test-Path (Join-Path $WinClone '.git')) {
    Log "updating $WinClone"
    git -C $WinClone pull --ff-only
  } else {
    Log "cloning to $WinClone"
    git clone $RepoUrl $WinClone
  }

  # 3. YASB: config straight from the repo, start at sign-in
  $yasbConfig = Join-Path $WinClone 'windows\yasb'
  [Environment]::SetEnvironmentVariable('YASB_CONFIG_HOME', $yasbConfig, 'User')
  $env:YASB_CONFIG_HOME = $yasbConfig
  $yasbc = Join-Path $env:ProgramFiles 'YASB\yasbc.exe'
  if (Test-Path $yasbc) {
    Log 'YASB: config from repo, autostart on, restarting'
    & $yasbc enable-autostart
    & $yasbc stop *> $null
    & $yasbc start
  } else {
    Write-Warning 'yasbc.exe not found; start YASB once by hand'
  }

  # 4. Windows Terminal creates settings.json on first launch; install.sh patches it
  $wtSettings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
  if (-not (Test-Path $wtSettings)) {
    Log 'opening Windows Terminal once to create its settings'
    Start-Process wt.exe
    for ($i = 0; $i -lt 30 -and -not (Test-Path $wtSettings); $i++) { Start-Sleep -Seconds 1 }
  }

  # 5. WSL2, with resume after reboot
  if (-not $Distro) { $Distro = Select-Distro }
  if (-not (Test-WslReady)) {
    Log 'enabling WSL2'
    wsl --install --no-distribution
    $resume = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$WinClone\install.ps1`" -Distro $Distro"
    New-Item -Path $RunOnce -Force | Out-Null
    Set-ItemProperty -Path $RunOnce -Name 'dotfiles-install' -Value $resume
    Write-Host "`nReboot to finish enabling WSL. Setup continues after you sign in."
    if ((Read-Host 'Reboot now? [Y/n]') -notmatch '^[nN]') { Restart-Computer -Force }
    return
  }
  wsl --set-default-version 2 | Out-Null

  # 6. Distro: first launch asks for a Linux username and password
  if (-not (Test-DistroInstalled $Distro)) {
    Log "installing $Distro"
    Write-Host 'Create your Linux user when asked. When you reach a shell prompt, type: exit' -ForegroundColor Yellow
    wsl --install -d $Distro
    if (-not (Test-DistroInstalled $Distro)) { throw "$Distro did not install; re-run this script" }
  }

  # 7. Inside WSL: clone and run install.sh (asks for your sudo password)
  Log "running install.sh in $Distro"
  $bash = 'set -e; command -v git >/dev/null && command -v curl >/dev/null || { sudo apt-get update -qq && sudo apt-get install -y -qq git curl; }; ' +
          "[ -d ~/dotfiles ] || git clone $RepoUrl ~/dotfiles; ~/dotfiles/install.sh --packages"
  wsl -d $Distro --cd ~ -e bash -lc $bash
  if ($LASTEXITCODE -ne 0) { throw "install.sh failed in $Distro (exit $LASTEXITCODE); fix and re-run" }

  Log "done. Opening $Distro in Windows Terminal"
  Start-Process wt.exe -ArgumentList "wsl.exe -d $Distro"
}

# Dot-sourcing (tests) loads the functions without running anything
if ($MyInvocation.InvocationName -ne '.') { Main }
