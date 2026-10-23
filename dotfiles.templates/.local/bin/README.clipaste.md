# clipaste client helpers

`clipaste-paste`, `xclip`, and `wl-paste` in this directory are the client-side helpers of [clipaste](https://github.com/hqhq1025/clipaste) v2.5.0, copied verbatim from `src/ssh_setup.rs` with the bridge URL set to `http://127.0.0.1:18340`.

They are byte-identical to what `clipaste ssh-setup` writes on a remote, so a host set up either way shows `in sync` in `onboard`.

| File | Installed on | Purpose |
| --- | --- | --- |
| `clipaste-paste` | macOS and Linux | Saves the clipboard host's current image to a file and prints the path |
| `xclip` | Linux | Answers Claude Code's Ctrl+V image request from the bridge, otherwise runs the real `xclip` |
| `wl-paste` | Linux | Same for Wayland tools, otherwise runs the real `wl-paste` |

Installed by `onboard` → `install` → `clipaste client`. They need `curl` and `~/.local/bin` ahead of `/usr/bin` on `PATH`.

## License

MIT License

Copyright (c) 2026 Haoqing Wang

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
