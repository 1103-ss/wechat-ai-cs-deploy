# =============================================================================
#  WeChat AI Service - install the PC WeChat build from a LOCAL installer file
#  (ASCII ONLY on purpose)
#
#  The compatible WeChat installer is distributed out of band (NOT downloaded
#  by this script). Point -InstallerPath at the file the operator gave you,
#  e.g. D:\WeChatSetup-4.1.x.exe
#
#  Usage:
#    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install_wechat.ps1 `
#      -InstallerPath "D:\WeChatSetup.exe"
#
#  Exit codes: 0 = compatible WeChat present  2 = GUI install needs user click
#              1 = bad argument / installer failed
# =============================================================================
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath
)
$ErrorActionPreference = 'Stop'

function Log($s) { Write-Host "[wechat] $s" -ForegroundColor Cyan }
function Ok($s)  { Write-Host "[ ok ] $s" -ForegroundColor Green }
function Warn($s){ Write-Host "[warn] $s" -ForegroundColor Yellow }
function Die($s) { Write-Host "[fail] $s" -ForegroundColor Red; exit 1 }

# --- resolve & sanity-check the installer ------------------------------------
$InstallerPath = [Environment]::ExpandEnvironmentVariables($InstallerPath)
if (-not [IO.Path]::IsPathRooted($InstallerPath)) {
    $InstallerPath = Join-Path (Get-Location) $InstallerPath
}
if (-not (Test-Path $InstallerPath)) { Die "Installer not found: $InstallerPath" }
$fi = Get-Item $InstallerPath
if ($fi.Length -lt 10000000) { Die "File too small ($($fi.Length) bytes), not a real installer: $InstallerPath" }
Log "Installer: $($fi.FullName)  ($([math]::Round($fi.Length/1MB,1)) MB)"

# --- read WeChat display version from registry uninstall entries -------------
function Get-WeChatVersions {
    $found = New-Object System.Collections.Generic.List[string]
    $paths = @(
        @{ Root = 'CurrentUser'; Sub = 'Software\Microsoft\Windows\CurrentVersion\Uninstall' },
        @{ Root = 'LocalMachine'; Sub = 'Software\Microsoft\Windows\CurrentVersion\Uninstall' },
        @{ Root = 'LocalMachine'; Sub = 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' }
    )
    foreach ($p in $paths) {
        if ($p.Root -eq 'CurrentUser') { $base = [Microsoft.Win32.Registry]::CurrentUser }
        else { $base = [Microsoft.Win32.Registry]::LocalMachine }
        try { $uninstall = $base.OpenSubKey($p.Sub) } catch { continue }
        if (-not $uninstall) { continue }
        foreach ($name in $uninstall.GetSubKeyNames()) {
            try { $sk = $uninstall.OpenSubKey($name) } catch { continue }
            if (-not $sk) { continue }
            $dn = $sk.GetValue('DisplayName')
            $dv = $sk.GetValue('DisplayVersion')
            if ($dn -and $dv) {
                if ($dn -match 'WeCom' -or $dn -match [char]0x4F01 + [char]0x4E1A) { continue }  # skip WeCom
                if ($dn -match 'Weixin|WeChat' -or $dn -match [char]0x5FAE + [char]0x4FE1) {
                    [void]$found.Add([string]$dv)
                }
            }
        }
    }
    return $found
}

function Test-Compatible($ver) {
    $n = [regex]::Matches($ver, '\d+') | ForEach-Object { [int]$_.Value }
    while ($n.Count -lt 4) { $n += 0 }
    $min = @(4,1,9,0); $max = @(4,1,15,13)
    $ge = $true
    for ($i=0; $i -lt 4; $i++) { if ($n[$i] -ne $min[$i]) { $ge = $n[$i] -gt $min[$i]; break } }
    $le = $true
    for ($i=0; $i -lt 4; $i++) { if ($n[$i] -ne $max[$i]) { $le = $n[$i] -lt $max[$i]; break } }
    return ($ge -and $le)
}

$existing = @(Get-WeChatVersions)
if ($existing.Count -gt 0) {
    $top = ($existing | Sort-Object { [version](($_ -split '\.' | ForEach-Object { if($_){$_}else{'0'} }) -join '.') })[-1]
    if (Test-Compatible $top) {
        Ok "Compatible WeChat already installed: $top - nothing to do."
        Log 'Remember: login via QR, DISABLE auto-update, keep window unminimized.'
        exit 0
    }
    Warn "Detected WeChat $top (outside supported 4.1.9 - 4.1.15.13)."
    Warn 'Uninstall it first (Settings > Apps), then re-run this script.'
}

# --- try silent install (/S), fall back to GUI -------------------------------
Log 'Trying silent install (/S), up to 5 minutes...'
$proc = Start-Process -FilePath $InstallerPath -ArgumentList '/S' -PassThru
$deadline = (Get-Date).AddMinutes(5)
$detected = $null
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    if ($proc.HasExited) {
        $vs = @(Get-WeChatVersions)
        if ($vs.Count -gt 0) { $detected = $vs[-1]; break }
    }
    $vs = @(Get-WeChatVersions)
    if ($vs.Count -gt 0) { $detected = $vs[-1]; break }
}

if (-not $detected) {
    Warn 'Silent install did not register WeChat. Opening the GUI installer...'
    Start-Process -FilePath $InstallerPath
    Write-Host ''
    Write-Host '  ACTION NEEDED: click through the WeChat installer window,' -ForegroundColor Yellow
    Write-Host '  then run:  python scripts\doctor.py   to verify the version.' -ForegroundColor Yellow
    exit 2
}

if (Test-Compatible $detected) {
    Ok "WeChat $detected installed successfully."
    Log 'Next: open WeChat > login with phone QR > Settings > General:'
    Log '      UNCHECK auto-update, keep the main window open (not minimized).'
    exit 0
} else {
    Warn "Installed WeChat $detected is outside 4.1.9 - 4.1.15.13."
    Warn 'Get the correct installer build from the operator.'
    exit 1
}
