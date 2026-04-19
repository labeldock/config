#!/usr/bin/env python3
"""Per-[[mgr.prepend_keymap]] block merger for yazi-style TOML.

Identifies blocks by their `on = ...` value. Replaces matching blocks in
the target with the template's block text; appends unmatched template
blocks at the end. Everything else in the target (comments, other
sections, custom blocks) is preserved verbatim.

Usage:
  toml_merge.py status TEMPLATE TARGET   # prints: same | partial
  toml_merge.py merge  TEMPLATE TARGET   # prints merged target to stdout
"""
from __future__ import annotations

import re
import sys
from collections import OrderedDict

TABLE_RE = re.compile(r'^\s*\[\[mgr\.prepend_keymap\]\]\s*$')
ON_RE = re.compile(r'^\s*on\s*=\s*(.+?)\s*$')


def _normalize_on(value: str) -> str:
    return re.sub(r'\s+', '', value)


def parse_blocks(text: str):
    """Return list of {'key', 'text'} for each [[mgr.prepend_keymap]] block.

    A block spans from '[[mgr.prepend_keymap]]' up to (but not including)
    the next blank line or the next table header. Comments between
    blocks are not part of any block.
    """
    lines = text.splitlines(keepends=True)
    blocks = []
    i, n = 0, len(lines)
    while i < n:
        if TABLE_RE.match(lines[i]):
            buf = [lines[i]]
            i += 1
            key = None
            while i < n:
                line = lines[i]
                if TABLE_RE.match(line) or line.strip() == '':
                    break
                buf.append(line)
                m = ON_RE.match(line)
                if m and key is None:
                    key = _normalize_on(m.group(1))
                i += 1
            blocks.append({'key': key, 'text': ''.join(buf)})
        else:
            i += 1
    return blocks


def merge(template_text: str, target_text: str) -> str:
    tpl_blocks = parse_blocks(template_text)
    tpl_by_key = OrderedDict(
        (b['key'], b) for b in tpl_blocks if b['key']
    )

    lines = target_text.splitlines(keepends=True)
    out = []
    matched = set()
    i, n = 0, len(lines)
    while i < n:
        if TABLE_RE.match(lines[i]):
            buf = [lines[i]]
            i += 1
            key = None
            while i < n:
                line = lines[i]
                if TABLE_RE.match(line) or line.strip() == '':
                    break
                buf.append(line)
                m = ON_RE.match(line)
                if m and key is None:
                    key = _normalize_on(m.group(1))
                i += 1
            if key and key in tpl_by_key:
                out.append(tpl_by_key[key]['text'])
                matched.add(key)
            else:
                out.append(''.join(buf))
        else:
            out.append(lines[i])
            i += 1

    result = ''.join(out)
    unmatched = [b for b in tpl_blocks if b['key'] and b['key'] not in matched]
    if unmatched:
        if not result.endswith('\n'):
            result += '\n'
        if not result.endswith('\n\n'):
            result += '\n'
        for idx, b in enumerate(unmatched):
            if idx > 0:
                result += '\n'
            result += b['text']
            if not b['text'].endswith('\n'):
                result += '\n'

    if not result.endswith('\n'):
        result += '\n'
    return result


def status(template_text: str, target_text: str) -> str:
    tpl_blocks = parse_blocks(template_text)
    tgt_by_key = {
        b['key']: b['text']
        for b in parse_blocks(target_text)
        if b['key']
    }
    for b in tpl_blocks:
        if not b['key']:
            continue
        if b['key'] not in tgt_by_key:
            return 'partial'
        if tgt_by_key[b['key']] != b['text']:
            return 'partial'
    return 'same'


def main() -> None:
    if len(sys.argv) < 4:
        sys.stderr.write(__doc__ or '')
        sys.exit(2)
    cmd, tpl_path, tgt_path = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(tpl_path, encoding='utf-8') as f:
        tpl = f.read()
    with open(tgt_path, encoding='utf-8') as f:
        tgt = f.read()
    if cmd == 'merge':
        sys.stdout.write(merge(tpl, tgt))
    elif cmd == 'status':
        print(status(tpl, tgt))
    else:
        sys.stderr.write(f'unknown cmd: {cmd}\n')
        sys.exit(2)


if __name__ == '__main__':
    main()
