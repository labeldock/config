# Windows PowerShell 7 환경 전역 설치 가이드

PowerShell(pwsh 7) 환경에서 `scoop` → `nano` / `mise` → `gh` 까지 전역으로 설치하는 순서를 정리한다.

흐름:

```
PowerShell 7 (pwsh)
  └─ Scoop (패키지 매니저)
       ├─ main 버킷 / nano (에디터)
       └─ mise (런타임/툴 매니저)
            └─ gh (GitHub CLI) 전역
```

---

## 요약 (전체 순서)

```powershell
# 1. PowerShell 7
winget install --id Microsoft.PowerShell --source winget
pwsh

# 2. Scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# 3. main 버킷 / nano
scoop bucket add main      # 누락 시
scoop install nano

# 4. mise
scoop install mise
Add-Content $PROFILE "`nmise activate pwsh | Out-String | Invoke-Expression"
. $PROFILE

# 5. gh 전역
mise use -g gh@latest
gh auth login
```

---

## 상세 설명

### 1. PowerShell 7 (pwsh) 설치

Windows 기본 `powershell.exe`(5.1)가 아닌 최신 PowerShell 7을 설치한다.

#### winget 사용 (권장)

기본 Windows 터미널(`powershell` 또는 `cmd`)에서:

```powershell
winget install --id Microsoft.PowerShell --source winget
```

설치 후 새 터미널에서 `pwsh` 명령으로 진입한다.

```powershell
pwsh
```

> 이후 단계는 모두 **pwsh(7)** 세션 안에서 진행한다.

#### 버전 확인

```powershell
$PSVersionTable.PSVersion
```

`7.x` 가 나오면 정상.

---

### 2. Scoop 설치

Scoop은 사용자 홈(`~\scoop`)에 설치되는 무관리자(non-admin) 패키지 매니저다.

먼저 실행 정책을 현재 사용자 범위에서 허용한다(이미 허용돼 있으면 생략 가능):

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

설치 스크립트 실행:

```powershell
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

설치 확인:

```powershell
scoop --version
```

> 관리자 권한으로 설치하려면 `-RunAsAdmin` 플래그가 필요하다. 일반 사용 권장은 비관리자 설치다.

---

### 3. Scoop → main 버킷 / nano

`nano` 에디터는 Scoop `main` 버킷에 있다. `main` 버킷은 기본 등록돼 있지만, 누락 시 직접 추가한다.

버킷 확인 / 추가:

```powershell
scoop bucket list
scoop bucket add main   # 없을 때만
```

nano 설치:

```powershell
scoop install nano
```

확인:

```powershell
nano --version
```

---

### 4. Scoop → mise

`mise`(구 rtx)는 다중 런타임/툴 버전 매니저다. Scoop으로 설치한다.

```powershell
scoop install mise
```

pwsh 프로파일에 `mise` 활성화 훅을 추가해 셸 진입 시 자동 활성화한다.

프로파일 파일 경로 확인:

```powershell
echo $PROFILE
```

프로파일에 다음 줄 추가(파일이 없으면 생성):

```powershell
if (!(Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force }
Add-Content $PROFILE "`nmise activate pwsh | Out-String | Invoke-Expression"
```

변경 사항 즉시 적용:

```powershell
. $PROFILE
```

확인:

```powershell
mise --version
mise doctor
```

---

### 5. mise → gh (GitHub CLI) 전역

`gh`를 mise로 전역(global) 설치한다. `mise use -g` 는 `~/.config/mise/config.toml`(global) 에 기록한다.

```powershell
mise use -g gh@latest
```

설치 및 PATH 반영 확인:

```powershell
mise list
gh --version
```

GitHub 로그인:

```powershell
gh auth login
```

> 특정 버전 고정이 필요하면 `mise use -g gh@2.x.x` 처럼 버전을 지정한다.
