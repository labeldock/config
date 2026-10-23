# README-TMUX-CONF

[`dotfiles.templates/.tmux.conf`](./dotfiles.templates/.tmux.conf) 의 각 설정이 왜 들어왔고 무엇을 해결하는지 정리한 문서입니다.

`.tmux.conf` 의 주석은 영어 한 줄로 "무엇인지" 만 적고, 끝에 `README-TMUX-CONF#N` 번호를 붙입니다. 자세한 도입 배경과 해결 방식은 이 문서의 같은 번호 항목에 있습니다. 설정을 추가할 때는 다음 번호를 쓰고, 이 문서에 항목을 함께 추가합니다.

| # | 설정 | 한 줄 요약 |
| --- | --- | --- |
| [`#1`](#1-prefix-c-b) | `prefix C-b`, `send-prefix` | prefix 를 C-b 로 고정하고, C-b 두 번이면 앱에 C-b 를 보낸다 |
| [`#2`](#2-update-environment-term--term_program) | `update-environment TERM TERM_PROGRAM` | attach 한 바깥 터미널 정보를 세션에 남긴다 |
| [`#3`](#3-extended-keys) | `extended-keys` | Shift+Enter 처럼 수식키 조합을 앱이 구분하게 한다 |
| [`#4`](#4-allow-passthrough) | `allow-passthrough on` | 앱의 이스케이프 시퀀스가 바깥 터미널까지 가게 한다 |
| [`#5`](#5-focus-events) | `focus-events on` | 창 포커스 변화를 앱에 알린다 |
| [`#6`](#6-mode-keys-vi) | `mode-keys vi` | 복사 모드를 vi 키로 쓴다 |
| [`#7`](#7-clipboard-osc-52) | `set-clipboard on`, `*:clipboard` | 앱이 보낸 클립보드 복사를 바깥 터미널로 넘긴다 |
| [`#8`](#8-mouse) | `mouse on` | 휠과 드래그를 tmux 와 전체화면 앱이 받는다 |
| [`#9`](#9-update-environment-ssh--display) | `update-environment SSH_CLIENT SSH_TTY WAYLAND_DISPLAY` | 재접속 시 SSH·디스플레이 변수를 새로 받는다 |
| [`#10`](#10-copy-mode-v--y) | copy-mode-vi `v` / `y` | vim 처럼 v 로 선택, y 로 복사 |
| [`#11`](#11-jk-pane-이동) | `bind j` / `bind k` | j/k 로 이전·다음 pane 이동 |

---

## `#1` prefix C-b

```tmux
set -g prefix C-b
unbind-key C-b
bind-key C-b send-prefix
```

**도입 배경**
[`#3`](#3-extended-keys) 의 `extended-keys` 를 `always` 로 바꾼 뒤에 "experimental C-b bug fix" 라는 이름으로 추가되었습니다. 어떤 증상이었는지는 기록에 남아 있지 않습니다. 확장 키 모드에서는 C-b 가 일반 제어 문자가 아닌 확장 시퀀스로 들어올 수 있어, prefix 인식이 흔들렸을 가능성이 있습니다.

**해결 방법**
prefix 를 기본값에 맡기지 않고 C-b 로 명시합니다. 기존 바인딩을 지운 뒤 `send-prefix` 로 다시 묶어서, C-b 를 두 번 누르면 tmux 안의 앱에 C-b 가 그대로 전달됩니다. 셸의 한 글자 뒤로 가기나 vim 의 페이지 업을 쓸 때 필요합니다.

## `#2` update-environment TERM / TERM_PROGRAM

```tmux
set -ga update-environment TERM
set -ga update-environment TERM_PROGRAM
```

**도입 배경**
tmux 안에서는 `TERM` 이 `tmux-256color`, `TERM_PROGRAM` 이 `tmux` 로 바뀝니다. 그래서 tmux 안의 앱은 바깥이 Ghostty 인지 iTerm2 인지 Windows Terminal 인지 알 수 없습니다. Claude Code 처럼 터미널마다 동작을 바꾸는 앱은 이 정보가 필요합니다.

**해결 방법**
attach 할 때마다 바깥 터미널의 값을 tmux 세션 환경에 기록합니다. pane 안의 변수는 여전히 tmux 값이지만, 앱이나 스크립트가 `tmux show-environment TERM_PROGRAM` 으로 실제 바깥 터미널을 조회할 수 있습니다.

## `#3` extended keys

```tmux
set -g extended-keys always
set -g extended-keys-format csi-u
set -as terminal-features 'xterm*:extkeys'
```

**도입 배경**
tmux 기본값에서는 Shift+Enter 와 Enter 가 같은 키로 전달됩니다. 그래서 Claude Code 안에서 Shift+Enter 로 줄바꿈을 하려 하면 그냥 전송되어 버립니다. 같은 이유로 Ctrl+Shift 조합 같은 단축키도 앱에 닿지 않습니다.

**해결 방법**
tmux 가 수식키 정보를 담은 확장 키 시퀀스를 앱에 보내게 합니다. `always` 는 앱이 요청하지 않아도 항상 보내고, `csi-u` 는 kitty 키보드 프로토콜과 같은 형식을 씁니다. `xterm*:extkeys` 는 바깥 터미널이 확장 키를 지원한다고 tmux 에 알려 줍니다. 처음에는 `on` 이었는데, 요청하지 않는 앱에서도 동작하도록 `always` 로 바꿨습니다.

## `#4` allow-passthrough

```tmux
set -g allow-passthrough on
```

**도입 배경**
tmux 는 앱이 보낸 이스케이프 시퀀스를 직접 해석하고, 모르는 것은 버립니다. 그래서 Claude Code 의 데스크톱 알림, 진행 표시줄, 이미지 출력 같은 기능이 tmux 안에서는 바깥 터미널에 닿지 않았습니다.

**해결 방법**
앱이 tmux 전용 포장으로 감싸 보낸 시퀀스는 해석하지 않고 바깥 터미널로 그대로 넘깁니다. `on` 은 현재 보이는 pane 에서 보낸 것만 넘깁니다.

## `#5` focus-events

```tmux
set -g focus-events on
```

**도입 배경**
tmux 안의 앱은 사용자가 다른 창이나 pane 으로 옮겨 갔는지 알 수 없습니다. 그래서 자리에 있을 때만 생략해야 할 알림이 계속 뜨거나, vim 이 외부에서 바뀐 파일을 다시 읽지 못하는 일이 생깁니다.

**해결 방법**
바깥 터미널의 포커스 이벤트를 받아 pane 의 앱에 전달합니다.

## `#6` mode-keys vi

```tmux
setw -g mode-keys vi
```

**도입 배경**
tmux 복사 모드의 기본 키는 emacs 계열이라 vim 사용자에게 손에 익지 않습니다.

**해결 방법**
복사 모드와 선택 목록에서 `h j k l`, `/` 검색, `Space` 선택 같은 vi 키를 씁니다. [`#10`](#10-copy-mode-v--y) 의 `v` / `y` 바인딩도 이 설정 위에서 동작합니다.

## `#7` clipboard (OSC 52)

```tmux
set -s set-clipboard on
set -as terminal-features '*:clipboard'
```

**도입 배경**
Claude Code 에서 복사가 "어떨 땐 되고 어떨 땐 안 되는" 문제가 있었습니다. SSH 너머의 앱은 OSC 52 라는 이스케이프 시퀀스로 바깥 터미널에 클립보드 복사를 요청합니다. 그런데 tmux 기본값 `set-clipboard external` 은 tmux 자신의 복사만 바깥으로 보내고, pane 안의 앱이 보낸 OSC 52 는 버립니다. 또 tmux 는 `TERM` 이 `xterm*` 일 때만 바깥 터미널이 OSC 52 를 지원한다고 가정합니다.

**해결 방법**
`set-clipboard on` 으로 앱이 보낸 OSC 52 를 받아 tmux 버퍼에 넣고, 바깥 터미널로 다시 보냅니다. `*:clipboard` 는 alacritty, wezterm, 중첩 tmux 처럼 `xterm*` 이 아닌 터미널에도 보내게 합니다. 지원하지 않는 터미널은 이 시퀀스를 무시합니다.

**주의**
pane 에 출력되는 어떤 프로그램이든 클립보드를 덮어쓸 수 있게 됩니다. 신뢰할 수 없는 파일을 `cat` 으로 출력할 때는 이 점을 염두에 둡니다. 바깥 터미널도 OSC 52 를 허용해야 합니다. iTerm2 는 별도 허용이 필요하고, Terminal.app 은 지원하지 않습니다. 자세한 점검표는 [README 의 Clipboard](./README.md#clipboard) 를 참고합니다.

## `#8` mouse

```tmux
set -g mouse on
```

**도입 배경**
Claude Code 전체화면 모드는 마우스로 스크롤하고, 드래그로 선택한 뒤 Ctrl+C 로 복사합니다. 이 방식은 줄바꿈과 여백이 섞이지 않은 원문을 복사합니다. 그런데 tmux 마우스가 꺼져 있으면 휠과 드래그가 앱에 닿지 않습니다. 그래서 터미널 자체 선택으로 화면 글자를 긁어야 했고, 결과에 여백과 줄바꿈이 섞였습니다.

**해결 방법**
tmux 가 마우스 이벤트를 받아, 마우스를 요청한 앱에는 그대로 넘기고 일반 셸 pane 에서는 tmux 가 직접 처리합니다.

| 동작 | 일반 셸 pane | Claude Code 전체화면 |
| --- | --- | --- |
| 드래그 | tmux 선택, 손을 떼면 복사 | Claude 내부 선택, Ctrl+C 로 복사 |
| 휠 | tmux 복사 모드로 스크롤 | Claude 대화 스크롤 |
| 오른쪽 클릭 | tmux pane 메뉴 | 앱으로 전달 |
| 가운데 클릭 | tmux 버퍼 붙여넣기 | 앱으로 전달 |

**주의**
터미널의 오른쪽 클릭 붙여넣기가 tmux 메뉴로 바뀝니다. 키보드 붙여넣기는 영향이 없으므로 Ctrl+V 나 Cmd+V 를 쓰면 되고, RustDesk 처럼 클립보드를 동기화하는 도구도 그대로 동작합니다. 가운데 클릭은 시스템 클립보드가 아닌 tmux 버퍼를 붙여넣습니다. 터미널 자체 선택이 필요하면 Shift 를 누른 채 드래그하거나 클릭합니다. iTerm2 는 Option 입니다.

## `#9` update-environment SSH / display

```tmux
set -ga update-environment 'SSH_CLIENT SSH_TTY WAYLAND_DISPLAY'
```

**도입 배경**
pane 의 셸은 처음 만들어질 때의 환경 변수를 그대로 들고 있습니다. 로컬 화면에서 만든 세션에 나중에 SSH 로 붙으면, 그 셸은 여전히 로컬이라고 알고 있습니다. 반대의 경우도 마찬가지입니다. Claude Code 는 SSH 변수가 있으면 OSC 52 로, 없으면 `pbcopy` 같은 로컬 명령으로 복사합니다. 그래서 변수가 낡으면 엉뚱한 머신의 클립보드에 복사합니다. tmux 기본 목록에는 `SSH_CONNECTION` 과 `DISPLAY` 만 있고 `SSH_CLIENT`, `SSH_TTY`, `WAYLAND_DISPLAY` 는 빠져 있습니다.

**해결 방법**
attach 할 때 이 변수들도 지금 붙은 클라이언트 기준으로 세션 환경에 갱신합니다. 클라이언트에 없는 변수는 "제거됨" 으로 표시됩니다. 새로 여는 pane 은 갱신된 값을 받고, 이미 열린 셸은 [`.claude/.bashrc.template`](./dotfiles.templates/.claude/.bashrc.template) 의 `claude` 함수가 실행 직전에 이 값을 읽어 와 맞춥니다.

## `#10` copy-mode `v` / `y`

```tmux
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
```

**도입 배경**
vi 복사 모드의 기본 키는 `Space` 로 선택, `Enter` 로 복사입니다. vim 에 익숙하면 `v` 와 `y` 를 먼저 누르게 됩니다.

**해결 방법**
`v` 로 선택을 시작하고 `y` 로 복사한 뒤 복사 모드를 빠져나옵니다. [`#7`](#7-clipboard-osc-52) 덕분에 복사한 내용은 시스템 클립보드까지 갑니다. 원래 `v` 에 있던 사각형 선택 전환은 `Ctrl+V` 로 계속 쓸 수 있습니다.

## `#11` j/k pane 이동

```tmux
bind j select-pane -t :.-
bind k select-pane -t :.+
```

**도입 배경**
pane 이동 기본 키는 방향키나 `o` 라서 손이 홈 로우를 벗어납니다.

**해결 방법**
`prefix j` 는 이전 pane, `prefix k` 는 다음 pane 으로 이동합니다. 한때 방향이 반대였는데, 호스트에서 쓰던 방향으로 맞췄습니다.
