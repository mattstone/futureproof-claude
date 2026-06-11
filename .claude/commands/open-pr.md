---
description: Open a PR for the current work (L2 supervised-autonomy flow, human merges)
argument-hint: "[optional PR title]"
allowed-tools: Bash, Read
---

Open a pull request for the current work. This is the L2 hand-off: the agent
prepares everything; **a human reviews and merges.** Never merge or push to main.

Steps:
1. **Branch check.** Run `git branch --show-current`. If it's `main` or `master`,
   STOP — create a feature branch first (`git switch -c <descriptive-name>`).
   The guardrail hook blocks pushing to main regardless; don't fight it.
2. **Run the gate.** Run `/run-checks` (tests, brakeman, importmap audit, rubocop,
   csp:report). If anything fails, fix it before continuing — do not open a red PR.
3. **Review the diff.** `git status` + `git diff` (and `git diff --staged`). Confirm
   no secrets, no `.env`, no stray debug code, no unrelated changes.
4. **Commit** with a concise message focused on the "why" (only if the user has
   asked you to commit). Co-author line per repo convention.
5. **Push the feature branch** and open the PR with `gh pr create`, title
   "$ARGUMENTS" (or a concise generated title). Body: summary + test plan +
   confirmation that the local gate passed.
6. **Report the PR URL.** State clearly that it awaits human review and merge —
   merging is what triggers the production deploy (`fly-deploy.yml`).

Do NOT: push to main/master, force-push, or run `fly deploy`. Those are human actions.
