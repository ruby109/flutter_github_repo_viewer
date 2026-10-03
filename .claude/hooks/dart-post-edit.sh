#!/bin/sh
# Claude Code PostToolUse hook: format and analyze a Dart file after Write/Edit.
# Uses `dart analyze` (not `flutter analyze`) because only it runs analyzer plugins such as riverpod_lint.
# Analyzer issues are written to stderr with exit 2 so Claude sees and fixes them.

f=$(jq -r '.tool_response.filePath // .tool_input.file_path')
case "$f" in *.dart) ;; *) exit 0 ;; esac
[ -f "$f" ] || exit 0

dart format "$f" >/dev/null 2>&1

cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
if ! out=$(dart analyze --fatal-infos "$f" 2>&1); then
  echo "dart analyze found issues in $f:" >&2
  echo "$out" >&2
  exit 2
fi
