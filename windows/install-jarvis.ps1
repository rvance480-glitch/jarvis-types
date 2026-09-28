<#
.SYNOPSIS
  One-click Jarvis setup for Windows.

.DESCRIPTION
  1. Checks for Docker Desktop (offers to install it with winget if missing).
  2. Starts Docker Desktop and waits for it to be ready.
  3. Pulls and runs the Jarvis brain container on port 3142.
  4. Creates a connection token for this PC and copies it to the clipboard.
  5. Downloads the official signed Jarvis desktop installer (jarvis-setup.exe),
     checks its signature, and launches it.

  Safe to run again: it reuses the existing container and only re-downloads
  the installer.

.PARAMETER DeviceName
  Name this PC appears under in Jarvis. Defaults to the computer name.

.PARAMETER SkipDesktopApp
  Set up the brain and token only; do not download the desktop installer.
#>
[CmdletBinding()]
param(
  [string]$DeviceName = $env:COMPUTERNAME,
  [switch]$SkipDesktopApp
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # makes Invoke-WebRequest much faster on Windows PowerShell 5.1

$Image         = 'ghcr.io/vierisid/jarvis:latest'
$ContainerName = 'jarvis'
$Volume        = 'jarvis-data'
$Port          = 3142
$DashboardUrl  = "http://localhost:$Port"
$ReleasesApi   = 'https://api.github.com/repos/vierisid/jarvis/releases?per_page=50'
$InstallerName = 'jarvis-setup.exe'
$Publisher     = 'Usejarvis Inc.'

function Step($n, $text) { Write-Host ""; Write-Host "[$n/5] $text" -ForegroundColor Cyan }
function Ok($text)       { Write-Host "      $text" -ForegroundColor Green }
function Info($text)     { Write-Host "      $text" }
function Fail($text) {
  Write-Host ""
  Write-Host "Setup stopped: $text" -ForegroundColor Red
  Write-Host ""
  Read-Host 'Press Enter to close'
  exit 1
}

function Test-DockerReady {
  & docker info --format '{{.ServerVersion}}' *> $null
  return ($LASTEXITCODE -eq 0)
}

function Get-ContainerState {
  $state = & docker ps -a --filter "name=^/$ContainerName$" --format '{{.State}}' 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  return ($state | Select-Object -First 1)
}

Write-Host '==========================================' -ForegroundColor DarkCyan
Write-Host '  Jarvis setup for Windows' -ForegroundColor White
Write-Host '==========================================' -ForegroundColor DarkCyan

# --- 1. Docker Desktop installed? -------------------------------------------
Step 1 'Checking for Docker Desktop'
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Info 'Docker Desktop is not installed. Jarvis needs it to run on Windows.'
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Fail 'winget is not available. Install Docker Desktop from https://www.docker.com/products/docker-desktop/ then run this again.'
  }
  $answer = Read-Host '      Install Docker Desktop now? (Y/N)'
  if ($answer -notmatch '^[Yy]') { Fail 'Docker Desktop is required.' }
  & winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
  if ($LASTEXITCODE -ne 0) { Fail 'Docker Desktop did not install. Try installing it manually from docker.com.' }
  Write-Host ''
  Write-Host 'Docker Desktop is installed. Restart your PC, open Docker Desktop once to finish its setup,' -ForegroundColor Yellow
  Write-Host 'then double-click "Install Jarvis" again.' -ForegroundColor Yellow
  Read-Host 'Press Enter to close'
  exit 0
}
Ok 'Docker Desktop is installed.'

# --- 2. Docker engine running? ----------------------------------------------
Step 2 'Starting Docker'
if (-not (Test-DockerReady)) {
  $dockerExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
  if (Test-Path $dockerExe) {
    Info 'Opening Docker Desktop...'
    Start-Process $dockerExe
  } else {
    Info 'Please open Docker Desktop from the Start menu.'
  }
  $deadline = (Get-Date).AddMinutes(4)
  while (-not (Test-DockerReady)) {
    if ((Get-Date) -gt $deadline) { Fail 'Docker did not start within 4 minutes. Open Docker Desktop, wait for it to say "Engine running", then run this again.' }
    Start-Sleep -Seconds 5
    Write-Host '.' -NoNewline
  }
  Write-Host ''
}
Ok 'Docker is running.'

# --- 3. Jarvis brain container ----------------------------------------------
Step 3 'Starting the Jarvis brain'
$state = Get-ContainerState
if ($state) {
  if ($state -ne 'running') {
    Info "Found an existing Jarvis container ($state). Starting it..."
    & docker start $ContainerName | Out-Null
    if ($LASTEXITCODE -ne 0) { Fail 'Could not start the existing Jarvis container. See: docker logs jarvis' }
  } else {
    Info 'Jarvis is already running.'
  }
} else {
  $portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
  if ($portInUse) { Fail "Port $Port is already in use by another program. Close it and run this again." }
  Info 'Downloading Jarvis (first time takes a few minutes)...'
  & docker pull $Image
  if ($LASTEXITCODE -ne 0) { Fail 'Could not download the Jarvis image. Check your internet connection.' }
  & docker run -d --name $ContainerName --restart unless-stopped -p "${Port}:${Port}" -v "${Volume}:/data" $Image | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail 'Could not start Jarvis. See: docker logs jarvis' }
}

Info 'Waiting for Jarvis to answer...'
$deadline = (Get-Date).AddMinutes(3)
$up = $false
while (-not $up) {
  try {
    Invoke-WebRequest -Uri $DashboardUrl -UseBasicParsing -TimeoutSec 5 | Out-Null
    $up = $true
  } catch {
    # Any HTTP response (even 401 Unauthorized) means the server is up.
    if ($_.Exception.Response) { $up = $true }
  }
  if (-not $up) {
    if ((Get-Date) -gt $deadline) { Fail 'Jarvis did not start within 3 minutes. See: docker logs jarvis' }
    Start-Sleep -Seconds 3
  }
}
Ok "Jarvis brain is running at $DashboardUrl"

# --- 4. Connection token ----------------------------------------------------
Step 4 "Creating a connection token for `"$DeviceName`""
$tokenOutput = & docker exec $ContainerName jarvis enroll $DeviceName 2>$null
if ($LASTEXITCODE -ne 0 -or -not $tokenOutput) {
  Fail "Could not create a token. Try manually: docker exec jarvis jarvis enroll `"$DeviceName`""
}
$token = ($tokenOutput | Where-Object { $_.Trim() } | Select-Object -Last 1).Trim()
Set-Clipboard -Value $token
$tokenFile = Join-Path $env:USERPROFILE 'Desktop\Jarvis connection token.txt'
Set-Content -Path $tokenFile -Value $token -Encoding ASCII
Ok 'Token copied to your clipboard.'
Info "A copy is saved to your desktop: 'Jarvis connection token.txt'"
Info 'Delete that file once Jarvis is connected. Anyone with it can connect to your Jarvis.'

# --- 5. Desktop app ----------------------------------------------------------
if ($SkipDesktopApp) {
  Step 5 'Skipping the desktop app (-SkipDesktopApp)'
} else {
  Step 5 'Downloading the Jarvis desktop app'
  try {
    $releases = Invoke-RestMethod -Uri $ReleasesApi -Headers @{ 'User-Agent' = 'jarvis-windows-setup' }
  } catch {
    Fail 'Could not reach GitHub to find the desktop app. Download jarvis-setup.exe from https://github.com/vierisid/jarvis/releases (newest "sidecar-v" release).'
  }
  $release = $releases |
    Where-Object { $_.tag_name -like 'sidecar-v*' -and -not $_.prerelease -and -not $_.draft } |
    Sort-Object { [datetime]$_.published_at } -Descending |
    Where-Object { $_.assets.name -contains $InstallerName } |
    Select-Object -First 1
  if (-not $release) { Fail 'No desktop installer found on GitHub. Check https://github.com/vierisid/jarvis/releases' }

  $asset = $release.assets | Where-Object { $_.name -eq $InstallerName } | Select-Object -First 1
  $dest = Join-Path $env:TEMP $InstallerName
  Info "Downloading $($release.tag_name)..."
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $dest -UseBasicParsing

  $sig = Get-AuthenticodeSignature -FilePath $dest
  $signer = if ($sig.SignerCertificate) { $sig.SignerCertificate.GetNameInfo('SimpleName', $false) } else { '' }
  if ($sig.Status -ne 'Valid' -or $signer -ne $Publisher) {
    Remove-Item $dest -Force -ErrorAction SilentlyContinue
    Fail "The downloaded installer is not signed by $Publisher (status: $($sig.Status), signer: '$signer'). It was deleted and not run."
  }
  Ok "Signature verified: $Publisher"
  Info 'Opening the installer. Follow its steps; it adds Jarvis to your desktop.'
  Start-Process -FilePath $dest
}

Write-Host ''
Write-Host '==========================================' -ForegroundColor DarkCyan
Write-Host '  Almost done' -ForegroundColor White
Write-Host '==========================================' -ForegroundColor DarkCyan
Write-Host '  1. Finish the Jarvis installer window.'
Write-Host '  2. When Jarvis asks for a token, press Ctrl+V and click Connect.'
Write-Host '  3. Follow the setup in Jarvis (AI provider, voice, profile).'
Write-Host '  4. After setup, restart the brain once:  docker restart jarvis'
Write-Host ''
Read-Host 'Press Enter to close'
