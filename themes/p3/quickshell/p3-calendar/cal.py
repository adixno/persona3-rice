#!/usr/bin/env python3
"""p3-calendar helper: reads and edits the plans file.

The file (~/.local/share/persona-rice/calendar.txt, or $P3_CALENDAR_FILE) is plain text,
one plan per line:
    2026-11-20 DBMS exam          a dated plan
    *-12-25 Christmas             every year on that day
    # anything                    a comment

  cal.py list               → one JSON line {"file": ..., "events": [{date, text, line}]}
  cal.py add DATE TEXT...   → append a plan (DATE = YYYY-MM-DD or *-MM-DD)
  cal.py touch              → create the file (with a short how-to header) if missing
  cal.py del LINE TEXT...   → delete line LINE (1-based), only if it still holds TEXT
"""
import json
import os
import re
import sys

FILE = os.environ.get("P3_CALENDAR_FILE") or os.path.expanduser("~/.local/share/persona-rice/calendar.txt")
PAT = re.compile(r"^\s*((?:\d{4}|\*)-\d{2}-\d{2})\s+(.*\S)\s*$")
HEADER = """# Plans for the p3 calendar (SUPER+Y). One per line:
#   2026-11-20 DBMS exam
#   *-12-25 Christmas        (every year)
"""


def lines():
    try:
        with open(FILE, encoding="utf-8") as f:
            return f.read().split("\n")
    except FileNotFoundError:
        return []


def save(ls):
    os.makedirs(os.path.dirname(FILE), exist_ok=True)
    text = "\n".join(ls)
    if not text.endswith("\n"):
        text += "\n"
    tmp = FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, FILE)


def events():
    out = []
    for n, l in enumerate(lines(), 1):
        if l.lstrip().startswith("#"):
            continue
        m = PAT.match(l)
        if m:
            out.append({"date": m.group(1), "text": m.group(2), "line": n})
    return out


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "list"
    if cmd == "add" and len(argv) >= 4:
        date, text = argv[2], " ".join(argv[3:]).strip()
        text = " ".join(text.split())
        if not re.fullmatch(r"(?:\d{4}|\*)-\d{2}-\d{2}", date) or not text:
            return 2
        ls = lines()
        if not ls:
            ls = HEADER.split("\n")
        while ls and ls[-1] == "":
            ls.pop()
        ls.append(f"{date} {text}")
        save(ls)
    elif cmd == "touch":
        if not os.path.exists(FILE):
            save(HEADER.split("\n"))
    elif cmd == "del" and len(argv) >= 4:
        n, text = int(argv[2]), " ".join(argv[3:])
        ls = lines()
        m = PAT.match(ls[n - 1]) if 0 < n <= len(ls) else None
        if not m or m.group(2) != text:
            return 3
        del ls[n - 1]
        save(ls)
    print(json.dumps({"file": FILE, "events": events()}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
