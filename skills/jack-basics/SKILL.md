---
name: jack-basics
description: >
  Essential Jack Cloud patterns for AI agents.
  Use when: working in any Jack project, querying databases, deploying, or managing services.
  Teaches: how to use Jack CLI effectively for common tasks.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Jack Basics

Work effectively in Jack Cloud projects. All commands run from the project root.

## Quick Reference

| Task | Command |
|------|---------|
| Deploy | `jack ship` |
| Check status | `jack info` |
| Stream logs | `jack logs` |
| Query database | `jack db execute "SELECT ..."` |
| Write to database | `jack db execute --write "INSERT ..."` |
| Create database | `jack services db create` |
| Set secret | `jack secrets set KEY` |
| List projects | `jack ls` |

---

## Key Concept

Jack projects use **cloud infrastructure**. Databases and storage run on Cloudflare's edge network, not locally. Always use `jack` commands for operations.

---

## Deploy & Monitor

### Push Changes Live

```bash
jack ship
```

For machine-readable output (useful in scripts):

```bash
jack ship --json
```

### Check Status

```bash
jack info
```

Shows: live URL, last deploy time, attached services.

### Stream Production Logs

```bash
jack logs
```

Real-time request/response logs. Ctrl+C to stop.

---

## Database Operations

### Query Data

```bash
jack db execute "SELECT * FROM users LIMIT 10"
```

For JSON output:

```bash
jack db execute --json "SELECT * FROM users LIMIT 10"
```

### Modify Data

```bash
jack db execute --write "INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com')"
```

### View Schema

```bash
jack db execute "SELECT name FROM sqlite_master WHERE type='table'"
jack db execute "PRAGMA table_info(users)"
```

### Create Tables

```bash
jack db execute --write "CREATE TABLE posts (id INTEGER PRIMARY KEY, title TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP)"
```

After schema changes, redeploy: `jack ship`

---

## Services

### Create Services

```bash
jack services db create        # D1 database
jack services storage create   # R2 bucket
jack services vectorize create # Vector index
```

### List All Services

```bash
jack services
```

---

## Secrets

```bash
jack secrets set STRIPE_SECRET_KEY     # Prompts for value (hidden)
jack secrets set API_KEY WEBHOOK_SECRET # Set multiple
jack secrets list                       # List names (values hidden)
```

Redeploy after adding secrets: `jack ship`

---

## Project Structure

```
my-project/
├── src/
│   └── index.ts          # Worker entry point (Hono app)
├── wrangler.jsonc        # Config: bindings, routes, compatibility
├── package.json
└── .jack/
    └── project.json      # Links to Jack Cloud
```

- **`src/index.ts`** — Main entry point, typically a Hono app
- **`wrangler.jsonc`** — Defines D1 bindings, env vars, compatibility flags
- **`.jack/project.json`** — Links local directory to your Jack Cloud project

---

## MCP Tools (When Available)

If `mcp__jack__*` tools are in your available tools, prefer them over CLI:

| Tool | CLI Equivalent |
|------|----------------|
| `mcp__jack__deploy_project` | `jack ship` |
| `mcp__jack__get_project_status` | `jack info` |
| `mcp__jack__execute_sql` | `jack db execute` |
| `mcp__jack__create_database` | `jack services db create` |
| `mcp__jack__tail_logs` | `jack logs` |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Database not found" | `jack services db create` |
| "Not a Jack project" | `jack link` to link directory |
| MCP tools not available | `jack mcp install`, then restart agent |
| Deploy fails | Check `jack logs`, fix code, `jack ship` again |
| "Not authenticated" | `jack login` |
