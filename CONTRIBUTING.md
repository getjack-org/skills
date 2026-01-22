# Contributing to Jack Skills

**Read [SPIRIT.md](SPIRIT.md) first** to understand the philosophy.

## Core Principle

Skills teach **platform knowledge**, not framework code. The agent already knows React/Hono/Express—skills teach how these integrate with Jack Cloud.

## Skill Structure

```
skills/add-feature/
├── SKILL.md                    # Overview (~200 lines max)
├── reference/                  # Deep-dive docs (loaded on demand)
│   ├── platform-specifics.md
│   └── schema.md
└── scripts/                    # Verification scripts
    └── verify.sh
```

## SKILL.md Format

```markdown
---
name: add-feature
description: >
  Add X capability to any Jack project.
  Use when: user wants X.
  Agent adapts code to project's existing framework.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch
---

# Add Feature to Jack Project

Brief overview of what this skill provides.

## What This Skill Provides
- Platform knowledge the agent doesn't have
- Jack-specific patterns
- Verification steps

## What Agent Figures Out
- Framework-specific code
- UI components
- Stack adaptation

## Prerequisites Check

```bash
# Quick check for requirements
```

## Platform Knowledge

### 1. First Jack-Specific Thing
Explain the pattern, reference detailed docs.

### 2. Second Jack-Specific Thing
...

## Integration Points

What agent needs to implement (not HOW):
1. Create endpoint at X
2. Store data in D1 using schema from reference/
3. Add frontend hook

## Reference Implementation

Brief example for common stack. Point to reference/ for details.

## Verification

```bash
./scripts/verify.sh
```

## Troubleshooting

Common issues and fixes.
```

## Guidelines

### Do

- **Focus on platform knowledge** — What does agent NOT know about Jack Cloud?
- **Use progressive disclosure** — SKILL.md is overview, reference/ has details
- **Include verification** — Scripts to confirm setup worked
- **Keep SKILL.md under 300 lines** — Details go in reference/
- **Write integration points** — WHAT to implement, not exact code

### Don't

- **Don't over-specify code** — Agent knows frameworks, let it adapt
- **Don't assume specific stack** — Support Hono, Express, Next.js, etc.
- **Don't bundle features** — One capability per skill
- **Don't skip verification** — Agent and user need confirmation

## Testing

```bash
# Verify skill structure
jq . .claude-plugin/plugin.json

# Check SKILL.md frontmatter
head -20 skills/add-feature/SKILL.md

# Test verification script
./skills/add-feature/scripts/verify.sh

# Local plugin install
/plugin install /path/to/skills
```

## Pull Request Checklist

- [ ] Skill follows platform-knowledge pattern (not copy-paste guide)
- [ ] SKILL.md under 300 lines
- [ ] Reference files for detailed docs
- [ ] Verification script included
- [ ] Tested on fresh Jack project
- [ ] CI passes

## Skill Ideas

Looking for contributions in:

- `add-ai` — Workers AI integration, streaming patterns
- `add-embeddings` — Vectorize setup, chunking strategies
- `add-auth` — Authentication patterns (Better Auth, custom)
- `add-queue` — Background job processing
- `add-storage` — R2 file uploads
- `add-email` — Transactional email (Resend, etc.)

## Questions?

- Open an issue for discussion
- Check existing skills for patterns
