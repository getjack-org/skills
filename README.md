# Jack Skills

Official skill library for Jack projects. Skills are capability chips that plug platform knowledge directly into your AI agent's brain.

**Read [SPIRIT.md](SPIRIT.md) for the philosophy behind skills.**

## The Concept

```
User: "Add payments to my app"

Agent without skills:
  → Searches web, guesses at patterns
  → Doesn't know Jack secrets workflow
  → 45 minutes of trial and error

Agent with add-payments skill:
  → "I know kung fu"
  → Knows .secrets.json → deployed secrets
  → Knows D1 subscription schema
  → Knows webhook URL patterns
  → Ships in 10 minutes
```

Skills teach agents **Jack-specific platform knowledge** they can't find elsewhere. The agent already knows React/Hono/Stripe—skills teach how these integrate with Jack Cloud.

## Installation

### Via Claude Code Plugin

```
/plugin install getjack/skills
```

### Via Jack CLI (Coming Soon)

```bash
# Search available skills
jack skills search payments

# Install a skill
jack skills install add-payments

# List installed skills
jack skills list

# Get skill info
jack skills info add-payments
```

## Available Skills

### add-payments

Add Stripe subscription payments to any Jack project.

**What agent learns:**
- Jack secrets pattern (`.secrets.json` → deployed secrets)
- D1 subscription schema
- Webhook endpoint requirements for Cloudflare Workers
- Verification steps

**What agent figures out:**
- Framework-specific routes (Hono, Express, Next.js)
- Auth library integration (Better Auth, NextAuth, custom)
- Frontend components for your stack

**Prerequisites:**
- Jack project with D1 database
- Stripe account (test mode works)

**Invoke:**
```
"Add payments to my project"
```
or explicitly:
```
/jack-skills:add-payments
```

## How Skills Work

Skills are NOT copy-paste guides. They're **platform knowledge injection**.

| Skills Provide | Agent Figures Out |
|----------------|-------------------|
| Jack secrets pattern | Framework-specific code |
| D1 database schemas | Route implementation |
| Webhook URL requirements | UI components |
| Verification scripts | Stack adaptation |

### Skill Structure

```
add-payments/
├── SKILL.md                    # Overview (~200 lines)
├── reference/
│   ├── stripe-webhooks.md      # Webhook events, signatures
│   ├── d1-subscription.md      # Database schema
│   └── secrets-pattern.md      # How Jack handles secrets
└── scripts/
    └── verify-webhook.sh       # Confirm it worked
```

Agent loads SKILL.md first, then reference files as needed. Progressive disclosure keeps context efficient.

## Creating Skills

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new skills.

**Key principles:**
1. Platform knowledge, not framework code
2. Integration points, not copy-paste
3. One capability per skill
4. Verification built in
5. Progressive disclosure

## Jack CLI Commands

These commands will be available in jack CLI:

| Command | Description |
|---------|-------------|
| `jack skills search <query>` | Search available skills |
| `jack skills install <name>` | Install a skill for your agent |
| `jack skills list` | List installed skills |
| `jack skills info <name>` | Show skill details |
| `jack skills update` | Update all installed skills |
| `jack skills remove <name>` | Remove an installed skill |

Skills are installed per-project in `.jack/skills/` or globally in `~/.config/jack/skills/`.

## Roadmap

- [x] `add-payments` — Stripe subscriptions
- [ ] `add-ai` — Workers AI integration
- [ ] `add-embeddings` — Vectorize + document processing
- [ ] `add-auth` — Authentication patterns
- [ ] `add-queue` — Background job processing
- [ ] `add-storage` — R2 file uploads

## Feedback & Issues

- [GitHub Issues](https://github.com/getjack/skills/issues)
- [Jack Discord](https://discord.gg/jack)

## License

MIT
