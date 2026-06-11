---
description: Run the full local quality gate (mirrors CI) before opening a PR
allowed-tools: Bash, Read
---

Run FutureProof's local quality gate — the same checks CI enforces on every PR
(`.github/workflows/ci.yml`) — and report results concisely.

Run these and summarise pass/fail for each (don't stop at the first failure;
run all, then report):

1. **Tests:** `bundle exec rails test` (and `test:system` if the change touches views/JS)
2. **Security (Ruby):** `bin/brakeman --no-pager`
3. **JS deps:** `bin/importmap audit`
4. **Lint:** `bin/rubocop`
5. **CSP:** `bundle exec rails csp:report`

Then give a one-line verdict: **READY** (all green) or **NOT READY** with the
exact failures and what to fix. Do not claim success unless every check passed.

Note: run with the default rvm ruby (do NOT prepend the homebrew ruby path —
gems are built for rvm ruby-3.4.4). If `$ARGUMENTS` names a single area (e.g.
"services"), you may scope the test run to it, but run the full suite before a PR.
