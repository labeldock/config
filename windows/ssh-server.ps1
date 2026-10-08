<#
.SYNOPSIS
  Windows OpenSSH 서버 활성화, ed25519 키 생성, authorized_keys(접속 허용 키) 관리.

.DESCRIPTION
  메인 화면에서 현재 상태를 보여주고 메뉴로 작업한다.
   [1] SSH 서버 설치/활성화   - OpenSSH Server 설치, sshd 자동 시작, 방화벽 22/TCP 허용
   [2] SSH 서버 비활성화      - sshd 중지/사용 안 함, 방화벽 규칙 끔 (설치는 유지)
   [3] ed25519 키 생성        - ~\.ssh\id_ed25519 (주석: 사용자@이 컴퓨터 이름)
   [4] 접속 허용 키 관리      - authorized_keys 목록/추가/제거

  키는 화면에 "앞 3자리 + ****** + 뒤 3자리 + 사용자(주석)" 로만 표시한다. 예) AAA******k2q labeldock@gmail.com
  sshd_config 의 AuthorizedKeysFile 을 읽어 sshd 가 실제로 읽는 키 파일과 적용 여부를 보여준다.
  (관리자 계정은 기본 설정상 C:\ProgramData\ssh\administrators_authorized_keys 를 쓴다)

.EXAMPLE
  ssh-server.cmd 더블클릭
  또는 powershell -ExecutionPolicy Bypass -File .\ssh-server.ps1
#>
[CmdletBinding()]
param(
  [string]$TargetUser,
  [string]$TargetSid
)

$ErrorActionPreference = 'Stop'
$SshDataDir   = Join-Path $env:ProgramData 'ssh'
$SshdConfig   = Join-Path $SshDataDir 'sshd_config'
$FirewallRule = 'OpenSSH-Server-In-TCP'
$SidSystem    = 'S-1-5-18'
$SidAdmins    = 'S-1-5-32-544'

# ---------------------------------------------------------------------------
# 관리자 권한으로 재실행 (원래 사용자 정보를 넘겨서 대상 계정이 바뀌지 않게)
# ---------------------------------------------------------------------------
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $TargetUser) { $TargetUser = $identity.Name }
if (-not $TargetSid)  { $TargetSid  = $identity.User.Value }

$isAdmin = ([Security.Principal.WindowsPrincipal]$identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host '관리자 권한이 필요합니다. UAC 창에서 승인해 주세요...' -ForegroundColor Yellow
  $exe = (Get-Process -Id $PID).Path
  $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
               '-TargetUser', "`"$TargetUser`"", '-TargetSid', $TargetSid)
  try { Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs | Out-Null }
  catch { Write-Host '관리자 권한 승인이 취소되었습니다.' -ForegroundColor Red }
  exit
}

$TargetUserName = ($TargetUser -split '\\')[-1]
$ProfileDir = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$TargetSid" -ErrorAction SilentlyContinue).ProfileImagePath
if (-not $ProfileDir) { $ProfileDir = $env:USERPROFILE }
$UserSshDir  = Join-Path $ProfileDir '.ssh'
$UserKeyPath = Join-Path $UserSshDir 'id_ed25519'

# ---------------------------------------------------------------------------
# 공통 UI
# ---------------------------------------------------------------------------
function Get-HostAddresses {
  try {
    @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
      Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
      ForEach-Object IPAddress)
  } catch { @() }
}

function Show-Header([string]$title) {
  Clear-Host
  $ips = (Get-HostAddresses) -join ', '
  Write-Host '=================================================================' -ForegroundColor DarkCyan
  Write-Host "  Windows SSH 서버 / 키 관리   |   $title" -ForegroundColor Cyan
  Write-Host '=================================================================' -ForegroundColor DarkCyan
  Write-Host '  이 컴퓨터(호스트): ' -ForegroundColor DarkGray -NoNewline
  Write-Host $env:COMPUTERNAME -ForegroundColor White -NoNewline
  if ($ips) { Write-Host "   IP: $ips" -ForegroundColor DarkGray } else { Write-Host '' }
  Write-Host "  대상 계정       : $TargetUser" -ForegroundColor DarkGray
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

function Exit-Script {
  Write-Host ''
  Read-Host 'Enter 를 누르면 창을 닫습니다' | Out-Null
  exit
}

# ---------------------------------------------------------------------------
# 키 표시 (앞 3자리 + 마스킹 + 뒤 3자리) / 파싱
# ---------------------------------------------------------------------------
# ed25519 키 본문은 항상 AAA 로 시작한다 (키 종류 표시로 충분)
function Format-MaskedKey([string]$body) {
  if ($body.Length -le 6) { return '******' }
  return '{0}******{1}' -f $body.Substring(0, 3), $body.Substring($body.Length - 3)
}

$KeyLinePattern = '^(?:(?<opts>.+?)\s+)?(?<type>ssh-ed25519|ssh-rsa|ssh-dss|ecdsa-sha2-nistp\d+|sk-[\w.@-]+)\s+(?<body>[A-Za-z0-9+/]+={0,2})(?:\s+(?<comment>.*))?$'

function ConvertFrom-KeyLine([string]$line) {
  $m = [regex]::Match($line.Trim(), $KeyLinePattern)
  if (-not $m.Success) { return $null }
  [pscustomobject]@{
    Type = $m.Groups['type'].Value; Body = $m.Groups['body'].Value
    Options = $m.Groups['opts'].Value; Comment = $m.Groups['comment'].Value.Trim()
  }
}

# 예) abc******k2q labeldock@gmail.com  /  cds******dfv (경고:사용자미입력)
function Write-KeyRow([string]$prefix, $key) {
  Write-Host "$prefix " -NoNewline
  Write-Host (Format-MaskedKey $key.Body) -ForegroundColor DarkCyan -NoNewline
  if ($key.Comment) { Write-Host " $($key.Comment)" }
  else              { Write-Host ' (경고:사용자미입력)' -ForegroundColor Yellow }
  if ($key.Options) { Write-Host "        옵션: $($key.Options)" -ForegroundColor DarkGray }
}

# ---------------------------------------------------------------------------
# 상태 조회
# ---------------------------------------------------------------------------
function Get-SshdService { Get-Service -Name sshd -ErrorAction SilentlyContinue }

function Get-SshKeygen {
  $exe = Join-Path $env:WINDIR 'System32\OpenSSH\ssh-keygen.exe'
  if (Test-Path $exe) { return $exe }
  $cmd = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Test-TargetIsAdmin {
  try {
    $group = [ADSI]"WinNT://./Administrators,group"
    foreach ($m in $group.psbase.Invoke('Members')) {
      $bytes = $m.GetType().InvokeMember('objectSid', 'GetProperty', $null, $m, $null)
      $sid = New-Object Security.Principal.SecurityIdentifier($bytes, 0)
      if ($sid.Value -eq $TargetSid) { return $true }
    }
    return $false
  } catch { return $true }
}

function Resolve-SshdPath([string]$p) {
  $p = $p.Replace('__PROGRAMDATA__', $env:ProgramData).Replace('%h', $ProfileDir).Replace('%u', $TargetUserName).Replace('%%', '%')
  $p = $p.Replace('/', '\')
  if (-not [IO.Path]::IsPathRooted($p)) { $p = Join-Path $ProfileDir $p }
  return $p
}

# sshd_config 의 AuthorizedKeysFile 설정으로 sshd 가 읽는 키 파일 목록을 만든다.
# Windows 기본값: 일반 사용자는 ~\.ssh\authorized_keys,
#                 관리자 그룹은 "Match Group administrators" 블록의 administrators_authorized_keys
function Get-SshdKeyFiles {
  $global = @('.ssh/authorized_keys')
  $admin  = @('__PROGRAMDATA__/ssh/administrators_authorized_keys')
  if (Test-Path $SshdConfig) {
    $global = @('.ssh/authorized_keys', '.ssh/authorized_keys2')   # 설정이 없을 때 OpenSSH 기본값
    $admin = @()
    $match = $null
    foreach ($raw in Get-Content $SshdConfig) {
      $line = $raw.Trim()
      if (-not $line -or $line.StartsWith('#')) { continue }
      if ($line -match '^Match\s+(.*)$') { $match = $Matches[1]; continue }
      if ($line -match '^AuthorizedKeysFile\s+(.+)$') {
        $paths = @($Matches[1].Trim() -split '\s+')
        if (-not $match) { $global = $paths }
        elseif ($match -match '^Group\s+administrators\s*$') { $admin = $paths }
      }
    }
  }

  $adminApplies = ($admin.Count -gt 0) -and (Test-TargetIsAdmin)
  $files = New-Object System.Collections.Generic.List[object]
  foreach ($a in $admin) {
    $files.Add([pscustomobject]@{ Path = (Resolve-SshdPath $a); Scope = '관리자 그룹용'; Applies = $adminApplies; IsAdminFile = $true })
  }
  foreach ($g in $global) {
    $files.Add([pscustomobject]@{ Path = (Resolve-SshdPath $g); Scope = '일반 사용자용'; Applies = (-not $adminApplies); IsAdminFile = $false })
  }
  return $files
}

# 이 스크립트가 추가/제거하는 파일 = 대상 계정에 적용되는 첫 번째 파일
function Get-AuthorizedKeysPath {
  return @(Get-SshdKeyFiles | Where-Object { $_.Applies })[0]
}

function Write-SshdKeyFiles {
  Write-Host '  sshd 가 읽는 키 파일 (sshd_config 기준)' -ForegroundColor Cyan
  foreach ($f in Get-SshdKeyFiles) {
    if ($f.Applies) { Write-Host '   [적용] ' -ForegroundColor Green -NoNewline }
    else            { Write-Host '   [무시] ' -ForegroundColor DarkGray -NoNewline }
    $count = if (Test-Path $f.Path) { "키 $(@(Get-AuthorizedKeys $f.Path).Count)개" } else { '파일 없음' }
    Write-Host $f.Path -NoNewline
    Write-Host "  ($($f.Scope), $count)" -ForegroundColor DarkGray
  }
  if (Test-TargetIsAdmin) {
    Write-Host '   * 대상 계정이 관리자라 ~\.ssh\authorized_keys 는 무시되고 관리자 그룹용 파일만 읽습니다.' -ForegroundColor DarkGray
  }
}

function Read-KeyFileLines([string]$path) {
  if (-not (Test-Path $path)) { return @() }
  $text = [IO.File]::ReadAllText($path).TrimStart([char]0xFEFF)
  return @($text -split "`r?`n" | Where-Object { $_ -ne '' })
}

function Get-AuthorizedKeys([string]$path) {
  $lines = @(Read-KeyFileLines $path)
  $list = New-Object System.Collections.Generic.List[object]
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*#') { continue }
    $k = ConvertFrom-KeyLine $lines[$i]
    if ($k) { $k | Add-Member -NotePropertyName LineIndex -NotePropertyValue $i; $list.Add($k) }
  }
  return $list
}

# ---------------------------------------------------------------------------
# 파일 권한 (sshd 는 권한이 넓으면 키 파일을 무시한다)
# ---------------------------------------------------------------------------
function Set-StrictAcl([string]$path, [string[]]$sids) {
  $grants = @('/inheritance:r')
  foreach ($s in $sids) { $grants += @('/grant', "*${s}:F") }
  & icacls.exe $path @grants | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "권한 설정 실패: $path" }
}

function Write-KeyFileLines([string]$path, [string[]]$lines, [bool]$isAdminFile) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $text = if ($lines.Count) { ($lines -join "`r`n") + "`r`n" } else { '' }
  [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding $false))   # BOM 없이
  if ($isAdminFile) { Set-StrictAcl $path @($SidAdmins, $SidSystem) }
  else              { Set-StrictAcl $path @($TargetSid, $SidSystem, $SidAdmins) }
}

# ---------------------------------------------------------------------------
# [1] / [2] SSH 서버
# ---------------------------------------------------------------------------
function Enable-SshServer {
  Show-Header 'SSH 서버 설치/활성화'
  if (-not (Get-SshdService)) {
    Write-Host '  OpenSSH Server 를 설치합니다. 몇 분 걸릴 수 있습니다...' -ForegroundColor Cyan
    Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
    if (-not (Get-SshdService)) { throw 'OpenSSH Server 설치 후에도 sshd 서비스를 찾을 수 없습니다.' }
  }
  Write-Check $true 'OpenSSH Server 설치됨'

  Set-Service -Name sshd -StartupType Automatic
  Start-Service -Name sshd
  Write-Check $true 'sshd 실행 + 부팅 시 자동 시작'

  $rule = Get-NetFirewallRule -Name $FirewallRule -ErrorAction SilentlyContinue
  if (-not $rule) {
    New-NetFirewallRule -Name $FirewallRule -DisplayName 'OpenSSH Server (sshd)' -Enabled True `
      -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
  } else {
    Enable-NetFirewallRule -Name $FirewallRule
  }
  Write-Check $true '방화벽 22/TCP 허용'
  Wait-Enter
}

function Disable-SshServer {
  Show-Header 'SSH 서버 비활성화'
  if (-not (Get-SshdService)) { Write-Host '  OpenSSH Server 가 설치되어 있지 않습니다.'; Wait-Enter; return }
  Write-Host '  sshd 를 중지하고 자동 시작을 끄며 방화벽 규칙을 비활성화합니다. (프로그램은 남겨둠)'
  if ((Read-Choice '  진행할까요? [Y] 예  [N] 아니오' @('Y', 'N')) -ne 'Y') { return }
  Stop-Service -Name sshd -Force
  Set-Service -Name sshd -StartupType Disabled
  Write-Check $true 'sshd 중지 + 사용 안 함'
  if (Get-NetFirewallRule -Name $FirewallRule -ErrorAction SilentlyContinue) {
    Disable-NetFirewallRule -Name $FirewallRule
    Write-Check $true '방화벽 규칙 비활성화'
  }
  Write-Host ''
  Write-Host '  완전히 제거하려면: Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0' -ForegroundColor DarkGray
  Wait-Enter
}

# ---------------------------------------------------------------------------
# [3] ed25519 키
# ---------------------------------------------------------------------------
function Get-OwnPublicKey {
  $pub = "$UserKeyPath.pub"
  if (-not (Test-Path $pub)) { return $null }
  return ConvertFrom-KeyLine (Get-Content $pub -TotalCount 1)
}

function New-Ed25519Key {
  Show-Header 'ed25519 키 생성'
  $keygen = Get-SshKeygen
  if (-not $keygen) {
    Write-Host '  ssh-keygen 이 없어 OpenSSH Client 를 설치합니다...' -ForegroundColor Cyan
    Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' | Out-Null
    $keygen = Get-SshKeygen
    if (-not $keygen) { throw 'ssh-keygen 을 찾을 수 없습니다.' }
  }

  $existing = Get-OwnPublicKey
  if ($existing) {
    Write-Host '  이미 키가 있습니다.' -ForegroundColor Yellow
    Write-KeyRow '  ' $existing
    Write-Host "  위치: $UserKeyPath" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  새로 만들면 이 키로 등록해 둔 다른 서버/GitHub 에는 더 이상 접속할 수 없습니다.' -ForegroundColor Yellow
    if ((Read-Choice '  [O] 기존 키 백업 후 새로 만들기  [B] 돌아가기' @('O', 'B')) -ne 'O') { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    Move-Item $UserKeyPath "$UserKeyPath.bak-$stamp"
    Move-Item "$UserKeyPath.pub" "$UserKeyPath.pub.bak-$stamp"
    Write-Host "  기존 키 백업: $UserKeyPath.bak-$stamp" -ForegroundColor DarkGray
  }

  if (-not (Test-Path $UserSshDir)) { New-Item -ItemType Directory -Path $UserSshDir -Force | Out-Null }
  $comment = "$TargetUserName@$env:COMPUTERNAME"
  Write-Host ''
  Write-Host "  키 주석(사용자 표시): $comment" -ForegroundColor Cyan
  Write-Host '  암호(passphrase)를 두 번 묻습니다. 비워 두려면 Enter 두 번.' -ForegroundColor DarkGray
  Write-Host ''
  & $keygen -t ed25519 -C $comment -f $UserKeyPath
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $UserKeyPath)) { throw '키 생성에 실패했습니다.' }

  # 관리자 권한으로 만든 파일이라 권한을 대상 사용자 기준으로 정리 (ssh 가 넓은 권한의 개인키를 거부함)
  Set-StrictAcl $UserKeyPath @($TargetSid, $SidSystem, $SidAdmins)

  Write-Host ''
  Write-Check $true '키 생성 완료'
  Write-KeyRow '  ' (Get-OwnPublicKey)
  Write-Host "  개인키: $UserKeyPath" -ForegroundColor DarkGray
  Write-Host "  공개키: $UserKeyPath.pub  (다른 서버/GitHub 에 등록하는 쪽)" -ForegroundColor DarkGray
  Write-Host ''
  if ((Read-Choice '  [C] 공개키 전체를 클립보드에 복사  [B] 돌아가기' @('C', 'B')) -eq 'C') {
    Get-Content "$UserKeyPath.pub" -TotalCount 1 | Set-Clipboard
    Write-Host '  복사했습니다. 등록할 곳에 붙여 넣으세요.' -ForegroundColor Green
    Wait-Enter
  }
}

# ---------------------------------------------------------------------------
# [4] authorized_keys 관리
# ---------------------------------------------------------------------------
function Add-AuthorizedKeyLines([string[]]$candidates, $target) {
  $lines = @(Read-KeyFileLines $target.Path)
  $current = @(Get-AuthorizedKeys $target.Path)
  $keygen = Get-SshKeygen
  $added = 0

  foreach ($raw in $candidates) {
    if (-not $raw -or $raw.Trim().StartsWith('#')) { continue }
    $k = ConvertFrom-KeyLine $raw
    if (-not $k) { Write-Host "  [건너뜀] 공개키 형식이 아닙니다: $($raw.Substring(0, [Math]::Min(20, $raw.Length)))..." -ForegroundColor Red; continue }
    if ($current | Where-Object { $_.Body -eq $k.Body }) {
      Write-Host '  [건너뜀] 이미 등록된 키입니다:' -ForegroundColor Yellow -NoNewline
      Write-KeyRow '' $k
      continue
    }
    if ($keygen) {
      $tmp = [IO.Path]::GetTempFileName()
      try {
        [IO.File]::WriteAllText($tmp, "$($k.Type) $($k.Body)`n")
        & $keygen -l -f $tmp *> $null
        $valid = ($LASTEXITCODE -eq 0)
      } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
      if (-not $valid) { Write-Host '  [건너뜀] 손상된 공개키입니다.' -ForegroundColor Red; continue }
    }

    # 누구의 키인지 알 수 있게 주석(사용자)이 없으면 입력받는다 (건너뛰면 목록에 경고 표시)
    if (-not $k.Comment) {
      Write-Host ''
      Write-Host "  이 키에는 사용자 정보가 없습니다: $(Format-MaskedKey $k.Body)" -ForegroundColor Yellow
      $k.Comment = (Read-Host '  사용자 (예: labeldock@gmail.com, Enter = 건너뜀)').Trim() -replace '\s', '-'
    }

    $line = (@($k.Options, $k.Type, $k.Body, $k.Comment) | Where-Object { $_ }) -join ' '
    $lines += $line
    $current += $k
    $added++
    Write-Host '  [추가]' -ForegroundColor Green -NoNewline
    Write-KeyRow '' $k
  }

  if ($added -gt 0) { Write-KeyFileLines $target.Path $lines $target.IsAdminFile }
  Write-Host ''
  Write-Host "  $added 개 추가했습니다." -ForegroundColor $(if ($added) { 'Green' } else { 'Yellow' })
}

function Remove-AuthorizedKey($target, $keys) {
  if ($keys.Count -eq 0) { return }
  $answer = (Read-Host '  제거할 번호').Trim()
  $n = 0
  if (-not [int]::TryParse($answer, [ref]$n) -or $n -lt 1 -or $n -gt $keys.Count) {
    Write-Host '  올바른 번호가 아닙니다.' -ForegroundColor Red; Wait-Enter; return
  }
  $k = $keys[$n - 1]
  Write-Host ''
  Write-KeyRow '  ' $k
  $who = if ($k.Comment) { $k.Comment } else { '사용자미입력' }
  if ((Read-Choice "  '$who' 의 키를 제거할까요? [Y] 예  [N] 아니오" @('Y', 'N')) -ne 'Y') { return }
  $lines = @(Read-KeyFileLines $target.Path)
  $kept = @(for ($i = 0; $i -lt $lines.Count; $i++) { if ($i -ne $k.LineIndex) { $lines[$i] } })
  Write-KeyFileLines $target.Path $kept $target.IsAdminFile
  Write-Host '  제거했습니다. 이 PC 에서는 더 이상 그 키로 접속할 수 없습니다.' -ForegroundColor Green
  Wait-Enter
}

function Invoke-KeyManager {
  while ($true) {
    Show-Header '접속 허용 키 (authorized_keys)'
    $target = Get-AuthorizedKeysPath
    Write-SshdKeyFiles
    Write-Host ''
    Write-Host "  편집 중: $($target.Path)" -ForegroundColor Cyan
    Write-Host "  아래 키를 가진 PC 는 비밀번호 없이 $TargetUserName@$env:COMPUTERNAME 로 접속할 수 있습니다." -ForegroundColor DarkGray
    Write-Host ''

    $keys = @(Get-AuthorizedKeys $target.Path)
    if ($keys.Count -eq 0) { Write-Host '  (등록된 키 없음)' -ForegroundColor Yellow }
    for ($i = 0; $i -lt $keys.Count; $i++) { Write-KeyRow ('  [{0}]' -f ($i + 1)) $keys[$i] }
    Write-Host ''

    $keysMenu = @('A', 'M', 'B')
    $menu = '  [A] 붙여넣기로 추가  [M] 이 PC 키 추가  '
    if ($keys.Count) { $keysMenu += 'D'; $menu += '[D] 제거  ' }
    $menu += '[B] 뒤로'

    switch (Read-Choice $menu $keysMenu) {
      'A' {
        Write-Host '  다른 PC 의 공개키 한 줄(ssh-ed25519 AAAA... 사용자)을 붙여 넣으세요.' -ForegroundColor DarkGray
        Add-AuthorizedKeyLines @((Read-Host '  공개키')) $target
        Wait-Enter
      }
      'M' {
        if (Test-Path "$UserKeyPath.pub") { Add-AuthorizedKeyLines @(Get-Content "$UserKeyPath.pub") $target }
        else { Write-Host '  이 PC 에 ed25519 키가 없습니다. 메인 메뉴 [3] 에서 먼저 만드세요.' -ForegroundColor Yellow }
        Wait-Enter
      }
      'D' { Remove-AuthorizedKey $target $keys }
      'B' { return }
    }
  }
}

# ---------------------------------------------------------------------------
# 메인
# ---------------------------------------------------------------------------
function Invoke-Main {
  while ($true) {
    Show-Header '메인'
    $svc = Get-SshdService
    $rule = Get-NetFirewallRule -Name $FirewallRule -ErrorAction SilentlyContinue
    $own = Get-OwnPublicKey
    $target = Get-AuthorizedKeysPath
    $keyCount = @(Get-AuthorizedKeys $target.Path).Count

    Write-Check ([bool]$svc) 'OpenSSH Server 설치'
    Write-Check ($svc -and $svc.Status -eq 'Running') 'sshd 실행 중' $(if ($svc) { "시작 유형: $($svc.StartType)" } else { '' })
    Write-Check ($rule -and "$($rule.Enabled)" -eq 'True') '방화벽 22/TCP 허용'
    if ($own) { Write-Check $true 'ed25519 키' "$(Format-MaskedKey $own.Body) $($own.Comment)" }
    else      { Write-Check $false 'ed25519 키' '없음' }
    Write-Check ($keyCount -gt 0) "접속 허용 키 $keyCount 개" (Split-Path $target.Path -Leaf)
    Write-Host ''
    Write-SshdKeyFiles

    if ($svc -and $svc.Status -eq 'Running') {
      Write-Host ''
      Write-Host '  다른 PC 에서 접속:' -ForegroundColor Cyan
      Write-Host "   ssh $TargetUserName@$env:COMPUTERNAME"
      foreach ($ip in Get-HostAddresses) { Write-Host "   ssh $TargetUserName@$ip" }
    }

    Write-Host ''
    Write-Host '  [1] SSH 서버 설치/활성화   [2] SSH 서버 비활성화'
    Write-Host '  [3] ed25519 키 생성        [4] 접속 허용 키 관리 (authorized_keys)'
    Write-Host '  [Q] 종료'
    switch (Read-Choice '  선택' @('1', '2', '3', '4', 'Q')) {
      '1' { Enable-SshServer }
      '2' { Disable-SshServer }
      '3' { New-Ed25519Key }
      '4' { Invoke-KeyManager }
      'Q' { Exit-Script }
    }
  }
}

try {
  Invoke-Main
} catch {
  Write-Host ''
  Write-Host "  오류: $($_.Exception.Message)" -ForegroundColor Red
  Exit-Script
}
