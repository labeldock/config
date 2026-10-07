<#
.SYNOPSIS
  Scoop 을 설치하고, 체크박스로 고른 개발 도구(pwsh, gh, GitHub Desktop, psmux, mise, make)를 Scoop 으로 설치한다.

.DESCRIPTION
  1. Scoop 확인 - 없으면 설치 (일반 사용자 권한 권장)
  2. 체크박스 메뉴 - ↑↓ 이동, Space 선택, A 전체 선택/해제, Enter 설치, Esc/Q 취소
     취소하거나 아무것도 고르지 않으면 직접 설치할 수 있는 명령을 출력하고 종료한다.
  3. 선택한 도구 설치 - 필요한 버킷(extras, psmux)과 git 은 자동으로 준비

.EXAMPLE
  scoop-dev-utils.cmd 더블클릭
  또는 powershell -ExecutionPolicy Bypass -File .\scoop-dev-utils.ps1
#>
$ErrorActionPreference = 'Stop'

$ScoopRoot = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE 'scoop' }

$Buckets = @{
  extras = 'https://github.com/ScoopInstaller/Extras'
  psmux  = 'https://github.com/psmux/scoop-psmux'
}

$Tools = @(
  [pscustomobject]@{ Name = 'pwsh';   Bucket = 'main';   Command = 'pwsh';  Label = 'PowerShell 7';    Desc = '최신 PowerShell' }
  [pscustomobject]@{ Name = 'gh';     Bucket = 'main';   Command = 'gh';    Label = 'gh';              Desc = 'GitHub CLI' }
  [pscustomobject]@{ Name = 'github'; Bucket = 'extras'; Command = $null;   Label = 'GitHub Desktop';  Desc = 'GitHub 데스크톱 앱 (extras 버킷)' }
  [pscustomobject]@{ Name = 'psmux';  Bucket = 'psmux';  Command = 'psmux'; Label = 'psmux';           Desc = 'Windows 용 tmux (psmux 버킷)' }
  [pscustomobject]@{ Name = 'mise';   Bucket = 'main';   Command = 'mise';  Label = 'mise';            Desc = '런타임/툴 버전 매니저' }
  [pscustomobject]@{ Name = 'make';   Bucket = 'main';   Command = 'make';  Label = 'make';            Desc = 'GNU make' }
)

# ---------------------------------------------------------------------------
# 공통
# ---------------------------------------------------------------------------
function Write-Title([string]$title) {
  Write-Host ''
  Write-Host "== $title ==" -ForegroundColor Cyan
}

function Exit-Script([int]$code = 0) {
  Write-Host ''
  Read-Host 'Enter 를 누르면 창을 닫습니다' | Out-Null
  exit $code
}

function Test-ScoopApp([string]$name) {
  Test-Path (Join-Path $ScoopRoot "apps\$name\current")
}

# 설치 상태: scoop / other(scoop 외 경로에 이미 있음) / none
function Get-ToolState($tool) {
  if (Test-ScoopApp $tool.Name) { return 'scoop' }
  if ($tool.Command -and (Get-Command $tool.Command -ErrorAction SilentlyContinue)) { return 'other' }
  return 'none'
}

function Show-ManualCommands {
  Write-Title '직접 설치하려면 이런 명령으로도 가능합니다'
  Write-Host '  # Scoop (일반 PowerShell 창에서, 관리자 아님)' -ForegroundColor DarkGray
  Write-Host '  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser'
  Write-Host '  irm https://get.scoop.sh | iex'
  Write-Host ''
  Write-Host '  # 버킷 (git 필요)' -ForegroundColor DarkGray
  Write-Host '  scoop install git'
  foreach ($b in $Buckets.Keys | Sort-Object) { Write-Host "  scoop bucket add $b $($Buckets[$b])" }
  Write-Host ''
  Write-Host '  # 도구' -ForegroundColor DarkGray
  foreach ($t in $Tools) { Write-Host ("  scoop install {0,-8} # {1}" -f $t.Name, $t.Desc) }
  Write-Host ''
  Write-Host '  # 한 번에' -ForegroundColor DarkGray
  Write-Host "  scoop install $(($Tools | ForEach-Object Name) -join ' ')"
}

# ---------------------------------------------------------------------------
# 1. Scoop
# ---------------------------------------------------------------------------
function Install-Scoop {
  Write-Title '1. Scoop'
  if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host '  Scoop 이 이미 설치되어 있습니다.' -ForegroundColor Green
    return
  }

  Write-Host '  Scoop 이 없습니다. 지금 설치합니다. (사용자 홈 ~\scoop 에 설치, 관리자 권한 불필요)'
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
  if ($isAdmin) {
    Write-Host '  관리자 권한 창입니다. Scoop 은 일반 사용자 창에서 설치하는 것을 권장합니다.' -ForegroundColor Yellow
    $answer = (Read-Host '  [Q] 종료 후 일반 창에서 다시 실행 (권장)  [C] 관리자로 계속').Trim().ToUpper()
    if ($answer -ne 'C') { Exit-Script }
  }

  $policy = Get-ExecutionPolicy -Scope CurrentUser
  if ($policy -in @('Undefined', 'Restricted', 'AllSigned')) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  }
  [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

  $installer = Invoke-RestMethod -Uri 'https://get.scoop.sh'
  if ($isAdmin) { & ([scriptblock]::Create($installer)) -RunAsAdmin }
  else          { & ([scriptblock]::Create($installer)) }

  $shims = Join-Path $ScoopRoot 'shims'
  if ($env:PATH -notlike "*$shims*") { $env:PATH = "$shims;$env:PATH" }
  if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { throw 'Scoop 설치 후에도 scoop 명령을 찾을 수 없습니다.' }
  Write-Host '  Scoop 설치 완료.' -ForegroundColor Green
}

# ---------------------------------------------------------------------------
# 2. 체크박스 선택
# ---------------------------------------------------------------------------
function Test-InteractiveConsole {
  try { return -not [Console]::IsInputRedirected -and $Host.Name -eq 'ConsoleHost' }
  catch { return $false }
}

function Select-ToolsCheckbox($states) {
  # 기본값: 아직 설치되지 않은 도구만 체크
  $checked = @($states | ForEach-Object { $_.State -eq 'none' })
  $cursor = 0
  while ($true) {
    Clear-Host
    Write-Host '== 2. 설치할 도구 선택 ==' -ForegroundColor Cyan
    Write-Host '  ↑↓ 이동   Space 선택/해제   A 전체 선택/해제   Enter 설치   Esc/Q 취소' -ForegroundColor DarkGray
    Write-Host ''
    for ($i = 0; $i -lt $states.Count; $i++) {
      $s = $states[$i]
      $box = if ($checked[$i]) { '[x]' } else { '[ ]' }
      $mark = if ($i -eq $cursor) { '>' } else { ' ' }
      $status = switch ($s.State) { 'scoop' { '설치됨' } 'other' { '설치됨(scoop 외)' } default { '' } }
      $line = ' {0} {1} {2,-15} {3}' -f $mark, $box, $s.Tool.Label, $s.Tool.Desc
      $color = if ($i -eq $cursor) { 'Yellow' } else { 'Gray' }
      Write-Host $line -ForegroundColor $color -NoNewline
      if ($status) { Write-Host "  ($status)" -ForegroundColor DarkGreen } else { Write-Host '' }
    }
    Write-Host ''
    Write-Host "  선택: $(@($checked | Where-Object { $_ }).Count)개" -ForegroundColor DarkGray

    $key = [Console]::ReadKey($true)
    switch ($key.Key) {
      'UpArrow'   { $cursor = ($cursor - 1 + $states.Count) % $states.Count }
      'DownArrow' { $cursor = ($cursor + 1) % $states.Count }
      'Spacebar'  { $checked[$cursor] = -not $checked[$cursor] }
      'A' {
        $all = -not ($checked -contains $false)
        for ($i = 0; $i -lt $checked.Count; $i++) { $checked[$i] = -not $all }
      }
      'Enter'  { return @(for ($i = 0; $i -lt $states.Count; $i++) { if ($checked[$i]) { $states[$i].Tool } }) }
      'Escape' { return }
      'Q'      { return }
    }
  }
}

# 체크박스를 쓸 수 없는 환경(ISE, 입력 리다이렉트 등)용
function Select-ToolsFallback($states) {
  Write-Title '2. 설치할 도구'
  foreach ($s in $states) {
    $status = switch ($s.State) { 'scoop' { ' (설치됨)' } 'other' { ' (설치됨, scoop 외)' } default { '' } }
    Write-Host ("  - {0,-15} {1}{2}" -f $s.Tool.Label, $s.Tool.Desc, $status)
  }
  $answer = (Read-Host '  아직 설치되지 않은 도구를 모두 설치할까요? [Y/N]').Trim().ToUpper()
  if ($answer -ne 'Y') { return }
  return @($states | Where-Object { $_.State -eq 'none' } | ForEach-Object { $_.Tool })
}

# ---------------------------------------------------------------------------
# 3. 설치
# ---------------------------------------------------------------------------
function Install-Tools($tools) {
  Write-Title '3. 설치'
  $needBuckets = @($tools | Where-Object { $_.Bucket -ne 'main' } | ForEach-Object Bucket | Sort-Object -Unique)

  if ($needBuckets.Count -gt 0) {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Write-Host '  버킷 추가에 필요한 git 을 먼저 설치합니다.' -ForegroundColor DarkGray
      & scoop install git
    }
    $existing = @(& scoop bucket list | ForEach-Object { if ($_.Name) { $_.Name } else { "$_".Trim() } })
    foreach ($b in $needBuckets) {
      if ($existing -contains $b) { continue }
      Write-Host "  버킷 추가: $b" -ForegroundColor DarkGray
      & scoop bucket add $b $Buckets[$b]
    }
  }

  $results = foreach ($t in $tools) {
    Write-Host ''
    Write-Host "  >> scoop install $($t.Name)" -ForegroundColor Cyan
    & scoop install $t.Name | Out-Host
    [pscustomobject]@{ Tool = $t; Ok = (Test-ScoopApp $t.Name) }
  }

  Write-Title '결과'
  foreach ($r in $results) {
    if ($r.Ok) { Write-Host "  [ OK ] $($r.Tool.Label)" -ForegroundColor Green }
    else       { Write-Host "  [실패] $($r.Tool.Label)  -> scoop install $($r.Tool.Name) 로 다시 시도해 보세요" -ForegroundColor Red }
  }

  $names = @($tools | ForEach-Object Name)
  Write-Host ''
  Write-Host '  다음 단계' -ForegroundColor Cyan
  Write-Host '   - 새 터미널을 열어야 PATH 가 반영됩니다.'
  if ($names -contains 'pwsh') { Write-Host '   - PowerShell 7 실행: pwsh' }
  if ($names -contains 'gh')   { Write-Host '   - GitHub 로그인: gh auth login' }
  if ($names -contains 'psmux') { Write-Host '   - psmux 실행: psmux (tmux 명령도 사용 가능)' }
  Write-Host '   - 전체 업데이트: scoop update *'
}

# ---------------------------------------------------------------------------
try {
  Install-Scoop

  $states = @($Tools | ForEach-Object { [pscustomobject]@{ Tool = $_; State = Get-ToolState $_ } })
  $selected = @(if (Test-InteractiveConsole) { Select-ToolsCheckbox $states } else { Select-ToolsFallback $states })

  if ($selected.Count -eq 0) {
    Write-Host ''
    Write-Host '  설치할 도구를 선택하지 않았습니다.' -ForegroundColor Yellow
    Show-ManualCommands
    Exit-Script
  }

  Install-Tools $selected
  Exit-Script
} catch {
  Write-Host ''
  Write-Host "  오류: $($_.Exception.Message)" -ForegroundColor Red
  Show-ManualCommands
  Exit-Script 1
}
