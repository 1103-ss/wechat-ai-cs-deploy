# =============================================================================
#  WeChat AI Service - Windows bootstrap (ASCII ONLY on purpose)
#  - Ensures Python 3.10-3.12 (auto download from China mirrors if missing)
#  - Optionally installs Git for Windows (-WithGit, China mirror)
#  - Installs requirements.txt (Tsinghua pip mirror, fallback to official)
#  - Creates config/config.json from template if missing
#  - Runs scripts/doctor.py
#
#  Usage (from a cmd or PowerShell window, run normally, no admin needed):
#    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup_windows.ps1
#    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\setup_windows.ps1 -WithGit
# =============================================================================
[CmdletBinding()]
param(
    [switch]$WithGit
)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Tmp  = Join-Path $env:TEMP 'wxaisetup'
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null

function Log($s) { Write-Host "[setup] $s" -ForegroundColor Cyan }
function Ok($s)  { Write-Host "[ ok ] $s" -ForegroundColor Green }
function Warn($s){ Write-Host "[warn] $s" -ForegroundColor Yellow }
function Die($s) { Write-Host "[fail] $s" -ForegroundColor Red; exit 1 }

# -----------------------------------------------------------------------------
# 1. Resolve a usable Python 3.10-3.12
# -----------------------------------------------------------------------------
$script:PyExe = $null

function Test-Py($exe) {
    if (-not $exe) { return $false }
    try {
        # NOTE: do not put double quotes inside -c strings here - PowerShell 5.1
        # strips embedded quotes when passing args to native exes.
        $v = (& $exe --version 2>&1 | Select-Object -First 1 | Out-String).Trim()
        if ($v -notmatch 'Python\s+(\d+)\.(\d+)\.(\d+)') { return $false }
        $major = [int]$Matches[1]; $minor = [int]$Matches[2]
        if ($major -eq 3 -and $minor -ge 10 -and $minor -le 12) {
            Log "Found usable Python $v at $exe"
            return $true
        }
        Warn "Python at $exe is $v (need 3.10-3.12); will look for another"
        return $false
    } catch { return $false }
}

# 1a. py launcher
foreach ($spec in @('-3.12', '-3.11', '-3.10', '-3')) {
    try {
        $p = & py $spec -c 'import sys;print(sys.executable)' 2>$null
        if ($LASTEXITCODE -eq 0 -and $p) {
            $p = $p.Trim()
            if (Test-Py $p) { $script:PyExe = $p; break }
        }
    } catch {}
}

# 1b. python on PATH
if (-not $script:PyExe) {
    $cmd = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($cmd -and (Test-Py $cmd.Source)) { $script:PyExe = $cmd.Source }
}

# 1c. default per-user install location
if (-not $script:PyExe) {
    foreach ($minor in @(12, 11, 10)) {
        $cand = Join-Path $env:LOCALAPPDATA "Programs\Python\Python3$minor\python.exe"
        if ((Test-Path $cand) -and (Test-Py $cand)) { $script:PyExe = $cand; break }
    }
}

# -----------------------------------------------------------------------------
# 2. Install Python 3.12 from China mirrors if still missing
# -----------------------------------------------------------------------------
if (-not $script:PyExe) {
    $PyVer  = '3.12.10'
    $MinSize = 20000000
    $urls = @(
        "https://mirrors.huaweicloud.com/python/$PyVer/python-$PyVer-amd64.exe",
        "https://mirrors.aliyun.com/python-release/windows/python-$PyVer-amd64.exe"
    )
    $installer = Join-Path $Tmp "python-$PyVer-amd64.exe"
    if (-not (Test-Path $installer) -or (Get-Item $installer).Length -lt $MinSize) {
        $downloaded = $false
        foreach ($u in $urls) {
            Log "Downloading Python $PyVer from $u"
            try {
                Invoke-WebRequest -Uri $u -OutFile $installer -UseBasicParsing -TimeoutSec 300
                if ((Test-Path $installer) -and (Get-Item $installer).Length -ge $MinSize) {
                    $downloaded = true; break
                }
            } catch { Warn "download failed: $($_.Exception.Message)" }
        }
        if (-not $downloaded) {
            Die "Could not download Python. Check network, or install Python 3.12 manually and re-run."
        }
    }
    Log 'Installing Python 3.12 silently (per-user, no admin required)...'
    $args = '/quiet','InstallAllUsers=0','PrependPath=1','Include_launcher=1',
            'Include_pip=1','Include_test=0','Include_doc=0','Include_dev=0','Include_symbols=0'
    $proc = Start-Process -FilePath $installer -ArgumentList $args -Wait -PassThru
    if ($proc.ExitCode -ne 0) { Die "Python installer exit code $($proc.ExitCode)" }

    # refresh PATH for this session
    $machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
    $userPath    = [Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = ($userPath + ';' + $machinePath)

    $cand = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'
    if (-not (Test-Py $cand)) { Die 'Python installed but could not be located afterward.' }
    $script:PyExe = $cand
    Ok 'Python 3.12 installed'
}

# -----------------------------------------------------------------------------
# 3. Optional Git for Windows (needed only for git clone / git pull updates)
# -----------------------------------------------------------------------------
if ($WithGit) {
    $gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        $GitVer = '2.56.0.2'
        $GitDir = 'v2.56.0.windows.2'
        $url = "https://registry.npmmirror.com/-/binary/git-for-windows/$GitDir/Git-$GitVer-64-bit.exe"
        $installer = Join-Path $Tmp "Git-$GitVer-64-bit.exe"
        $MinSize = 50000000
        if (-not (Test-Path $installer) -or (Get-Item $installer).Length -lt $MinSize) {
            Log "Downloading Git for Windows $GitVer from npmmirror..."
            try {
                Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 600
            } catch { Die "Could not download Git: $($_.Exception.Message)" }
        }
        Log 'Installing Git silently (may take 1-2 minutes)...'
        $gargs = '/VERYSILENT','/NORESTART','/NOCANCEL','/SP-','/CLOSEAPPLICATIONS','/RESTARTAPPLICATIONS'
        $proc = Start-Process -FilePath $installer -ArgumentList $gargs -Wait -PassThru
        if ($proc.ExitCode -ne 0) { Warn "Git installer exit code $($proc.ExitCode) (continuing)" }
        $machinePath = [Environment]::GetEnvironmentVariable('Path','Machine')
        $userPath    = [Environment]::GetEnvironmentVariable('Path','User')
        $env:Path = ($userPath + ';' + $machinePath)
        if (Get-Command git.exe -ErrorAction SilentlyContinue) { Ok 'Git installed' }
        else { Warn 'Git installed but not on this session PATH; open a NEW terminal later.' }
    } else {
        Ok "Git already present: $(& git --version)"
    }
}

# -----------------------------------------------------------------------------
# 4. pip dependencies (Tsinghua mirror first, official PyPI fallback)
# -----------------------------------------------------------------------------
Log 'Upgrading pip (Tsinghua mirror)...'
& $script:PyExe -m pip install --upgrade pip `
    -i https://pypi.tuna.tsinghua.edu.cn/simple --timeout 60 --retries 2 | Out-Null

Log 'Installing requirements.txt (Tsinghua mirror)...'
& $script:PyExe -m pip install -r (Join-Path $Root 'requirements.txt') `
    -i https://pypi.tuna.tsinghua.edu.cn/simple --timeout 60 --retries 2
if ($LASTEXITCODE -ne 0) {
    Warn 'Tsinghua mirror failed, retrying with official PyPI...'
    & $script:PyExe -m pip install -r (Join-Path $Root 'requirements.txt') --timeout 60
}
if ($LASTEXITCODE -ne 0) { Die 'pip install failed. Check network and re-run this script.' }
Ok 'Python dependencies installed'

# -----------------------------------------------------------------------------
# 5. config from template (never overwrite existing config)
# -----------------------------------------------------------------------------
$cfgDir = Join-Path $Root 'config'
$cfgFile = Join-Path $cfgDir 'config.json'
if (-not (Test-Path $cfgFile)) {
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    Copy-Item (Join-Path $Root 'config.example.json') $cfgFile
    Ok 'config\config.json created from template'
} else {
    Ok 'config\config.json already exists, kept as-is'
}

# -----------------------------------------------------------------------------
# 6. doctor
# -----------------------------------------------------------------------------
Log 'Running environment doctor...'
& $script:PyExe (Join-Path $Root 'scripts\doctor.py')
$docExit = $LASTEXITCODE

Write-Host ''
Write-Host '================================================================' -ForegroundColor White
if ($docExit -eq 0) {
    Ok 'SETUP DONE - no hard failures.'
} else {
    Warn 'SETUP DONE with FAIL items - resolve them (see doctor output above).'
}
Write-Host 'Next:'
Write-Host '  1. Install compatible PC WeChat using the installer you got,'
Write-Host '     then login with phone QR and DISABLE auto-update in settings.'
Write-Host '  2. Activate wxautox4:  wxautox4 auth activate <YOUR_CODE>'
Write-Host '     (one code binds one machine; needs internet once)'
Write-Host '  3. Start the panel:    start.bat   (login admin / 123456)'
Write-Host '  4. Change password, fill DeepSeek API key, add groups, start bot.'
Write-Host '================================================================'
exit $docExit
