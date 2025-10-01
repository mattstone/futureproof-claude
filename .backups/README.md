# Deployment Backups

This directory contains backups of critical deployment configuration files.

## Fly.io Deployment Files

Location: `.backups/fly/`

**IMPORTANT: DO NOT modify Fly deployment configuration without explicit permission**

### Backed up files:
- `fly.toml.backup` - Fly.io configuration (internal_port: 8080)
- `Dockerfile.backup` - Docker build configuration (Rails on port 8080)
- `docker-entrypoint.backup` - Container startup script

### Working Configuration (as of 2025-10-01):
- Rails runs directly on port 8080 (no Thruster)
- `fly.toml` internal_port: 8080
- Dockerfile CMD: `["./bin/rails", "server", "-b", "0.0.0.0", "-p", "8080"]`
- Health check grace period: 30s

### To Restore:
```bash
cp .backups/fly/fly.toml.backup fly.toml
cp .backups/fly/Dockerfile.backup Dockerfile
cp .backups/fly/docker-entrypoint.backup bin/docker-entrypoint
```

### Branch Information:
- Main branch: **master** (not main)
- Deployment URL: https://futureproof.fly.dev/
