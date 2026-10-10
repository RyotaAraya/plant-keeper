#!/usr/bin/env python3
# PreToolUse（Bash）: PR 本文に `## セルフレビュー` の節がない `gh pr create` を止める。
# fix-issue の手順 5（セルフレビュー）を、変更が小さいからと飛ばさないようにするため。
# 本文は、コマンドに直接書いたもの（--body / heredoc）と、--body-file / -F で渡したファイルの両方を見る。
import json
import re
import shlex
import sys

command = json.load(sys.stdin).get("tool_input", {}).get("command", "")
if not re.search(r"\bgh\s+pr\s+create\b", command):
    sys.exit(0)

text = command
try:
    tokens = shlex.split(command, posix=True)
except ValueError:
    tokens = []
for i, token in enumerate(tokens):
    path = None
    if token in ("--body-file", "-F") and i + 1 < len(tokens):
        path = tokens[i + 1]
    elif token.startswith("--body-file="):
        path = token.split("=", 1)[1]
    if path and path != "-":
        try:
            with open(path, encoding="utf-8") as f:
                text += f.read()
        except OSError:
            pass

if "## セルフレビュー" in text:
    sys.exit(0)

print(
    "PR 本文に `## セルフレビュー` の節がありません。fix-issue の手順 5 に沿って "
    "`git diff <base>...HEAD` をレビュアーとして読み、観点ごとに確かめたこと・直したこと・残したことを "
    "`## セルフレビュー` に書いてから、PR を作り直してください（指摘がなくても、確かめた観点を書く）。",
    file=sys.stderr,
)
sys.exit(2)
