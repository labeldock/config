# Principles

이 레포를 어떤 의도로 만들고 어떤 방향으로 다듬어 가는지 정리해 둔 문서입니다.

## Scope

- **주 대상**: bash / zsh (macOS, Linux)
- **Shell 우선순위**: bash first, zsh second. 스크립트는 bash에서 동작하는 것을 기준으로 작성하고 zsh에서도 문제없이 돌아가도록 유지합니다.
- **Windows**: `windows/` 하위 자원은 사용자가 직접 클론 후 설정하는 영역입니다. 온보딩 스크립트의 자동화 대상이 아닙니다.

## 호환 목표

| 환경 | 목표 |
| --- | --- |
| Linux | 100% |
| macOS | 99% |
| Git Bash (Windows) | 50% |

Git Bash는 best-effort 수준으로만 지원합니다. 특수 파일/설정이 필요한 경우 사용자가 별도 클론으로 구성합니다.

## 재현성 (Reproducibility)

현재 호스트(이 저자의 머신)의 설정 상태가 이후 적용되는 모든 머신과 동일한 상태로 수렴해야 합니다. 온보딩은 "이 레포를 클론 + 스크립트 실행 = 모든 머신이 같은 베이스라인"을 만족시키는 것을 목표로 합니다.

## 이중 사용성 (Dual-mode usage)

이 레포는 **두 가지 사용 방식을 동시에** 지원하도록 작성합니다.

1. **수동 사용** — 사용자가 레포를 클론하거나 GitHub 웹에서 파일을 직접 열어보고, 원하는 dotfile(예: `dotfiles.templates/.gitconfig`)을 자기 환경에 직접 복사/참조합니다.
2. **자동 적용** — `~/config/onboard` 를 실행하면 메뉴를 통해 템플릿 복사/설치가 자동으로 이루어집니다.

따라서 템플릿 파일들은 **사람이 직접 읽고 복사할 수 있는 형태**로 유지해야 합니다. 주석, 자기완결성, 읽기 쉬운 구조가 중요하며, 스크립트 전용 placeholder/변수 주입 같은 것은 지양합니다. `onboard` 는 이 템플릿들 위의 편의 레이어일 뿐, 템플릿이 single source of truth 입니다.

### 템플릿 디렉토리 구분

배치 대상에 따라 두 디렉토리로 분리합니다. 이 구분은 단순 네이밍이 아니라 "복사 대상 경로" 를 명확히 드러내기 위함이며, 수동 복사 사용자가 어디에 넣어야 할지 즉시 알 수 있게 합니다.

| 디렉토리 | 대상 경로 | 예시 |
| --- | --- | --- |
| `dotfiles.templates/` | `$HOME/...` (홈 디렉토리 직접) | `.gitconfig`, `.tmux.conf`, `.nanorc` |
| `xdg_config.templates/` | `$HOME/.config/...` (XDG_CONFIG_HOME 하위) | `opencode/opencode-*.json` |

## 온보딩 스크립트 방향

- **런타임**: bash 유지. `@clack/prompts` 같은 외부 런타임은 도입하지 않습니다. 현재 범위에서는 bash가 충분합니다.
- **진입점**: 레포 루트의 `onboard` 실행파일 하나. (`~/config/onboard` 직접 실행; Rails 의 `bin/rails` 스타일). 별도의 PATH 등록/쉘 재시작 없이 바로 동작합니다.
- **UI**: 방향키로 이동, Space 로 토글, Enter 로 완료, Esc/q 로 취소. `lib/ui.sh` 가 공용 헬퍼(`ui_menu`, `ui_multiselect`) 를 제공합니다. bash 3.2 (macOS 기본) 호환을 위해 `stty` 로 ESC 시퀀스를 감지합니다.
- **메뉴 구조**: 최상위는 `install` / `config` / `ai-config` / `Exit` 의 3-tier 구조입니다.
  - `install` → `Recommend` (brew + mise + global tools) / `Brew 설치` / `Mise 설치`
  - `config` → `gitconfig` / `nanorc` / `tmux` / `ghostty` / `tm_properties`
  - `ai-config` → `opencode` / `claude`
  - 서브메뉴 하단의 `← back` 또는 Esc 로 상위로 복귀합니다. 이미 설치된 항목은 `(installed)` 로 표기됩니다.
- **rc 통합 방식**: AI 관련 alias 는 각 템플릿 파일을 그대로 두고, `.bashrc`/`.zshrc` 에 `[ -f <template> ] && . <template>` 한 줄을 추가하는 source 방식입니다. 템플릿을 수정하면 즉시 반영되며, 같은 내용을 복제하지 않습니다. 멱등성은 `#~/config:<tag>:source` 마커로 유지합니다.

## 시스템 기본 설치 대상

온보딩이 시스템 레벨에서 기본으로 깔아주는 도구:

- [**Homebrew**](https://brew.sh) — macOS/Linux 공용 패키지 매니저
- [**mise**](https://mise.jdx.dev) — 런타임(node, python, bun, ...) 버전 관리

이 두 도구를 기반으로 이후 필요한 런타임/CLI는 `mise` 또는 `brew`로 관리합니다.

### Recommend 가 설치하는 mise 글로벌 도구

체크박스 multi-select 로 사용자가 설치 대상을 결정합니다. 기본 선택은 미설치 항목.

| 카테고리 | 도구 |
| --- | --- |
| 텍스트 처리 | `jq`, `yq` |
| 파일/검색 | `fd`, `ripgrep` |
| Git 워크플로 | `lazygit`, `delta` |
| 파일 탐색 | `yazi` |
| 셸 생산성 | `fzf`, `zoxide` |

## 유지 항목

- `gitconfig` 템플릿 적용
- git user 설정 입력
- `tmux.conf` 템플릿 적용
