#!/usr/bin/env python3
"""Per-key merger for gitconfig-style files.

Rule: template keys overwrite target keys (no value-level diff); keys that
exist only in target are preserved. Sections that exist only in template
are appended. Comments and blank lines in the target are left in place.

Section and key names are matched case-insensitively (git's own rule);
subsection names (`[section "sub"]`) are matched case-sensitively.

Usage:
  gitconfig_merge.py status TEMPLATE TARGET   # prints: same | partial
  gitconfig_merge.py merge  TEMPLATE TARGET   # prints merged target to stdout
"""
from __future__ import annotations

import re
import sys
from collections import OrderedDict

SECTION_RE = re.compile(
    r'^\s*\[\s*([A-Za-z0-9._-]+)(?:\s+"((?:[^"\\]|\\.)*)")?\s*\]\s*(?:[#;].*)?$'
)
KEY_RE = re.compile(r'^\s*([A-Za-z0-9][A-Za-z0-9-]*)\s*=\s*(.*)$')


def parse(text):
    """Return list of items.

    Items:
      ('section', name, sub, raw)
      ('entry',   name, sub, key, raw)   # raw may include backslash continuations
      ('other',   raw)                   # blank lines, comments, stray lines
    """
    lines = text.splitlines(keepends=True)
    items = []
    cur_name = None
    cur_sub = None
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        ms = SECTION_RE.match(line)
        if ms:
            cur_name = ms.group(1)
            cur_sub = ms.group(2)
            items.append(('section', cur_name, cur_sub, line))
            i += 1
            continue
        if cur_name is not None:
            mk = KEY_RE.match(line)
            if mk:
                buf = line
                while buf.rstrip('\r\n').endswith('\\') and i + 1 < n:
                    i += 1
                    buf += lines[i]
                items.append(('entry', cur_name, cur_sub, mk.group(1), buf))
                i += 1
                continue
        items.append(('other', line))
        i += 1
    return items


def _norm(name, sub, key):
    return (name.lower(), sub, key.lower())


def merge(template_text: str, target_text: str) -> str:
    tpl = parse(template_text)
    dst = parse(target_text)

    tpl_by_key = OrderedDict()
    for it in tpl:
        if it[0] == 'entry':
            k = _norm(it[1], it[2], it[3])
            if k not in tpl_by_key:
                tpl_by_key[k] = it  # first occurrence wins inside template

    # Pass 1: walk target; replace first match of each template key, drop extras.
    pass1 = []
    replaced = set()
    for it in dst:
        if it[0] == 'entry':
            k = _norm(it[1], it[2], it[3])
            if k in tpl_by_key:
                if k not in replaced:
                    t = tpl_by_key[k]
                    pass1.append(('entry', it[1], it[2], it[3], t[4]))
                    replaced.add(k)
                # else: duplicate in target; template overrides -> drop
                continue
        pass1.append(it)

    # Pass 2: for sections present in target, insert missing template entries
    # just after the last entry line of that section.
    missing = [
        tpl_by_key[k] for k in tpl_by_key if k not in replaced
    ]
    # Bucket missing by (name_lower, sub)
    by_section = OrderedDict()
    for m in missing:
        key = (m[1].lower(), m[2])
        by_section.setdefault(key, []).append(m)

    # Track last-entry index per section in pass1.
    last_entry_idx = {}
    cur_sec = None
    for idx, it in enumerate(pass1):
        if it[0] == 'section':
            cur_sec = (it[1].lower(), it[2])
            last_entry_idx.setdefault(cur_sec, idx)
        elif cur_sec is not None and it[0] == 'entry':
            last_entry_idx[cur_sec] = idx

    existing_sections = set(last_entry_idx.keys())
    insert_here = OrderedDict(
        (k, v) for k, v in by_section.items() if k in existing_sections
    )
    append_new = OrderedDict(
        (k, v) for k, v in by_section.items() if k not in existing_sections
    )

    # Insert into existing sections — walk from end to keep earlier indices stable.
    result = list(pass1)
    for sec in reversed(list(insert_here.keys())):
        idx = last_entry_idx[sec]
        entries = insert_here[sec]
        for m in reversed(entries):
            result.insert(idx + 1, ('entry', m[1], m[2], m[3], m[4]))

    # Append new sections. Preserve original section header text from template
    # when available; otherwise synthesize.
    tpl_section_raw = {}
    for it in tpl:
        if it[0] == 'section':
            tpl_section_raw[(it[1].lower(), it[2])] = it[3]

    if append_new:
        # Ensure a blank separator before appending.
        if result and not (result[-1][0] == 'other' and result[-1][1].strip() == ''):
            result.append(('other', '\n'))

    for sec, entries in append_new.items():
        header = tpl_section_raw.get(sec)
        if header is None:
            if sec[1] is None:
                header = '[%s]\n' % entries[0][1]
            else:
                header = '[%s "%s"]\n' % (entries[0][1], sec[1])
        result.append(('section', entries[0][1], sec[1], header))
        for m in entries:
            result.append(('entry', m[1], m[2], m[3], m[4]))

    # Serialize.
    out = []
    for it in result:
        if it[0] == 'section':
            out.append(it[3])
        elif it[0] == 'entry':
            out.append(it[4])
        else:
            out.append(it[1])
    text = ''.join(out)
    if not text.endswith('\n'):
        text += '\n'
    return text


def status(template_text: str, target_text: str) -> str:
    merged = merge(template_text, target_text)
    return 'same' if merged == target_text else 'partial'


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
        sys.stderr.write('unknown cmd: %s\n' % cmd)
        sys.exit(2)


if __name__ == '__main__':
    main()
