#!/usr/bin/env bash
#
# Motoko guardrail (PreToolUse / Bash). Makes CLAUDE.md's ZERO TOLERANCE rules
# structural instead of discretionary: blocks irreversible / production-affecting
# shell commands before they run.
#
# Blocks: destructive DB tasks, force pushes, pushes to main/master (main
# auto-deploys to prod — humans merge PRs), and rm -rf on root/home/glob targets.
#
# Contract: print a deny decision as JSON on stdout and exit 0 to block; exit 0
# with no output to allow. FAILS OPEN — any parse error allows the command, so a
# malformed input can never brick the session (this is a productivity guard, not
# an adversarial security boundary).

input=$(cat) || exit 0
command -v jq >/dev/null 2>&1 || exit 0

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$cmd" ] && exit 0

# Collapse newlines so multi-line commands still match.
norm=$(printf '%s' "$cmd" | tr '\n' ' ')

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# 1. Destructive database tasks.
if printf '%s' "$norm" | grep -Eiq '\bdb:(drop|reset|purge|schema:load)\b'; then
  deny "Blocked by Motoko guardrail: destructive DB task (db:drop/reset/purge/schema:load). CLAUDE.md is ZERO TOLERANCE on data loss — ask a human and back up first."
fi
if printf '%s' "$norm" | grep -Eiq '\bdatabase_reset\b'; then
  deny "Blocked by Motoko guardrail: database_reset is destructive. Ask a human."
fi

# 2. Force push (rewrites remote history).
if printf '%s' "$norm" | grep -Eiq 'git +push\b.*(--force\b|--force-with-lease| -f\b)'; then
  deny "Blocked by Motoko guardrail: force push rewrites remote history. Use a normal push or open a PR."
fi

# 3. Push to main/master — main auto-deploys to PRODUCTION (fly-deploy.yml).
if printf '%s' "$norm" | grep -Eiq 'git +push\b.*( main| master)([ :]|$)'; then
  deny "Blocked by Motoko guardrail: pushing to main/master. main auto-deploys to PROD — open a PR and let a human merge."
fi

# 4. rm -rf on root / home / glob targets.
if printf '%s' "$norm" | grep -Eiq 'rm +-[a-z]*[rf][a-z]* +(/|~|\$HOME|\*)([ /]|$)'; then
  deny "Blocked by Motoko guardrail: rm -rf on a root/home/glob target. Narrow the path or ask a human."
fi

exit 0
