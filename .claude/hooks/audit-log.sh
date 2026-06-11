#!/usr/bin/env bash
#
# Motoko audit trail (PostToolUse / Bash|Edit|Write|MultiEdit). Appends one
# timestamped line per agent action to .claude/motoko-activity.log so the
# engineering-agent's work is measurable (actions, files touched, cadence).
#
# Never blocks (PostToolUse can't) and never errors out the tool call.

input=$(cat) || exit 0
command -v jq >/dev/null 2>&1 || exit 0

log="${CLAUDE_PROJECT_DIR:-.}/.claude/motoko-activity.log"
tool=$(printf '%s' "$input" | jq -r '.tool_name // "?"' 2>/dev/null) || exit 0

case "$tool" in
  Bash)
    detail=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null | tr '\n' ' ' | cut -c1-200)
    ;;
  Edit|Write|MultiEdit|NotebookEdit)
    detail=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null)
    ;;
  *)
    detail=""
    ;;
esac

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
printf '%s\t%s\t%s\n' "$ts" "$tool" "$detail" >> "$log" 2>/dev/null || true
exit 0
