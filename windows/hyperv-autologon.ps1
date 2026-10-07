<#
.SYNOPSIS
  Hyper-V VM 전용: 비밀번호 없이 자동 로그인하고 화면이 꺼지지 않은 채 대기(standby)하도록 구성/복원한다.

.DESCRIPTION
  Step 1  경고 - VM 전용 장치이며 호스트(실제 PC)에 적용하면 보안상 위험함을 안내
  Step 2  Windows Hello 구성 확인 - 켜져 있으면 끄는 위치를 안내하고 새로고침
  Step 3  자동 로그인 / 화면 유지 설치 여부 확인
          - 설치됨   : 완료 안내 + [나가기] / [복원]
          - 미설치   : Sysinternals Autologon(winget: Microsoft.Sysinternals.Autologon)으로
                       자동 로그인 등록 + 화면 꺼짐/절전/잠금 해제

  비밀번호는 Autologon 이 LSA Secret(암호화)으로 저장한다. 레지스트리 평문 저장 아님.

.EXAMPLE
  hyperv-autologon.cmd 더블클릭
  또는 powershell -ExecutionPolicy Bypass -File .\hyperv-autologon.ps1
#>
[CmdletBinding()]
param(
  [string]$TargetUser,
  [string]$TargetSid
)

$ErrorActionPreference = 'Stop'
$BackupDir  = Join-Path $env:ProgramData 'HyperVAutoLogon'
$BackupFile = Join-Path $BackupDir 'backup.json'
$WinlogonKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$PasswordLessKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device'

# 화면 유지에 필요한 전원 설정 (powercfg alias, 원하는 값)
$PowerSettings = @(
  @{ Sub = 'SUB_VIDEO'; Setting = 'VIDEOIDLE';     Want = 0; Label = '디스플레이 끄기: 안 함' },
  @{ Sub = 'SUB_SLEEP'; Setting = 'STANDBYIDLE';   Want = 0; Label = '절전 모드: 안 함' },
  @{ Sub = 'SUB_SLEEP'; Setting = 'HIBERNATEIDLE'; Want = 0; Label = '최대 절전: 안 함' },
  @{ Sub = 'SUB_NONE';  Setting = 'CONSOLELOCK';   Want = 0; Label = '절전 해제 시 로그인 요구: 안 함' }
)

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

# ---------------------------------------------------------------------------
# LSA Secret 확인/삭제, 자격 증명 검증 (Win32 API)
# ---------------------------------------------------------------------------
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HvAutoLogonNative {
  [StructLayout(LayoutKind.Sequential)]
  struct LSA_UNICODE_STRING { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }
  [StructLayout(LayoutKind.Sequential)]
  struct LSA_OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory; public IntPtr ObjectName; public uint Attributes; public IntPtr SecurityDescriptor; public IntPtr SecurityQualityOfService; }

  [DllImport("advapi32.dll")] static extern uint LsaOpenPolicy(IntPtr systemName, ref LSA_OBJECT_ATTRIBUTES attrs, uint access, out IntPtr handle);
  [DllImport("advapi32.dll")] static extern uint LsaRetrievePrivateData(IntPtr handle, ref LSA_UNICODE_STRING key, out IntPtr data);
  [DllImport("advapi32.dll")] static extern uint LsaStorePrivateData(IntPtr handle, ref LSA_UNICODE_STRING key, IntPtr data);
  [DllImport("advapi32.dll")] static extern uint LsaFreeMemory(IntPtr p);
  [DllImport("advapi32.dll")] static extern uint LsaClose(IntPtr h);
  [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
  static extern bool LogonUser(string user, string domain, string password, int logonType, int provider, out IntPtr token);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);

  const uint POLICY_ALL_ACCESS = 0x000F0FFF;

  static IntPtr Open() {
    var attrs = new LSA_OBJECT_ATTRIBUTES();
    attrs.Length = Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));
    IntPtr h;
    uint st = LsaOpenPolicy(IntPtr.Zero, ref attrs, POLICY_ALL_ACCESS, out h);
    if (st != 0) throw new Exception("LsaOpenPolicy failed: 0x" + st.ToString("X8"));
    return h;
  }

  static LSA_UNICODE_STRING Str(string s) {
    var u = new LSA_UNICODE_STRING();
    u.Buffer = Marshal.StringToHGlobalUni(s);
    u.Length = (ushort)(s.Length * 2);
    u.MaximumLength = (ushort)(u.Length + 2);
    return u;
  }

  public static bool HasSecret(string name) {
    IntPtr h = Open();
    var key = Str(name);
    try {
      IntPtr data;
      uint st = LsaRetrievePrivateData(h, ref key, out data);
      if (st != 0 || data == IntPtr.Zero) return false;
      var v = (LSA_UNICODE_STRING)Marshal.PtrToStructure(data, typeof(LSA_UNICODE_STRING));
      LsaFreeMemory(data);
      return v.Length > 0;
    } finally { Marshal.FreeHGlobal(key.Buffer); LsaClose(h); }
  }

  public static void DeleteSecret(string name) {
    IntPtr h = Open();
    var key = Str(name);
    try { LsaStorePrivateData(h, ref key, IntPtr.Zero); }
    finally { Marshal.FreeHGlobal(key.Buffer); LsaClose(h); }
  }

  public static bool ValidateLogon(string user, string domain, string password) {
    IntPtr token;
    if (!LogonUser(user, domain, password, 2, 0, out token)) return false;
    CloseHandle(token);
    return true;
  }
}
'@

# ---------------------------------------------------------------------------
# 공통 UI
# ---------------------------------------------------------------------------
function Show-Header([string]$title) {
  Clear-Host
  Write-Host '=================================================================' -ForegroundColor DarkCyan
  Write-Host "  Hyper-V VM 자동 로그인 / 화면 유지 설정   |   $title" -ForegroundColor Cyan
  Write-Host '=================================================================' -ForegroundColor DarkCyan
  Write-Host "  대상 계정: $TargetUser" -ForegroundColor DarkGray
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

function Exit-Script {
  Write-Host ''
  Read-Host 'Enter 를 누르면 창을 닫습니다' | Out-Null
  exit
}

# ---------------------------------------------------------------------------
# 상태 조회
# ---------------------------------------------------------------------------
function Get-RegValue([string]$path, [string]$name) {
  $item = Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
  if ($item) { return $item.$name }
  return $null
}

function Test-HyperVGuest {
  $cs = Get-CimInstance Win32_ComputerSystem
  return ($cs.Manufacturer -eq 'Microsoft Corporation' -and $cs.Model -eq 'Virtual Machine')
}

function Get-HelloState {
  $passwordless = Get-RegValue $PasswordLessKey 'DevicePasswordLessBuildVersion'
  $pinKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\NgcPin\Credentials\$TargetSid"
  $policy = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork' 'Enabled'
  [pscustomobject]@{
    HelloOnly = ($passwordless -eq 2)          # "Microsoft 계정에 Windows Hello 로그인만 허용"
    Pin       = (Test-Path $pinKey)            # PIN(Windows Hello) 등록 여부
    Managed   = ($policy -eq 1)                # 회사/학교 정책(Windows Hello for Business)
  }
}

function Get-PowerIndex([string]$sub, [string]$setting) {
  $out = (& powercfg /q SCHEME_CURRENT $sub $setting 2>$null) -join "`n"
  $hex = [regex]::Matches($out, '0x[0-9a-fA-F]{8}')
  if ($hex.Count -lt 2) { return $null }
  [pscustomobject]@{
    AC = [Convert]::ToInt32($hex[$hex.Count - 2].Value.Substring(2), 16)
    DC = [Convert]::ToInt32($hex[$hex.Count - 1].Value.Substring(2), 16)
  }
}

function Set-PowerIndex([string]$sub, [string]$setting, [int]$ac, [int]$dc) {
  & powercfg /setacvalueindex SCHEME_CURRENT $sub $setting $ac | Out-Null
  & powercfg /setdcvalueindex SCHEME_CURRENT $sub $setting $dc | Out-Null
}

function Get-UserDesktopKey { "Registry::HKEY_USERS\$TargetSid\Control Panel\Desktop" }

function Get-SetupState {
  $autoAdmin = Get-RegValue $WinlogonKey 'AutoAdminLogon'
  $userName  = Get-RegValue $WinlogonKey 'DefaultUserName'
  $domain    = Get-RegValue $WinlogonKey 'DefaultDomainName'
  $plainPw   = Get-RegValue $WinlogonKey 'DefaultPassword'
  $lsaPw     = [HvAutoLogonNative]::HasSecret('DefaultPassword')

  $checks = New-Object System.Collections.Generic.List[object]
  $checks.Add([pscustomobject]@{
    Ok = ($autoAdmin -eq '1' -and [bool]$userName)
    Label = '자동 로그인 활성화'
    Detail = if ($userName) { "$domain\$userName" } else { '미설정' }
  })
  $checks.Add([pscustomobject]@{
    Ok = ($lsaPw -or $null -ne $plainPw)
    Label = '로그인 비밀번호 저장'
    Detail = if ($lsaPw) { 'LSA Secret(암호화)' } elseif ($null -ne $plainPw) { '레지스트리 평문 - 권장하지 않음' } else { '없음' }
  })
  foreach ($p in $PowerSettings) {
    $cur = Get-PowerIndex $p.Sub $p.Setting
    $checks.Add([pscustomobject]@{
      Ok = ($cur -and $cur.AC -eq $p.Want -and $cur.DC -eq $p.Want)
      Label = $p.Label
      Detail = if ($cur) { "AC=$($cur.AC) DC=$($cur.DC)" } else { '조회 불가' }
    })
  }
  $saver = Get-RegValue (Get-UserDesktopKey) 'ScreenSaverIsSecure'
  $checks.Add([pscustomobject]@{
    Ok = ($saver -ne '1')
    Label = '화면 보호기 해제 시 로그인 요구: 안 함'
    Detail = "ScreenSaverIsSecure=$saver"
  })
  return $checks
}

# ---------------------------------------------------------------------------
# 백업 / 복원
# ---------------------------------------------------------------------------
function Save-BackupIfMissing {
  if (Test-Path $BackupFile) { return }
  New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
  $power = @{}
  foreach ($p in $PowerSettings) { $power[$p.Setting] = Get-PowerIndex $p.Sub $p.Setting }
  $desktop = Get-UserDesktopKey
  $backup = [ordered]@{
    createdAt  = (Get-Date).ToString('s')
    targetUser = $TargetUser
    devicePasswordLessBuildVersion = Get-RegValue $PasswordLessKey 'DevicePasswordLessBuildVersion'
    autoAdminLogon = Get-RegValue $WinlogonKey 'AutoAdminLogon'
    power = $power
    screenSaveActive    = Get-RegValue $desktop 'ScreenSaveActive'
    screenSaverIsSecure = Get-RegValue $desktop 'ScreenSaverIsSecure'
  }
  $backup | ConvertTo-Json -Depth 5 | Set-Content -Path $BackupFile -Encoding UTF8
}

function Invoke-Restore {
  Show-Header '복원'
  Write-Host '  자동 로그인을 해제하고 저장된 비밀번호를 삭제합니다.'
  if ((Read-Choice '  진행할까요? [Y] 예  [N] 아니오' @('Y', 'N')) -ne 'Y') { return }

  Set-ItemProperty -Path $WinlogonKey -Name 'AutoAdminLogon' -Value '0'
  Remove-ItemProperty -Path $WinlogonKey -Name 'DefaultPassword' -ErrorAction SilentlyContinue
  [HvAutoLogonNative]::DeleteSecret('DefaultPassword')
  Write-Check $true '자동 로그인 해제 / 비밀번호 삭제'

  if (Test-Path $BackupFile) {
    $b = Get-Content -Path $BackupFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $PowerSettings) {
      $v = $b.power.($p.Setting)
      if ($v) { Set-PowerIndex $p.Sub $p.Setting $v.AC $v.DC }
    }
    & powercfg /setactive SCHEME_CURRENT | Out-Null
    Write-Check $true '전원/잠금 설정 원복' $b.createdAt

    $desktop = Get-UserDesktopKey
    if ($null -ne $b.screenSaveActive)    { Set-ItemProperty -Path $desktop -Name 'ScreenSaveActive'    -Value $b.screenSaveActive }
    if ($null -ne $b.screenSaverIsSecure) { Set-ItemProperty -Path $desktop -Name 'ScreenSaverIsSecure' -Value $b.screenSaverIsSecure }
    Write-Check $true '화면 보호기 설정 원복'

    if ($b.devicePasswordLessBuildVersion -eq 2) {
      New-Item -Path $PasswordLessKey -Force | Out-Null
      Set-ItemProperty -Path $PasswordLessKey -Name 'DevicePasswordLessBuildVersion' -Value 2 -Type DWord
      Write-Check $true '"Windows Hello 로그인만 허용" 다시 켬'
    }
    Remove-Item -Path $BackupFile -Force
  } else {
    Write-Check $false '백업 파일이 없어 전원/화면 설정은 그대로 둡니다' $BackupFile
  }

  Write-Host ''
  Write-Host '  복원 완료. PIN(Windows Hello)은 설정 > 계정 > 로그인 옵션에서 다시 추가하세요.' -ForegroundColor Green
  Write-Host '  Autologon 프로그램 제거: winget uninstall Microsoft.Sysinternals.Autologon' -ForegroundColor DarkGray
  Exit-Script
}

# ---------------------------------------------------------------------------
# Autologon 확보 (winget 우선, 실패 시 Sysinternals 공식 zip)
# ---------------------------------------------------------------------------
function Get-AutologonExeName {
  switch ($env:PROCESSOR_ARCHITECTURE) {
    'ARM64' { 'Autologon64a.exe' }
    'AMD64' { 'Autologon64.exe' }
    default { 'Autologon.exe' }
  }
}

function Find-Autologon {
  $name = Get-AutologonExeName
  foreach ($cmd in @($name, 'Autologon.exe', 'autologon')) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
  }
  $roots = @(
    "$env:LOCALAPPDATA\Microsoft\WinGet\Packages",
    "$env:ProgramFiles\WinGet\Packages",
    (Join-Path $BackupDir 'Autologon')
  )
  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    $hit = Get-ChildItem -Path $root -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { return $hit.FullName }
  }
  return $null
}

function Install-Autologon {
  $exe = Find-Autologon
  if ($exe) { return $exe }

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host '  winget 으로 Microsoft.Sysinternals.Autologon 설치 중...' -ForegroundColor Cyan
    & winget install --id Microsoft.Sysinternals.Autologon -e --source winget --accept-source-agreements --accept-package-agreements | Out-Host
    $exe = Find-Autologon
    if ($exe) { return $exe }
  }

  Write-Host '  winget 설치를 찾지 못해 Sysinternals 공식 배포본을 내려받습니다...' -ForegroundColor Cyan
  $dest = Join-Path $BackupDir 'Autologon'
  $zip  = Join-Path $env:TEMP 'AutoLogon.zip'
  New-Item -ItemType Directory -Path $dest -Force | Out-Null
  Invoke-WebRequest -Uri 'https://download.sysinternals.com/files/AutoLogon.zip' -OutFile $zip -UseBasicParsing
  Expand-Archive -Path $zip -DestinationPath $dest -Force
  Remove-Item $zip -Force
  return Find-Autologon
}

# ---------------------------------------------------------------------------
# 설치
# ---------------------------------------------------------------------------
function Read-PlainPassword([string]$prompt) {
  $secure = Read-Host $prompt -AsSecureString
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}

function Install-AutoLogonCredential {
  $exe = Install-Autologon
  if (-not $exe) { throw 'Autologon 실행 파일을 찾을 수 없습니다.' }
  Write-Host "  Autologon: $exe" -ForegroundColor DarkGray

  $domain, $user = $TargetUser -split '\\', 2
  if (-not $user) { $user = $domain; $domain = $env:COMPUTERNAME }

  Write-Host ''
  Write-Host '  자동 로그인에 사용할 계정 비밀번호를 한 번만 입력합니다.'
  Write-Host '  * Microsoft 계정이면 PIN 이 아니라 Microsoft 계정 비밀번호입니다.' -ForegroundColor DarkYellow
  $answer = Read-Host "  사용자 이름 [$user]"
  if ($answer) { $user = $answer }
  $answer = Read-Host "  도메인/컴퓨터 이름 [$domain]"
  if ($answer) { $domain = $answer }

  while ($true) {
    $pw1 = Read-PlainPassword '  비밀번호'
    $pw2 = Read-PlainPassword '  비밀번호 확인'
    if ($pw1 -ne $pw2) { Write-Host '  비밀번호가 일치하지 않습니다.' -ForegroundColor Red; continue }
    if ([HvAutoLogonNative]::ValidateLogon($user, $domain, $pw1)) { break }
    Write-Host '  이 비밀번호로 로그인 검증에 실패했습니다.' -ForegroundColor Red
    if ((Read-Choice '  [R] 다시 입력  [C] 그래도 계속' @('R', 'C')) -eq 'C') { break }
  }

  & $exe $user $domain $pw1 /accepteula | Out-Null
  $pw1 = $null; $pw2 = $null
  [GC]::Collect()
}

function Install-DisplayKeepAlive {
  foreach ($p in $PowerSettings) { Set-PowerIndex $p.Sub $p.Setting $p.Want $p.Want }
  & powercfg /setactive SCHEME_CURRENT | Out-Null
  $desktop = Get-UserDesktopKey
  if (Test-Path $desktop) {
    Set-ItemProperty -Path $desktop -Name 'ScreenSaveActive'    -Value '0'
    Set-ItemProperty -Path $desktop -Name 'ScreenSaverIsSecure' -Value '0'
  }
}

function Invoke-Install([object[]]$checks) {
  Show-Header 'Step 3 · 설치'
  Save-BackupIfMissing

  $autologonOk = ($checks[0].Ok -and $checks[1].Ok)
  $doCredential = $true
  if ($autologonOk) {
    Write-Host "  자동 로그인은 이미 구성되어 있습니다. ($($checks[0].Detail))"
    $doCredential = (Read-Choice '  비밀번호를 다시 등록할까요? [Y] 예  [N] 아니오' @('Y', 'N')) -eq 'Y'
  }
  if ($doCredential) { Install-AutoLogonCredential }

  Install-DisplayKeepAlive
  Write-Host ''
  Write-Host '  적용 완료. 상태를 다시 확인합니다...' -ForegroundColor Green
  Start-Sleep -Seconds 1
}

# ---------------------------------------------------------------------------
# Step 1 · 경고
# ---------------------------------------------------------------------------
function Invoke-Step1 {
  Show-Header 'Step 1 · 경고'
  $isVm = Test-HyperVGuest
  Write-Host '  이 스크립트는 Hyper-V 가상 머신에서 화면을 항상 켜 두기 위한 장치입니다.' -ForegroundColor White
  Write-Host ''
  Write-Host '  적용되는 내용' -ForegroundColor Cyan
  Write-Host '   - 부팅 시 비밀번호 입력 없이 자동 로그인'
  Write-Host '   - 디스플레이 끄기 / 절전 / 최대 절전 비활성화'
  Write-Host '   - 절전 해제·화면 보호기 해제 시 로그인 요구 해제'
  Write-Host ''
  Write-Host '  !! 보안 경고 !!' -ForegroundColor Red
  Write-Host '   실제 사용하는 PC(호스트)에 적용하면 전원만 켜도 누구나 계정에 접근할 수 있습니다.' -ForegroundColor Red
  Write-Host '   반드시 격리된 VM 에서만 사용하세요.' -ForegroundColor Red
  Write-Host ''
  if ($isVm) { Write-Host '  현재 환경: Hyper-V 가상 머신으로 감지됨' -ForegroundColor Green }
  else       { Write-Host '  현재 환경: 가상 머신이 아닌 것으로 보입니다 (호스트일 가능성 높음!)' -ForegroundColor Red }
  Write-Host ''

  $choice = Read-Choice '  [N] 다음 단계  [C] 취소' @('N', 'C')
  if ($choice -eq 'C') { Exit-Script }
  if (-not $isVm) {
    Write-Host ''
    $confirm = Read-Host '  VM 이 아닌 환경입니다. 그래도 계속하려면 "I UNDERSTAND" 를 입력하세요'
    if ($confirm -cne 'I UNDERSTAND') { Exit-Script }
  }
}

# ---------------------------------------------------------------------------
# Step 2 · Windows Hello
# ---------------------------------------------------------------------------
function Invoke-Step2 {
  while ($true) {
    Show-Header 'Step 2 · Windows Hello 확인'
    $hello = Get-HelloState
    Write-Check (-not $hello.HelloOnly) '"Microsoft 계정에 Windows Hello 로그인만 허용" 꺼짐'
    Write-Check (-not $hello.Pin)       'PIN(Windows Hello) 미등록'
    if ($hello.Managed) {
      Write-Check $false '조직 정책(Windows Hello for Business)이 적용됨' '관리자 정책에서 해제 필요'
    }

    if (-not $hello.HelloOnly -and -not $hello.Pin) {
      Write-Host ''
      Write-Host '  Windows Hello 가 꺼져 있습니다. 다음 단계로 진행합니다.' -ForegroundColor Green
      Start-Sleep -Seconds 1
      return
    }

    Write-Host ''
    Write-Host '  Windows Hello 를 꺼 주세요' -ForegroundColor Cyan
    Write-Host '   설정(Win + I) > 계정 > 로그인 옵션'
    Write-Host '    1) 추가 설정: "보안 향상을 위해 이 디바이스에서 Microsoft 계정에 대해'
    Write-Host '       Windows Hello 로그인만 허용" -> 끔'
    Write-Host '    2) PIN(Windows Hello) -> 제거  (1번을 먼저 꺼야 제거 버튼이 활성화됩니다)'
    Write-Host '   완료 후 [R] 로 새로고침하세요.'
    Write-Host ''

    $keys = @('O', 'R', 'Q')
    $menu = '  [O] 설정 열기  [R] 새로고침  '
    if ($hello.HelloOnly) { $keys += 'A'; $menu += '[A] 1번 자동으로 끄기  ' }
    if (-not $hello.HelloOnly) {
      # PIN 만 남은 경우 자동 로그인은 동작하므로 계속 진행 허용
      $keys += 'S'; $menu += '[S] PIN 유지하고 계속  '
    }
    $menu += '[Q] 종료'

    switch (Read-Choice $menu $keys) {
      'O' { Start-Process 'ms-settings:signinoptions' }
      'A' {
        Save-BackupIfMissing
        New-Item -Path $PasswordLessKey -Force | Out-Null
        Set-ItemProperty -Path $PasswordLessKey -Name 'DevicePasswordLessBuildVersion' -Value 0 -Type DWord
      }
      'S' { return }
      'Q' { Exit-Script }
    }
  }
}

# ---------------------------------------------------------------------------
# Step 3 · 설치 여부 확인
# ---------------------------------------------------------------------------
function Invoke-Step3 {
  while ($true) {
    Show-Header 'Step 3 · 자동 로그인 / 화면 유지'
    $checks = Get-SetupState
    foreach ($c in $checks) { Write-Check $c.Ok $c.Label $c.Detail }
    Write-Host ''

    $allOk = -not ($checks | Where-Object { -not $_.Ok })
    if ($allOk) {
      Write-Host '  모든 설정이 완료되었습니다. 재부팅하면 비밀번호 없이 바로 바탕화면이 뜹니다.' -ForegroundColor Green
      Write-Host '  * Hyper-V 연결 시 "고급 세션"이 아닌 "기본 세션"으로 열어야 콘솔 화면이 유지됩니다.' -ForegroundColor DarkGray
      Write-Host ''
      switch (Read-Choice '  [Q] 나가기  [U] 복원(설정 되돌리기)' @('Q', 'U')) {
        'Q' { Exit-Script }
        'U' { Invoke-Restore }
      }
    } else {
      Write-Host '  아직 설치되지 않은 항목이 있습니다.' -ForegroundColor Yellow
      Write-Host ''
      switch (Read-Choice '  [I] 설치  [U] 복원  [Q] 종료' @('I', 'U', 'Q')) {
        'I' { Invoke-Install $checks }
        'U' { Invoke-Restore }
        'Q' { Exit-Script }
      }
    }
  }
}

try {
  Invoke-Step1
  Save-BackupIfMissing   # 아무것도 바꾸기 전 원래 상태를 기록
  Invoke-Step2
  Invoke-Step3
} catch {
  Write-Host ''
  Write-Host "  오류: $($_.Exception.Message)" -ForegroundColor Red
  Exit-Script
}
