# video-studio installer for Windows (hardened).
# Checks runtime deps, builds the video-use engine venv from a hash-locked
# requirements file, and stores the ElevenLabs key readable by you only.
# Idempotent: safe to re-run.
#
# Run from this folder:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$HfVersion = '0.8.96'   # single pinned HyperFrames version used everywhere in this plugin

function Say($m)  { Write-Host "> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "!  $m" -ForegroundColor Yellow }

# ---------------------------------------------------------------------------
# 1) Runtime deps (checked only - this script never installs system packages).
# ---------------------------------------------------------------------------
$missing = $false
function Need($bin, $wingetId, $required) {
    $cmd = Get-Command $bin -ErrorAction SilentlyContinue
    if ($cmd) { Say "$bin ok ($($cmd.Source))"; return $true }
    if ($required) { Warn "$bin MISSING - install with:  winget install $wingetId"; $script:missing = $true }
    else { Warn "$bin missing (optional) - winget install $wingetId" }
    return $false
}

Say 'Checking runtime...'
Need 'ffmpeg'  'Gyan.FFmpeg'         $true  | Out-Null
Need 'ffprobe' 'Gyan.FFmpeg'         $true  | Out-Null
$hasNode = Need 'node' 'OpenJS.NodeJS.LTS' $true
Need 'npx'     'OpenJS.NodeJS.LTS'   $true  | Out-Null
Need 'yt-dlp'  'yt-dlp.yt-dlp'       $false | Out-Null

if ($hasNode) {
    $nodeMajor = [int](& node -p "process.versions.node.split('.')[0]")
    if ($nodeMajor -lt 22) { Warn "Node $nodeMajor found - HyperFrames needs Node 22+"; $missing = $true }
}

# Python 3.10+ : prefer the py launcher, fall back to python.exe
$Py = $null
if (Get-Command py -ErrorAction SilentlyContinue) { $Py = @('py', '-3') }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $Py = @('python') }
if (-not $Py) { Warn 'Python MISSING - install with:  winget install Python.Python.3.12'; $missing = $true }
else {
    $pyExe = $Py[0]; $pyArgs = @($Py | Select-Object -Skip 1)
    & $pyExe @pyArgs -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)"
    if ($LASTEXITCODE -ne 0) { Warn 'Python 3.10+ required'; $missing = $true }
    else { Say "python ok ($(& $pyExe @pyArgs --version))" }
}

$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
if ($chromePaths | Where-Object { $_ -and (Test-Path $_) }) { Say 'chrome ok' }
else { Warn 'Google Chrome not found - HyperFrames renders need it (winget install Google.Chrome).' }

if ($missing) { Warn 'Install the required deps above, open a NEW terminal, then re-run.'; exit 1 }

# ---------------------------------------------------------------------------
# 2) video-use engine venv - exact versions, every file checked against its hash.
# ---------------------------------------------------------------------------
$VU = Join-Path $Root 'skills\video-use'
$VenvPy = Join-Path $VU '.venv\Scripts\python.exe'
Say 'Building the engine venv from requirements.lock (hash-verified)...'
if (-not (Test-Path $VenvPy)) { & $pyExe @pyArgs -m venv (Join-Path $VU '.venv') }
& $VenvPy -m pip install --quiet --disable-pip-version-check --require-hashes --only-binary=:all: -r (Join-Path $VU 'requirements.lock')
if ($LASTEXITCODE -ne 0) { Warn 'pip install failed (see above).'; exit 1 }
& $VenvPy -c 'import requests, numpy, PIL'
if ($LASTEXITCODE -ne 0) { Warn 'engine import check failed.'; exit 1 }
Say "engine ready: $VU\.venv"

# ---------------------------------------------------------------------------
# 3) ElevenLabs key - typed hidden, file readable by your account only.
# ---------------------------------------------------------------------------
$EnvFile = Join-Path $VU '.env'
$me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
function Lock-File($path) {
    # remove inherited permissions, grant read/write to the current user only
    & icacls $path /inheritance:r /grant:r "${me}:(R,W)" | Out-Null
}

if ($env:ELEVENLABS_API_KEY) {
    Say 'ELEVENLABS_API_KEY found in your environment - nothing written to disk'
}
elseif ((Test-Path $EnvFile) -and (Select-String -Path $EnvFile -Pattern '^ELEVENLABS_API_KEY=.' -Quiet)) {
    Lock-File $EnvFile
    Say 'ElevenLabs key already set (permissions restricted to your account)'
}
else {
    Write-Host ''
    Write-Host 'ElevenLabs API key - get one at elevenlabs.io/app/settings/api-keys'
    $sec = Read-Host 'Paste it (input hidden; Enter to skip)' -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    if ($key) {
        # UTF-8 without BOM, so the Python helpers parse the first line correctly
        [IO.File]::WriteAllText($EnvFile, "ELEVENLABS_API_KEY=$($key.Trim())`n", (New-Object Text.UTF8Encoding $false))
        $key = $null
        Lock-File $EnvFile
        Say "key saved to $EnvFile (readable by $me only)"
    }
    else { Warn "skipped - add ELEVENLABS_API_KEY=... to $EnvFile before transcribing" }
}

# ---------------------------------------------------------------------------
# 4) HyperFrames CLI sanity (pinned version).
# ---------------------------------------------------------------------------
# Opt out of upstream telemetry (on by default, sent to PostHog) and of update
# checks, for this run and persistently for your Windows account.
foreach ($name in 'HYPERFRAMES_NO_TELEMETRY', 'HYPERFRAMES_NO_UPDATE_CHECK', 'HYPERFRAMES_NO_AUTO_INSTALL') {
    Set-Item -Path "Env:$name" -Value '1'
    [Environment]::SetEnvironmentVariable($name, '1', 'User')
}
Say 'Disabling HyperFrames usage telemetry...'
& npx --yes "hyperframes@$HfVersion" telemetry disable | Out-Null
if ($LASTEXITCODE -eq 0) { Say 'telemetry disabled (persisted in ~\.hyperframes\config.json + user env vars)' }
else { Warn "could not disable telemetry - run: npx hyperframes@$HfVersion telemetry disable" }

Say "Checking HyperFrames $HfVersion render path..."
& npx --yes "hyperframes@$HfVersion" doctor
if ($LASTEXITCODE -ne 0) { Warn 'hyperframes doctor reported issues (see above)' }

Write-Host ''
Say 'Claude video editor (hardened) installed.'
Write-Host "  Skills:   $Root\skills"
Write-Host "  Engine:   $VU\.venv"
Write-Host "  Template: $Root\templates\project  (copy it next to your footage)"
Write-Host '  Security: see SECURITY-HARDENING.md'
