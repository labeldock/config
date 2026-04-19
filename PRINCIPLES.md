# Principles

이 레포를 어떤 의도로 만들고 어떤 방향으로 다듬어 가는지 정리해 둔 문서입니다.

## Scope

- **주 대상**: bash / zsh (macOS, Linux)
- **Windows**: `windows/` 하위 자원은 사용자가 클론 후 GUI에서 직접 다루는 영역입니다. 설치 스크립트의 자동화 대상이 아닙니다.

## 설치 스크립트 리팩터링 방향

현재 진행 중인 개편입니다.

- **기존**: `install.sh`(bash, PATH 등록) + `bin/config`(bash 메뉴 기반 세부 세팅)
- **방향**: `install.sh`는 shell 감지 + bun 확보 + TS 엔트리 `exec` 까지만 담당. 메뉴/각 세팅 로직은 [`@clack/prompts`](https://github.com/bombardier-gif/clack) 기반 TypeScript + bun 런타임으로 이전합니다.
- bun 바이너리 확보 방식(vendoring / 부트스트랩 설치 / 컴파일 단일 바이너리)은 아직 확정되지 않았습니다.

## 유지 항목

- `gitconfig` 템플릿 적용
- git user 설정 입력
- `tmux.conf` 템플릿 적용
- `config/bin` PATH 등록
