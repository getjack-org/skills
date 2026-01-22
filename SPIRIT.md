# The Spirit of Jack Skills

## From SPIRIT.md: The Name

In Gibson's *Neuromancer*, "jacking in" means plugging consciousness directly into cyberspace. The meat body becomes irrelevant—you're pure thought in the matrix.

jack handles the meat work (infra, config, deployment) so you stay in creative flow. Think it, ship it. The infrastructure disappears.

## Skills: Expansion Packs for Agents

Skills extend the "prepare the session" principle to capabilities.

**Without skills:** Agent knows general programming but fumbles Jack-specific patterns. Every project re-learns the same lessons.

**With skills:** Agent "jacks in" to platform knowledge instantly. Like Neo downloading martial arts, but for Stripe webhooks and D1 schemas.

```
User: "I want to add payments"

Agent without skill:
  → Searches web for Stripe docs
  → Doesn't know Jack secrets pattern
  → Doesn't know D1 schema conventions
  → Makes mistakes, iterates, 45 minutes

Agent WITH skill installed:
  → "I know kung fu" (Stripe + Jack Cloud)
  → Knows .secrets.json → deployed secrets
  → Knows D1 subscription schema
  → Knows webhook URL pattern
  → Ships in 10 minutes
```

## Skill Design Principles

### 1. Platform Knowledge, Not Framework Code

Agent already knows React/Hono/Express. Skills teach Jack Cloud patterns.

**Bad:** 500 lines of Hono route code the agent could write itself.

**Good:** "Webhook endpoint must be at `/api/webhooks/stripe`. Jack syncs `.secrets.json` on deploy. Here's the D1 schema."

### 2. Integration Points, Not Copy-Paste

Tell agent WHAT to implement, not exact code. Agent adapts to project's stack.

**Bad:** "Create this exact file with this exact code."

**Good:** "Create webhook handler. Must verify signature. Store subscription in D1. See reference/d1-schema.md."

### 3. One Capability Per Skill

Each skill solves one problem well. Compose multiple skills for complex features.

- `add-payments` — Stripe subscriptions
- `add-ai` — Workers AI integration
- `add-embeddings` — Vectorize + document processing
- `add-auth` — Authentication patterns

Not: "payments + auth + database + kitchen sink."

### 4. Verification Built In

Scripts to confirm it worked. Agent shouldn't guess if webhook is live.

```bash
./scripts/verify-webhook.sh
# ✓ Webhook endpoint responds
# ✓ Stripe signature verification works
# ✓ Subscription table exists in D1
```

### 5. Progressive Disclosure

SKILL.md is overview (~200 lines). Reference files for deep dives. Agent loads what it needs.

```
add-payments/
├── SKILL.md                    # Overview, integration points
├── reference/
│   ├── stripe-webhooks.md      # Webhook events, signatures
│   ├── d1-subscription.md      # Database schema
│   └── secrets-pattern.md      # How Jack handles secrets
└── scripts/
    └── verify-webhook.sh       # Verification script
```

### 6. Degrees of Freedom

Match specificity to task fragility (from Anthropic's skill best practices):

| Task Type | Freedom Level | Example |
|-----------|---------------|---------|
| Webhook URLs | Low (exact) | Must be `/api/webhooks/stripe` |
| Route setup | Medium | "Create handler" - agent picks framework |
| UI components | High | Agent decides based on project |

## The Skill Library Vision

```bash
jack skills search payments
# add-payments - Stripe subscription payments

jack skills install add-payments
# ✓ Installed add-payments skill
# Agent now knows Stripe + Jack Cloud integration

jack skills list
# Installed skills:
#   add-payments (v0.1.0)
#   add-ai (v0.2.0)
```

Each skill is a capability chip. Install it, agent has the knowledge. The vibecoder stays in flow—"add payments to this" just works.

## SPIRIT.md Principles Applied

| SPIRIT Principle | How Skills Embody It |
|------------------|---------------------|
| **Prepare the Session** | Skills inject platform knowledge so agent starts informed |
| **Expansion Packs** | Skills ARE expansion packs for agent capabilities |
| **Convention Over Configuration** | Skills encode Jack's conventions (secrets, D1 schema) |
| **Disappear Until Needed** | Agent doesn't think about Cloudflare—skill handles it |
| **No Lock-In** | Skills use standard patterns—no proprietary magic |
| **First Use Is Instant** | Install skill, immediately productive |

## Anti-Patterns

**Don't over-specify framework code.** Agent knows Hono. Don't write 50 lines of route setup it could generate.

**Don't assume stack.** User might have Hono, Next.js, or Express. Skill provides integration points, agent adapts.

**Don't bundle unrelated features.** "Payments" skill shouldn't include auth setup. That's a different skill.

**Don't hide verification.** If there's no way to confirm it worked, agent and user are guessing.

**Don't require reading the whole skill.** Progressive disclosure—agent loads reference files only when needed.

## The Test

Before shipping a skill, ask:

1. Does it teach Jack-specific knowledge the agent couldn't find elsewhere?
2. Can an agent with a different stack still use it?
3. Is there a way to verify it worked?
4. Is SKILL.md under 300 lines with details in reference files?
5. Would installing this skill genuinely save 30+ minutes?

If the answer to #5 is no, the skill isn't valuable enough to exist.

---

Skills exist because vibecoders hit a wall after "jack new" and "jack ship." They want to add payments, AI, embeddings—but the platform-specific knowledge is scattered. Skills plug that knowledge directly into the agent's brain.

We win when "add payments to this" just works, because the agent already knows how.
