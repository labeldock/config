# README-TMUX-CONF

[`dotfiles.templates/.tmux.conf`](./dotfiles.templates/.tmux.conf) 의 각 설정이 왜 들어왔고 무엇을 해결하는지 정리한 문서입니다.

`.tmux.conf` 의 주석은 영어 한 줄로 "무엇인지" 만 적고, 끝에 `README-TMUX-CONF#N` 번호를 붙입니다. 자세한 도입 배경과 해결 방식은 이 문서의 같은 번호 항목에 있습니다.

**번호 규칙: 한 번 붙인 번호는 절대 바꾸지 않습니다.**

- 새 설정은 지금까지 쓴 가장 큰 번호의 다음 번호를 받습니다. 중간 번호를 재사용하지 않습니다.
- 설정을 지워도 번호를 당기지 않습니다. 이 문서의 항목은 "삭제됨" 으로 표시해 남기고, 왜 넣었고 왜 지웠는지 기록합니다.
- `.tmux.conf` 안에서 설정 순서를 바꿔도 번호는 따라 바뀌지 않습니다.

번호가 바뀌면 이미 복사해 간 `.tmux.conf`, 커밋 메시지, 대화 기록에 남은 `README-TMUX-CONF#N` 이 엉뚱한 항목을 가리키게 되기 때문입니다.

| # | 설정 | 한 줄 요약 |
| --- | --- | --- |
| [`#1`](#1-prefix-c-b-삭제됨) | ~~`prefix C-b`, `send-prefix`~~ | 삭제됨. tmux 기본값과 같아 효과가 없었다. 실제 원인은 `#12` |
| [`#2`](#2-update-environment-term--term_program) | `update-environment TERM TERM_PROGRAM` | attach 한 바깥 터미널 정보를 세션에 남긴다 |
| [`#3`](#3-extended-keys) | `extended-keys` | Shift+Enter 처럼 수식키 조합을 앱이 구분하게 한다 |
| [`#4`](#4-allow-passthrough) | `allow-passthrough on` | 앱의 이스케이프 시퀀스가 바깥 터미널까지 가게 한다 |
| [`#5`](#5-focus-events) | `focus-events on` | 창 포커스 변화를 앱에 알린다 |
| [`#6`](#6-mode-keys-vi) | `mode-keys vi` | 복사 모드를 vi 키로 쓴다 |
| [`#7`](#7-clipboard-osc-52-삭제됨) | ~~`set-clipboard on`, `*:clipboard`~~ | 삭제됨. 이미지 붙여넣기는 clipaste 로 해결 |
| [`#8`](#8-mouse-삭제됨) | ~~`mouse on`~~ | 삭제됨. 오른쪽 클릭 붙여넣기 등 기존 마우스 습관을 깬다 |
| [`#9`](#9-update-environment-ssh--display-삭제됨) | ~~`update-environment SSH_CLIENT SSH_TTY WAYLAND_DISPLAY`~~ | 삭제됨. `#7` 의 복사 경로 판단용이었다 |
| [`#10`](#10-copy-mode-v--y-삭제됨) | ~~copy-mode-vi `v` / `y`~~ | 삭제됨. `#7` 과 한 묶음이었다 |
| [`#11`](#11-jk-pane-이동) | `bind j` / `bind k` | j/k 로 이전·다음 pane 이동 |
| [`#12`](#12-assume-paste-time) | `assume-paste-time 0` | 빠르게 몰려 들어온 키를 붙여넣기로 오해하지 않게 한다 |

---

## `#1` prefix C-b (삭제됨)

```tmux
# 삭제된 설정
set -g prefix C-b
unbind-key C-b
bind-key C-b send-prefix
```

**도입 배경**
Claude Code 를 tmux 안에서 쓰다 보면 가끔 Ctrl+B 가 먹통이 되어, prefix 로 시작하는 tmux 동작을 하나도 쓸 수 없었습니다. 타이핑 자체는 정상이었습니다. 주 환경은 Windows Terminal 의 pwsh 7 에서 SSH 로 macOS 에 접속해 tmux 를 쓰는 경우였고, 한/영 상태와는 관계가 없었습니다. 이를 고치려고 prefix 를 C-b 로 명시하고 `send-prefix` 를 다시 묶었습니다.

**삭제 이유**
세 줄 모두 tmux 기본값과 똑같아서 실제로는 아무것도 바꾸지 않았습니다. 빈 설정과 이 세 줄만 넣은 설정에서 `prefix` 값과 `C-b` 바인딩이 같은 것을 확인했습니다. 실제 원인은 tmux 3.6 계열의 붙여넣기 판정 버그로 보이며, 대응은 [`#12`](#12-assume-paste-time) 에 정리했습니다. Claude Code 의 Ctrl+B 백그라운드 단축키는 기본값 그대로 C-b 를 두 번 누르면 앱에 전달됩니다.

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
복사 모드와 선택 목록에서 `h j k l`, `/` 검색, `Space` 선택, `Enter` 복사 같은 vi 키를 씁니다.

## `#7` clipboard (OSC 52) (삭제됨)

```tmux
# 삭제된 설정
set -s set-clipboard on
set -as terminal-features '*:clipboard'
```

**도입 배경**
Claude Code 에서 복사가 "어떨 땐 되고 어떨 땐 안 되는" 문제를 풀려고 넣었습니다. tmux 기본값 `set-clipboard external` 은 pane 안의 앱이 OSC 52 로 보낸 복사 요청을 버리므로, 이를 받아 바깥 터미널로 넘기게 했습니다.

**삭제 이유**
실제로 필요했던 것은 Windows 에서 캡처한 이미지를 원격 Claude Code 에 붙여넣는 일이었고, 이는 텍스트 복사 경로로는 풀 수 없습니다. 이미지 붙여넣기는 tmux 가 아니라 [clipaste](./README.md#clipboard-image-paste) 가 맡습니다. 텍스트 복사는 Windows Terminal 의 Ctrl+Shift+C 와 RustDesk 로 이미 쓰고 있어서, 어떤 프로그램이든 클립보드를 덮어쓸 수 있게 되는 부작용을 감수할 이유가 없었습니다.

## `#8` mouse (삭제됨)

```tmux
# 삭제된 설정
set -g mouse on
```

**도입 배경**
Claude Code 전체화면 모드에서 드래그로 선택하고 Ctrl+C 로 복사하려면 tmux 가 마우스를 앱에 넘겨야 해서 넣었습니다.

**삭제 이유**
`#7` 과 같은 이유로 목적이 사라졌습니다. 게다가 오른쪽 클릭이 tmux 메뉴로 바뀌고, 가운데 클릭이 tmux 버퍼를 붙여넣고, 터미널 자체 선택에 Shift 가 필요해지는 등 기존 마우스 습관을 깹니다.

## `#9` update-environment SSH / display (삭제됨)

```tmux
# 삭제된 설정
set -ga update-environment 'SSH_CLIENT SSH_TTY WAYLAND_DISPLAY'
```

**도입 배경**
pane 의 셸은 처음 만들어질 때의 환경 변수를 들고 있어서, 다른 머신에서 다시 attach 하면 Claude Code 가 SSH 인지 로컬인지 잘못 판단해 엉뚱한 머신의 클립보드에 복사했습니다. 이를 막으려고 SSH 변수를 attach 때마다 갱신하게 했습니다.

**삭제 이유**
`#7` 의 복사 경로 판단을 위한 설정이라 함께 뺐습니다. clipaste 는 SSH 접속에 붙은 포트 포워딩으로 이미지를 가져오므로 이 변수에 기대지 않습니다.

## `#10` copy-mode `v` / `y` (삭제됨)

```tmux
# 삭제된 설정
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel
```

**도입 배경**
vim 처럼 `v` 로 선택하고 `y` 로 복사한 내용이 `#7` 을 거쳐 시스템 클립보드까지 가게 하려고 넣었습니다.

**삭제 이유**
`#7` 이 빠지면 복사 결과가 tmux 버퍼에만 남아 의미가 줄어들고, 원래 `v` 에 있던 사각형 선택 전환도 되돌리는 편이 낫습니다. 기본 키는 `Space` 로 선택, `Enter` 로 복사입니다.

## `#11` j/k pane 이동

```tmux
bind j select-pane -t :.-
bind k select-pane -t :.+
```

**도입 배경**
pane 이동 기본 키는 방향키나 `o` 라서 손이 홈 로우를 벗어납니다.

**해결 방법**
`prefix j` 는 이전 pane, `prefix k` 는 다음 pane 으로 이동합니다. 한때 방향이 반대였는데, 호스트에서 쓰던 방향으로 맞췄습니다.

## `#12` assume-paste-time

```tmux
set -g assume-paste-time 0
```

**도입 배경**
[`#1`](#1-prefix-c-b-삭제됨) 의 Ctrl+B 먹통 증상의 실제 원인으로 보이는 tmux 3.6 계열 버그가 두 가지 있습니다. 둘 다 tmux 가 "지금 붙여넣기 중" 이라고 잘못 판단하면, 그동안 들어오는 키를 단축키로 해석하지 않고 글자로 넘기는 문제입니다. 그래서 타이핑은 되는데 prefix 만 죽은 것처럼 보입니다.

1. **붙여넣기 끝 신호가 나뉘어 도착하는 경우:** 터미널은 붙여넣기 내용 앞뒤에 시작 신호와 끝 신호를 붙입니다. Windows 의 OpenSSH 를 거치면 끝 신호가 여러 조각으로 나뉘어 도착할 수 있고, 3.6 계열은 이를 알아보지 못해 붙여넣기 상태에 갇힙니다. RustDesk 등으로 받은 내용을 Claude 에 붙여넣은 직후에 생기기 쉽습니다. tmux [issue 5089](https://github.com/tmux/tmux/issues/5089), [PR 5088](https://github.com/tmux/tmux/issues/5088).
2. **키가 몰려 들어오는 경우:** tmux 는 `assume-paste-time` 보다 짧은 간격으로 들어온 키 묶음을 붙여넣기로 추측합니다. 기본값은 1ms 입니다. 지연이 큰 SSH 에서는 키가 뭉쳐서 도착하므로 prefix 가 붙여넣기의 일부로 취급될 수 있습니다. tmux [issue 5031](https://github.com/tmux/tmux/issues/5031).

**해결 방법**
`assume-paste-time 0` 으로 두 번째 경우의 추측을 끕니다. 터미널이 붙여넣기 시작과 끝 신호를 보내므로 추측 없이도 붙여넣기는 정상으로 처리됩니다. tmux 3.7 부터는 이런 터미널에서 추측을 자동으로 끄기 때문에 이 설정은 3.6 계열을 위한 안전장치입니다.

첫 번째 경우는 설정으로 막을 수 없고, tmux 3.7 이상으로 올려야 고쳐집니다. 3.7 에는 Windows Terminal 의 나뉜 끝 신호 처리와, 붙여넣기가 5초 넘게 끝나지 않으면 강제로 끝내는 수정이 들어 있습니다. 업그레이드 후에는 이미 떠 있는 tmux 서버를 완전히 내렸다 올려야 새 버전이 적용됩니다.

**먹통일 때 복구**
다른 터미널 탭에서 같은 호스트에 접속해 클라이언트를 분리한 뒤, 원래 탭에서 다시 attach 합니다.

```bash
tmux detach-client -s <session>
```

**주의**
붙여넣기 시작과 끝 신호를 보내지 않는 터미널에서는 붙여넣은 내용 안의 prefix 바이트가 단축키로 해석될 수 있습니다. Windows Terminal, Ghostty, iTerm2 등은 신호를 보내므로 해당하지 않습니다.
