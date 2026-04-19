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

## 온보딩 스크립트 방향

- **런타임**: bash 유지. `@clack/prompts` 같은 외부 런타임은 도입하지 않습니다. 현재 범위에서는 bash가 충분합니다.
- **진입점**: 레포 루트의 `onboard` 실행파일 하나. (`~/config/onboard` 직접 실행; Rails 의 `bin/rails` 스타일). 별도의 PATH 등록/쉘 재시작 없이 바로 동작합니다.
- **UI**: 방향키로 이동, Space 로 토글, Enter 로 완료, Esc/q 로 취소. `lib/ui.sh` 가 공용 헬퍼(`ui_menu`, `ui_multiselect`) 를 제공합니다. bash 3.2 (macOS 기본) 호환을 위해 `stty` 로 ESC 시퀀스를 감지합니다.
- **메뉴 구조**: `Recommend` (brew + mise + global tools) / `Brew 설치` / `Mise 설치` / `gitconfig 적용` / `git user 설정` / `tmux.conf 적용` / `Exit`. 이미 설치된 항목은 `(installed)` 로 표기됩니다.

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
