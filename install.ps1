# video-studio installer for Windows (hardened).
# Checks runtime deps, builds the video-use engine venv from a hash-locked
# requirements file, and stores the ElevenLabs key readable by you only.
# Idempotent: safe to re-run.
#
# Run from this folder:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 -Gpu
#
# -Gpu : NVIDIA mode. Adds LOCAL transcription on the GPU (faster-whisper, no
#        ElevenLabs key, audio stays on this PC) and sets NVENC as the default
#        video encoder. Needs Python 3.12 and an NVIDIA GPU + recent driver.
#        Downloads ~1.4 GB of hash-locked packages (CUDA libraries), and the
#        Whisper model (~1.6 GB) on first transcription.

param([switch]$Gpu)

# Native tools (pip, ffmpeg, nvidia-smi) write warnings to stderr; under 'Stop',
# Windows PowerShell 5.1 turns redirected stderr into terminating errors.
# Every step below checks $LASTEXITCODE explicitly instead.
$ErrorActionPreference = 'Continue'
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
# (-Gpu needs exactly 3.12: the GPU lock file is built for it)
$Py = $null
$pyCheck = if ($Gpu) { 'import sys; sys.exit(0 if sys.version_info[:2] == (3,12) else 1)' }
           else { 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)' }
if (Get-Command py -ErrorAction SilentlyContinue) { $Py = if ($Gpu) { @('py', '-3.12') } else { @('py', '-3') } }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $Py = @('python') }
if (-not $Py) { Warn 'Python MISSING - install with:  winget install Python.Python.3.12'; $missing = $true }
else {
    $pyExe = $Py[0]; $pyArgs = @($Py | Select-Object -Skip 1)
    & $pyExe @pyArgs -c $pyCheck 2>$null
    if ($LASTEXITCODE -ne 0) {
        if ($Gpu) { Warn 'Python 3.12 required for -Gpu - install with:  winget install Python.Python.3.12' }
        else { Warn 'Python 3.10+ required' }
        $missing = $true
    }
    else { Say "python ok ($(& $pyExe @pyArgs --version))" }
}

if ($Gpu) {
    if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        $gpuName = (& nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | Select-Object -First 1)
        Say "nvidia gpu ok ($gpuName)"
    }
    else { Warn 'nvidia-smi not found - -Gpu needs an NVIDIA GPU with its driver installed.'; $missing = $true }
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
$Lock = if ($Gpu) { 'requirements-gpu-windows.lock' } else { 'requirements.lock' }
Say "Building the engine venv from $Lock (hash-verified)..."
if (Test-Path $VenvPy) {
    & $VenvPy -c $pyCheck 2>$null
    if ($LASTEXITCODE -ne 0) { Say 'existing venv uses another Python - rebuilding it'; & $pyExe @pyArgs -m venv --clear (Join-Path $VU '.venv') }
}
else { & $pyExe @pyArgs -m venv (Join-Path $VU '.venv') }
if ($Gpu) { Say 'downloading ~1.4 GB (CUDA libraries) - this can take a few minutes...' }
& $VenvPy -m pip install --quiet --disable-pip-version-check --require-hashes --only-binary=:all: -r (Join-Path $VU $Lock)
if ($LASTEXITCODE -ne 0) { Warn 'pip install failed (see above).'; exit 1 }
& $VenvPy -c 'import requests, numpy, PIL'
if ($LASTEXITCODE -ne 0) { Warn 'engine import check failed.'; exit 1 }
Say "engine ready: $VU\.venv"

if ($Gpu) {
    # CUDA check through the same DLL registration the transcriber uses
    $helpers = Join-Path $VU 'helpers'
    $probe = "import sys; sys.path.insert(0, r'$helpers'); import transcribe_local as t; t._register_windows_cuda_dlls(); import ctranslate2 as c; n = c.get_cuda_device_count(); print(n, sorted(c.get_supported_compute_types('cuda')) if n else []); sys.exit(0 if n else 1)"
    $out = & $VenvPy -c $probe 2>&1
    if ($LASTEXITCODE -eq 0) { Say "CUDA ok for local transcription (devices, compute types: $out)" }
    else {
        Warn "CUDA not usable by faster-whisper: $out"
        Warn 'If the error mentions MSVCP140.dll: winget install Microsoft.VCRedist.2015+.x64 ; otherwise update the NVIDIA driver. Transcription will fall back to CPU (slow).'
    }

    # NVENC check: one-second test encode on the GPU
    & ffmpeg -hide_banner -loglevel error -f lavfi -i testsrc=duration=1:size=1280x720:rate=30 -c:v h264_nvenc -f null - 2>$null
    if ($LASTEXITCODE -eq 0) {
        $env:VIDEO_USE_ENCODER = 'h264_nvenc'
        [Environment]::SetEnvironmentVariable('VIDEO_USE_ENCODER', 'h264_nvenc', 'User')
        Say 'NVENC ok - GPU encoding set as default (VIDEO_USE_ENCODER=h264_nvenc)'
    }
    else { Warn 'NVENC test encode failed - exports stay on the CPU (libx264). Update ffmpeg (winget upgrade Gyan.FFmpeg) or the NVIDIA driver.' }
}

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
    if ($Gpu) { Write-Host '(optional with -Gpu: transcription runs locally; only needed for AI voice-over)' }
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
