# Self-check for install.ps1 helpers: powershell -NoProfile -ExecutionPolicy Bypass -File windows\test_install.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'install.ps1')

$sample = @(
  'The following is a list of valid distributions that can be installed.',
  "Install using 'wsl.exe --install <Distro>'.",
  '',
  'NAME                            FRIENDLY NAME',
  'Ubuntu                          Ubuntu',
  'Ubuntu-24.04                    Ubuntu 24.04 LTS',
  'openSUSE-Tumbleweed             openSUSE Tumbleweed',
  'kali-linux                      Kali Linux Rolling',
  'Debian                          Debian GNU/Linux',
  'archlinux                       Arch Linux')

$got = @(ConvertFrom-WslOnline $sample)
if (($got.Name -join ',') -ne 'Ubuntu,Ubuntu-24.04,Debian') { throw "names: $($got.Name -join ',')" }
if ($got[1].FriendlyName -ne 'Ubuntu 24.04 LTS') { throw "friendly: $($got[1].FriendlyName)" }
if (@(ConvertFrom-WslOnline @('no table here')).Count -ne 0) { throw 'non-table input should give nothing' }

# Default = newest Ubuntu LTS, ignoring non-LTS and unversioned entries
$list = @(
  [pscustomobject]@{ Name = 'Ubuntu';       FriendlyName = 'Ubuntu' },
  [pscustomobject]@{ Name = 'Ubuntu-24.04'; FriendlyName = 'Ubuntu 24.04 LTS' },
  [pscustomobject]@{ Name = 'Ubuntu-26.10'; FriendlyName = 'Ubuntu 26.10' },
  [pscustomobject]@{ Name = 'Ubuntu-26.04'; FriendlyName = 'Ubuntu 26.04 LTS' },
  [pscustomobject]@{ Name = 'Debian';       FriendlyName = 'Debian GNU/Linux' })
if ((Get-LatestLtsIndex $list) -ne 3) { throw "latest LTS index: $(Get-LatestLtsIndex $list)" }
if ((Get-LatestLtsIndex @($list[4])) -ne 0) { throw 'no LTS should fall back to 0' }
# packages.yaml windows list: plain ids and maps with `id`, linux section ignored
Install-YamlModule
$tmp = Join-Path $env:TEMP 'dotfiles-test-packages.yaml'
Set-Content $tmp @('linux:', '  - git', 'windows:', '  # comment', '  - Git.Git', '  - id: Foo.Font', '    font: Foo',
                  '  - id: Foo.Chat', '    private: Foo keeps chats')
$pk = @(Read-WindowsPackages $tmp)
if (($pk.id -join ',') -ne 'Git.Git,Foo.Font,Foo.Chat') { throw "packages: $($pk.id -join ',')" }
if ($pk[2].private -ne 'Foo keeps chats' -or $pk[0].private) { throw "private: $($pk.private -join ',')" }
if (@(Read-WindowsPackages (Join-Path $PSScriptRoot '..\packages.yaml')).id -notcontains 'Git.Git') { throw 'packages.yaml should list Git.Git' }
# monitoring-check.ps1 runs and prints only finding lines (none expected on a plain machine)
$mc = @(& (Join-Path $PSScriptRoot 'monitoring-check.ps1'))
if ($mc | Where-Object { $_ -isnot [string] }) { throw 'monitoring-check should print only strings' }
'install.ps1 ok'
