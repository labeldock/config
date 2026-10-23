<#
.SYNOPSIS
  clipaste 붙여넣기 서버(스크린샷을 찍는 Windows 쪽) 설치 현황을 보여주고, 설치/업데이트와 원격 연결을 관리한다.

.DESCRIPTION
  clipaste 는 두 부분으로 나뉜다. https://github.com/hqhq1025/clipaste
   붙여넣기 서버  스크린샷을 찍는 머신. 클립보드 이미지를 127.0.0.1:18340 으로 내어 준다.  <- 이 스크립트
   클라이언트     Claude Code 가 도는 머신. 18340 에서 이미지를 받아 붙여넣는다.
                  원격 macOS/Linux 는 ~/config/onboard -> install -> clipaste client,
                  또는 아래 [2] 가 원격에 함께 설치한다.

  메인 화면에서 설치 여부, 버전, 실행 상태, 로그인 자동 시작, server-only 모드,
  RemoteForward 로 연결된 원격 호스트를 보여주고 메뉴로 작업한다.
   [1] 설치/업데이트       - 공식 install.ps1 을 내려받아 실행 (실행 중이면 먼저 종료)
   [2] 원격 연결+클라이언트 - clipaste ssh-setup user@host
                             ~/.ssh/config 에 RemoteForward 를 넣고, 원격에 클라이언트 도우미도 설치한다
   [3] server-only 모드    - Windows 클립보드의 스크린샷을 경로로 바꾸지 않고 그대로 둔다
   [4] 진단                - clipaste doctor
   [5] 포워딩만 추가       - 원격에는 손대지 않고 ~/.ssh/config 에 RemoteForward 18340 만 넣는다
                             (클라이언트를 원격에서 onboard 로 따로 설치한 경우)

  붙여넣는 곳에 따라:
   Windows 의 Claude Code   Ctrl+V / Alt+V
   WSL2 의 Claude Code      WSL 안에서 clipaste wsl-setup 후 Ctrl+V
   리눅스 원격 Claude Code  [2] 로 연결 후, 새 SSH 접속에서 Ctrl+V
   macOS 원격 Claude Code   [2] 로 연결 후, 새 SSH 접속에서 clipaste-paste 실행, 출력된 경로를 붙여넣기

.EXAMPLE
  clipaste.cmd 더블클릭
  또는 powershell -ExecutionPolicy Bypass -File .\clipaste.ps1
#>
$ErrorActionPreference = 'Stop'

$Repo         = 'hqhq1025/clipaste'
$InstallerUrl = "https://raw.githubusercontent.com/$Repo/main/install.ps1"
$InstallDir   = Join-Path $env:LOCALAPPDATA 'clipaste'
$ExePath      = Join-Path $InstallDir 'clipaste.exe'
$RunKey       = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$Port         = 18340
$SshConfig    = Join-Path $env:USERPROFILE '.ssh\config'

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# ---------------------------------------------------------------------------
# 공통 UI
# ---------------------------------------------------------------------------
function Show-Header([string]$title) {
  Clear-Host
  Write-Host '=================================================================' -ForegroundColor DarkCyan
  Write-Host "  clipaste 붙여넣기 서버 (Windows)   |   $title" -ForegroundColor Cyan
  Write-Host '=================================================================' -ForegroundColor DarkCyan
  Write-Host ''
}

function Read-Choice([string]$prompt, [string[]]$keys) {
  while ($true) {
    $answer = (Read-Host $prompt).Trim().ToUpper()
    if ($keys -contains $answer) { return $answer }
    Write-Host "  [$($keys -join '/')] 중에서 선택해 주세요." -ForegroundColor DarkYellow
  }
}

function Write-Check([bool]$ok, [string]$label, [string]$detail = '') {
  if ($ok) { Write-Host '  [ OK ] ' -ForegroundColor Green -NoNewline }
  else     { Write-Host '  [ -- ] ' -ForegroundColor Yellow -NoNewline }
  Write-Host $label -NoNewline
  if ($detail) { Write-Host "  ($detail)" -ForegroundColor DarkGray } else { Write-Host '' }
}

function Wait-Enter {
  Write-Host ''
  Read-Host 'Enter 를 누르면 돌아갑니다' | Out-Null
}

function Exit-Script([int]$code = 0) {
  Write-Host ''
  Read-Host 'Enter 를 누르면 창을 닫습니다' | Out-Null
  exit $code
}

# ---------------------------------------------------------------------------
# 상태 조회
# ---------------------------------------------------------------------------
function Get-InstalledVersion {
  if (-not (Test-Path $ExePath)) { return $null }
  try { return ((& $ExePath --version) -split '\s+')[-1] } catch { return '?' }
}

$script:LatestVersion = $null
function Get-LatestVersion {
  if ($null -eq $script:LatestVersion) {
    try {
      $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest" -TimeoutSec 10
      $script:LatestVersion = "$($release.tag_name)".TrimStart('v')
    } catch { $script:LatestVersion = '' }
  }
  return $script:LatestVersion
}

function Get-Daemon { Get-Process -Name clipaste -ErrorAction SilentlyContinue }

function Test-AutoStart {
  $value = (Get-ItemProperty -Path $RunKey -Name clipaste -ErrorAction SilentlyContinue).clipaste
  return [bool]$value
}

function Test-ServerOnly {
  return [Environment]::GetEnvironmentVariable('CLIPASTE_SERVER_ONLY', 'User') -eq '1'
}

# ~/.ssh/config 에서 RemoteForward 18340 이 들어 있는 Host 이름들
function Get-LinkedHosts {
  if (-not (Test-Path $SshConfig)) { return @() }
  $current = @()
  $found = New-Object System.Collections.Generic.List[string]
  foreach ($line in Get-Content $SshConfig) {
    if ($line -match '^\s*Host\s+(.+)$') { $current = $Matches[1].Trim() -split '\s+'; continue }
    if ($line -match "^\s*RemoteForward\s+$Port\b") { foreach ($h in $current) { if (-not $found.Contains($h)) { $found.Add($h) } } }
  }
  return @($found)
}

function Start-Daemon {
  if (-not (Test-Path $ExePath)) { return }
  $env:CLIPASTE_SERVER_ONLY = if (Test-ServerOnly) { '1' } else { '0' }
  Start-Process -FilePath $ExePath -WindowStyle Hidden
  Start-Sleep -Milliseconds 800
}

function Stop-Daemon {
  $p = Get-Daemon
  if ($p) {
    $p | Stop-Process -Force
    Start-Sleep -Milliseconds 500
  }
}

# ---------------------------------------------------------------------------
# 1. 설치/업데이트
# ---------------------------------------------------------------------------
function Select-ServerOnly {
  Write-Host ''
  Write-Host '  스크린샷을 Windows 클립보드에 어떻게 둘까요?' -ForegroundColor Cyan
  Write-Host '   [D] 기본 모드    : 스크린샷 옆에 PNG 파일 경로를 넣고 비트맵은 지운다.'
  Write-Host '                      Slack, Word, 그림판, RustDesk 클립보드 공유는 이미지 대신 경로를 받는다.'
  Write-Host '   [S] server-only : 클립보드를 그대로 두고 SSH/WSL2 로만 이미지를 내어 준다.'
  Write-Host '                      다른 앱과 RustDesk 는 지금처럼 이미지를 받는다.'
  Write-Host '                      Windows 터미널에서 경로를 텍스트로 붙여넣는 기능만 빠진다.'
  $answer = Read-Choice '  선택 (D/S)' @('D', 'S')
  $value = if ($answer -eq 'S') { '1' } else { '0' }
  [Environment]::SetEnvironmentVariable('CLIPASTE_SERVER_ONLY', $value, 'User')
  $env:CLIPASTE_SERVER_ONLY = $value
}

function Install-Clipaste {
  Show-Header '설치/업데이트'
  $installed = Get-InstalledVersion
  $latest = Get-LatestVersion

  if ($installed -and $latest -and $installed -eq $latest) {
    Write-Host "  이미 최신 버전입니다. (v$installed)" -ForegroundColor Green
    if ((Read-Choice '  그래도 다시 설치할까요? (Y/N)' @('Y', 'N')) -ne 'Y') { return }
  }
  if (-not $installed) { Select-ServerOnly }
  else { $env:CLIPASTE_SERVER_ONLY = if (Test-ServerOnly) { '1' } else { '0' } }

  # 공식 설치 스크립트는 실행 중인 clipaste.exe 를 덮어쓰다 실패하므로 먼저 멈춘다
  Stop-Daemon

  $tmp = Join-Path $env:TEMP 'clipaste-install.ps1'
  Write-Host "  설치 스크립트 내려받는 중: $InstallerUrl" -ForegroundColor DarkGray
  Invoke-WebRequest -Uri $InstallerUrl -OutFile $tmp -UseBasicParsing
  Write-Host ''
  $shell = (Get-Process -Id $PID).Path
  & $shell -NoProfile -ExecutionPolicy Bypass -File $tmp
  $code = $LASTEXITCODE
  Remove-Item $tmp -ErrorAction SilentlyContinue

  if ($env:PATH -notlike "*$InstallDir*") { $env:PATH = "$env:PATH;$InstallDir" }
  Write-Host ''
  if ($code -ne 0 -or -not (Test-Path $ExePath)) {
    Write-Host '  설치에 실패했습니다. 위 메시지를 확인해 주세요.' -ForegroundColor Red
  } else {
    if (-not (Get-Daemon)) { Start-Daemon }
    Write-Host "  설치 완료: v$(Get-InstalledVersion)" -ForegroundColor Green
    Write-Host '  다음 단계: [2] 또는 [5] 로 Claude Code 를 쓰는 원격 서버를 연결하세요.' -ForegroundColor Cyan
  }
  Wait-Enter
}

# ---------------------------------------------------------------------------
# 2. 원격 호스트 연결 (ssh-setup)
# ---------------------------------------------------------------------------
function Connect-RemoteHost {
  Show-Header '원격 연결 + 클라이언트 설치'
  if (-not (Test-Path $ExePath)) { Write-Host '  먼저 [1] 로 설치해 주세요.' -ForegroundColor Yellow; Wait-Enter; return }
  if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    Write-Host '  ssh 명령이 없습니다. 설정 > 시스템 > 선택적 기능 에서 OpenSSH 클라이언트를 설치해 주세요.' -ForegroundColor Yellow
    Wait-Enter; return
  }
  if (-not (Get-Daemon)) { Start-Daemon }

  Write-Host '  Claude Code 를 실행하는 원격 서버를 등록합니다.'
  Write-Host "  ~/.ssh/config 의 해당 Host 에 RemoteForward $Port 가 추가되고, 원격에 클라이언트 도우미가 설치됩니다." -ForegroundColor DarkGray
  Write-Host '  예) user@server   user@server -p 2222   (ssh config 의 Host 별칭도 가능)' -ForegroundColor DarkGray
  Write-Host ''
  $line = (Read-Host '  원격 호스트 (Enter = 취소)').Trim()
  if (-not $line) { return }

  Write-Host ''
  $sshArgs = @('ssh-setup') + @($line -split '\s+')
  & $ExePath @sshArgs
  Write-Host ''
  if ($LASTEXITCODE -eq 0) {
    Write-Host '  연결 완료. 원격에 새로 SSH 접속해야 터널이 열립니다.' -ForegroundColor Green
    Write-Host '   리눅스 원격: Claude Code 에서 Ctrl+V' -ForegroundColor Cyan
    Write-Host '   macOS 원격 : clipaste-paste 실행 후 출력된 경로를 Claude Code 에 붙여넣기' -ForegroundColor Cyan
  } else {
    Write-Host '  ssh-setup 이 실패했습니다. 위 메시지를 확인해 주세요.' -ForegroundColor Red
  }
  Wait-Enter
}

# ---------------------------------------------------------------------------
# 3. server-only 모드
# ---------------------------------------------------------------------------
function Switch-ServerOnly {
  Show-Header 'server-only 모드'
  Select-ServerOnly
  if (Test-Path $ExePath) {
    Stop-Daemon
    Start-Daemon
    Write-Host '  clipaste 를 다시 시작했습니다.' -ForegroundColor Green
  }
  Wait-Enter
}

# ---------------------------------------------------------------------------
# 5. 포워딩만 추가 (원격 클라이언트는 따로 설치한 경우)
# ---------------------------------------------------------------------------
# user@host -> host. ssh-setup 과 같은 규칙으로 Host 블록을 찾는다.
function Get-HostPattern([string]$target) { return ($target -split '@')[-1] }

# Host 블록에 RemoteForward 를 넣은 새 설정 텍스트를 돌려준다. 이미 있으면 $null.
function Add-ForwardLine([string[]]$lines, [string]$hostPattern) {
  $forward = "  RemoteForward $Port 127.0.0.1:$Port"
  $insertAt = -1
  $inBlock = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $t = $lines[$i].Trim()
    if ($t -match '^Host\s+(.+)$') {
      $inBlock = @($Matches[1].Trim() -split '\s+') -contains $hostPattern
      if ($inBlock -and $insertAt -lt 0) { $insertAt = $i + 1 }
      continue
    }
    if ($inBlock -and $t -match "^RemoteForward\s+$Port\b") { return $null }
  }
  $out = New-Object System.Collections.Generic.List[string]
  if ($insertAt -ge 0) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($i -eq $insertAt) { $out.Add($forward) }
      $out.Add($lines[$i])
    }
    if ($insertAt -eq $lines.Count) { $out.Add($forward) }
  } else {
    foreach ($l in $lines) { $out.Add($l) }
    if ($out.Count -gt 0 -and $out[$out.Count - 1].Trim()) { $out.Add('') }
    $out.Add("Host $hostPattern")
    $out.Add($forward)
  }
  return ,$out.ToArray()
}

function Add-RemoteForwardOnly {
  Show-Header '포워딩만 추가'
  Write-Host '  원격에는 아무것도 설치하지 않고, 이 PC 의 ~/.ssh/config 에 아래 줄만 넣습니다.'
  Write-Host "    RemoteForward $Port 127.0.0.1:$Port" -ForegroundColor DarkGray
  Write-Host '  원격 클라이언트는 원격에서 ~/config/onboard -> install -> clipaste client 로 설치합니다.' -ForegroundColor DarkGray
  Write-Host ''
  $target = (Read-Host '  원격 호스트 또는 Host 별칭 (Enter = 취소)').Trim()
  if (-not $target) { return }
  $hostPattern = Get-HostPattern $target

  $lines = @()
  if (Test-Path $SshConfig) { $lines = @(Get-Content $SshConfig) }
  else { New-Item -ItemType Directory -Force -Path (Split-Path $SshConfig) | Out-Null }

  $updated = Add-ForwardLine $lines $hostPattern
  if ($null -eq $updated) {
    Write-Host "  이미 Host $hostPattern 에 RemoteForward $Port 가 있습니다." -ForegroundColor Green
  } else {
    if (Test-Path $SshConfig) { Copy-Item $SshConfig "$SshConfig.bak" -Force }
    [IO.File]::WriteAllLines($SshConfig, [string[]]$updated)
    Write-Host "  Host $hostPattern 에 RemoteForward $Port 를 추가했습니다. (이전 파일: config.bak)" -ForegroundColor Green
  }
  Write-Host '  원격에 새로 SSH 접속해야 터널이 열립니다.' -ForegroundColor Cyan
  Wait-Enter
}

# ---------------------------------------------------------------------------
# 4. 진단
# ---------------------------------------------------------------------------
function Invoke-Doctor {
  Show-Header '진단'
  if (-not (Test-Path $ExePath)) { Write-Host '  먼저 [1] 로 설치해 주세요.' -ForegroundColor Yellow; Wait-Enter; return }
  & $ExePath doctor
  Wait-Enter
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------
function Invoke-Main {
  while ($true) {
    Show-Header '설치 현황'
    $installed = Get-InstalledVersion
    $latest = Get-LatestVersion
    $daemon = Get-Daemon
    $hosts = Get-LinkedHosts

    $verDetail = if ($installed) { "v$installed" } else { '' }
    if ($installed -and $latest -and $installed -ne $latest) { $verDetail += " -> 최신 v$latest 있음" }
    elseif (-not $installed -and $latest) { $verDetail = "최신 v$latest" }

    Write-Check ([bool]$installed) 'clipaste 설치' $verDetail
    Write-Check ([bool]$daemon) '실행 중' $(if ($daemon) { "PID $($daemon[0].Id)" } else { '' })
    Write-Check (Test-AutoStart) '로그인 시 자동 시작' 'HKCU Run'
    Write-Check $true 'server-only 모드' $(if (Test-ServerOnly) { '켜짐: 클립보드를 그대로 둔다' } else { '꺼짐: 스크린샷 옆에 경로를 넣는다' })
    Write-Check ($hosts.Count -gt 0) "연결된 원격 호스트 $($hosts.Count) 개" ($hosts -join ', ')

    Write-Host ''
    Write-Host '  [1] 설치/업데이트       [2] 원격 연결 + 클라이언트 설치 (ssh-setup)'
    Write-Host '  [3] server-only 모드    [4] 진단 (doctor)'
    Write-Host '  [5] 포워딩만 추가 (원격 클라이언트는 따로 설치한 경우)'
    Write-Host '  [Q] 종료'
    switch (Read-Choice '  선택' @('1', '2', '3', '4', '5', 'Q')) {
      '1' { Install-Clipaste }
      '2' { Connect-RemoteHost }
      '3' { Switch-ServerOnly }
      '4' { Invoke-Doctor }
      '5' { Add-RemoteForwardOnly }
      'Q' { Exit-Script }
    }
  }
}

try {
  Invoke-Main
} catch {
  Write-Host ''
  Write-Host "  오류: $($_.Exception.Message)" -ForegroundColor Red
  Exit-Script 1
}
