<#
monitoring-check: software on this machine that could let someone else see private data stored or shown on it.
Prints one line per finding (nothing on a machine with none). Two kinds:
  - it can read local files: endpoint security (EDR), data loss prevention, file-query and forensics agents. Beeper,
    for one, keeps its chats decrypted in a local SQLite database;
  - it can record the screen: activity and screen monitoring.
Read-only: it only looks at services, processes and one registry value. install.ps1, and packages.py from WSL, run it
before installing an entry with `private:` (e.g. Beeper), and ask first when it finds anything.
Plain Microsoft Defender Antivirus doesn't count: it's on every Windows machine and reports to no one; Defender for
Endpoint (onboarded to a company) does.
Not listed: what only sees network traffic (VPNs, Zscaler, Netskope, company root certificates) or manages the device
(Intune/MDM, domain or Entra join, Configuration Manager). End-to-end encryption keeps messages from those; what they
deploy shows up here once installed. Nothing found is no proof of privacy: an agent can be hidden, or added later.
#>
$ErrorActionPreference = 'SilentlyContinue'
$seen = @{}
function Found([string]$Line) { if (-not $seen[$Line]) { $seen[$Line] = $true; $Line } }

# services (name, display name, binary path) and processes, one line each, to match against
$names = @(Get-CimInstance Win32_Service | ForEach-Object { "$($_.Name) $($_.DisplayName) $($_.PathName)" }) +
         @(Get-Process | ForEach-Object { "$($_.ProcessName) $($_.Path)" })
$all = $names -join "`n"

# name, what it is, regex over service and process names (short, cryptic names as whole words: \b)
$agents = @(
  @('CrowdStrike Falcon', 'endpoint security: reads files', '\bCSFalcon\b|CrowdStrike'),
  @('SentinelOne', 'endpoint security: reads files', '\bSentinelAgent\b|SentinelOne'),
  @('Carbon Black', 'endpoint security: reads files', '\bCbDefense\b|CarbonBlack|Carbon Black|\bRepMgr\b'),
  @('Palo Alto Cortex XDR', 'endpoint security: reads files', '\bcyserver\b|Cortex XDR|\bTraps\b'),
  @('Sophos', 'endpoint security: reads files', 'Sophos'),
  @('Elastic Defend', 'endpoint security: reads files', '\bElasticEndpoint\b|Elastic Agent|elastic-endpoint'),
  @('Trend Micro', 'endpoint security: reads files', 'Trend Micro|\bds_agent\b|\bTMBMServer\b'),
  @('Trellix (McAfee)', 'endpoint security: reads files', 'McAfee|Trellix|\bmfemms\b|\bmasvc\b'),
  @('Cybereason', 'endpoint security: reads files', 'Cybereason'),
  @('Cisco Secure Endpoint', 'endpoint security: reads files', 'CiscoAMP|Cisco Secure Endpoint'),
  @('Bitdefender GravityZone', 'endpoint security: reads files', '\bEPSecurityService\b|Bitdefender Endpoint'),
  @('ESET PROTECT', 'endpoint security management: reads files', '\bEraAgentSvc\b|ESET Management Agent'),
  @('Kaspersky Endpoint Security', 'endpoint security: reads files', 'Kaspersky Endpoint|\bklnagent\b'),
  @('WithSecure', 'endpoint security: reads files', 'WithSecure|F-Secure Elements'),
  @('Tanium', 'endpoint management: file queries', 'Tanium'),
  @('Rapid7 Insight Agent', 'security agent: reads files', '\bir_agent\b|Rapid7'),
  @('Qualys Cloud Agent', 'security agent: reads files', '\bQualysAgent\b'),
  @('Wazuh', 'security monitoring: watches files', '\bWazuhSvc\b|\bOssecSvc\b|wazuh-agent'),
  @('osquery', 'endpoint queries: reads files', '\bosqueryd\b'),
  @('Kolide', 'device checks (osquery): reads files', 'Kolide'),
  @('Velociraptor', 'forensics agent: reads files', 'Velociraptor'),
  @('Forcepoint', 'data loss prevention: reads files', 'Forcepoint|\bfppsvc\b|Websense'),
  @('Symantec DLP', 'data loss prevention: reads files', '\bEDPA\b|Symantec DLP'),
  @('Digital Guardian', 'data loss prevention: reads files', 'Digital Guardian|\bDGService\b|\bdgagent\b'),
  @('Code42 Incydr', 'data loss prevention: reads files', 'Code42|Incydr'),
  @('Endpoint Protector', 'data loss prevention: reads files', '\bEPPClient\b|Endpoint Protector'),
  @('Proofpoint ITM (ObserveIT)', 'activity and screen recording', 'ObserveIT|Proofpoint.*Agent'),
  @('Teramind', 'activity and screen recording', 'Teramind|\btmagent\b'),
  @('ActivTrak', 'activity and screen recording', 'ActivTrak|\bsvctcom\b|\bscthost\b'),
  @('Veriato', 'activity and screen recording', 'Veriato|\bCerebral\b'),
  @('Hubstaff', 'activity and screen recording', 'Hubstaff'),
  @('Time Doctor', 'activity and screen recording', 'Time ?Doctor|TimeDoctor'),
  @('Insightful', 'activity and screen recording', 'Insightful|Workpuls'),
  @('InterGuard', 'activity and screen recording', 'InterGuard'),
  @('Controlio', 'activity and screen recording', 'Controlio'),
  @('Kickidler', 'activity and screen recording', 'Kickidler'),
  @('Ekran System', 'activity and screen recording', 'Ekran')
)
foreach ($a in $agents) { if ($all -match "(?im)$($a[2])") { Found "$($a[0]) ($($a[1]))" } }

# Defender for Endpoint: onboarded to a company's tenant (the Sense service exists on every machine, unused)
$atp = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status'
if ($atp.OnboardingState -eq 1) { Found 'Microsoft Defender for Endpoint (endpoint security: reads files)' }

