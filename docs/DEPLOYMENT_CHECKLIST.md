# Deployment Checklist

## Pre-Deploy
- [ ] `fly auth whoami` — correct account
- [ ] `fly status` — correct app
- [ ] `rails test` — 0 failures
- [ ] `bin/rails csp:report` — 0 violations
- [ ] `git status` — clean working tree
- [ ] `git log --oneline -5` — review commits

## Deploy
```bash
fly deploy --remote-only
```

## Post-Deploy
- [ ] Visit homepage — renders correctly
- [ ] Visit /au, /nz, /uk — region routing works
- [ ] Try quote calculator — returns results
- [ ] Visit /admin — dashboard loads, agent activity stream runs
- [ ] Visit /legal — all 24 templates render
- [ ] Check logs: `fly logs`

## Rollback
```bash
fly releases
fly deploy --image <previous-image>
```
