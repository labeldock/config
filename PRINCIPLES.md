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
- **구성**: `install.sh`(진입점, shell 감지 + PATH 등록) + `bin/config`(메뉴 기반 세부 세팅).
- **6년 전 스타일에서 벗어나기 위한 현대화**가 진행 예정입니다.

## 시스템 기본 설치 대상

온보딩이 시스템 레벨에서 기본으로 깔아주는 도구:

- [**Homebrew**](https://brew.sh) — macOS/Linux 공용 패키지 매니저
- [**mise**](https://mise.jdx.dev) — 런타임(node, python, bun, ...) 버전 관리

이 두 도구를 기반으로 이후 필요한 런타임/CLI는 `mise` 또는 `brew`로 관리합니다.

## 유지 항목

- `gitconfig` 템플릿 적용
- git user 설정 입력
- `tmux.conf` 템플릿 적용
- `config/bin` PATH 등록
