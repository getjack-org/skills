---
name: add-payments
description: >
  Add Stripe subscription payments to any Jack project.
  Use when: user wants payments, subscriptions, billing, or checkout.
  Stack-agnostic: works with any framework (Hono, Next.js, Express) and auth library.
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebFetch
---

# Add Payments to Jack Project

This skill teaches **what you need** for Stripe payments on Jack Cloud. You figure out **how to implement it** for the project's specific stack.

## What This Skill Provides

- Required secrets and their formats
- Webhook events to handle
- Data model for subscriptions
- Jack Cloud deployment patterns
- Verification scripts

## What You Figure Out

- Route implementation (Hono, Express, Next.js, etc.)
- Auth integration (Better Auth, NextAuth, Lucia, custom)
- Database integration (D1 directly, Drizzle, Prisma, Kysely)
- Frontend components

## Prerequisites

```bash
# Must have Jack project
ls .jack.json wrangler.jsonc 2>/dev/null
```

## Required Secrets

These secrets must exist in `.secrets.json` before deployment:

| Secret | Format | Required | Source |
|--------|--------|----------|--------|
| `STRIPE_SECRET_KEY` | `sk_test_...` or `sk_live_...` | Yes | [API Keys](https://dashboard.stripe.com/apikeys) |
| `STRIPE_WEBHOOK_SECRET` | `whsec_...` | Yes (after first deploy) | Webhook endpoint signing secret |
| `STRIPE_PRO_PRICE_ID` | `price_...` | If using plans | Product price ID |
| `STRIPE_ENTERPRISE_PRICE_ID` | `price_...` | If using plans | Product price ID |

**Verify secrets exist:**
```bash
./scripts/check-secrets.sh
```

**Create Stripe products programmatically:**
```bash
./scripts/setup-stripe-products.sh
```

## Required Webhook Events

Configure these events in Stripe Dashboard → Webhooks:

| Event | When Fired | What to Do |
|-------|------------|------------|
| `checkout.session.completed` | User completes checkout | Create/activate subscription |
| `customer.subscription.created` | Subscription starts | Store subscription record |
| `customer.subscription.updated` | Plan change, renewal, cancellation scheduled | Update subscription record |
| `customer.subscription.deleted` | Subscription ends | Mark subscription inactive |
| `invoice.paid` | Payment succeeds | Update payment status |
| `invoice.payment_failed` | Payment fails | Notify user, update status |

## Webhook Endpoint Requirements

Create an endpoint that:

1. **Receives POST** at a consistent path (e.g., `/api/webhooks/stripe`)
2. **Verifies signature** using `STRIPE_WEBHOOK_SECRET`
3. **Reads raw body** (not parsed JSON) for signature verification
4. **Handles events** listed above
5. **Returns 200** quickly (do heavy work async if needed)

**Cloudflare Workers note:** Use `stripe.webhooks.constructEventAsync()` (async version).

## Data Model

Store this subscription data (adapt to your ORM/database):

```
subscription:
  id: string (primary key)
  user_id: string (foreign key to user)
  stripe_customer_id: string
  stripe_subscription_id: string
  stripe_price_id: string
  plan: string ("pro", "enterprise", etc.)
  status: string ("active", "trialing", "past_due", "canceled")
  cancel_at_period_end: boolean
  current_period_end: timestamp
  created_at: timestamp
  updated_at: timestamp
```

**User table addition:**
```
user:
  ... existing fields ...
  stripe_customer_id: string (nullable)
```

See [reference/d1-schema.sql](reference/d1-schema.sql) for raw SQL if using D1 directly.

## Checkout Flow

Implement this flow:

1. **User clicks upgrade** → Frontend calls your backend
2. **Backend creates Checkout Session** → Returns Stripe URL
3. **Redirect user to Stripe** → User completes payment
4. **Stripe sends webhook** → `checkout.session.completed`
5. **Backend creates subscription** → User is now subscribed

```
Frontend          Backend              Stripe
   │                 │                   │
   │─── upgrade ────►│                   │
   │                 │── create session ─►│
   │                 │◄── session URL ───│
   │◄── redirect ────│                   │
   │─────────────────────── payment ────►│
   │                 │◄─── webhook ──────│
   │                 │   (create sub)    │
   │◄── show success │                   │
```

## Setup Flow

1. **Add Stripe secret** to `.secrets.json`
2. **Create products** (run `./scripts/setup-stripe-products.sh` or via Dashboard)
3. **Implement webhook endpoint** in your framework
4. **Implement checkout flow** (session creation + redirect)
5. **Add subscription state** to your database
6. **Deploy** with `jack ship`
7. **Configure webhook** in Stripe Dashboard with deployed URL
8. **Add webhook secret** to `.secrets.json`
9. **Redeploy** with `jack ship`
10. **Verify** with `./scripts/verify-setup.sh`

## Verification

```bash
# Check all secrets are configured
./scripts/check-secrets.sh

# After deployment, verify webhook works
./scripts/verify-setup.sh
```

**Manual verification:**
- [ ] Secrets configured (check with script)
- [ ] Webhook endpoint returns 200 for POST
- [ ] Test checkout with card `4242 4242 4242 4242`
- [ ] Webhook logs show successful delivery in Stripe Dashboard
- [ ] Subscription record created in database

## Stack-Specific Examples

After understanding the requirements above, see examples for common stacks:

- [reference/hono-better-auth.md](reference/hono-better-auth.md) — Hono + Better Auth (common Jack stack)
- [reference/hono-custom.md](reference/hono-custom.md) — Hono with custom auth
- [reference/nextjs.md](reference/nextjs.md) — Next.js API routes

These are **examples**, not copy-paste solutions. Adapt to your project's patterns.

## Stripe Documentation

For up-to-date API reference, fetch: `https://docs.stripe.com/llms.txt`

Quick links:
- [Checkout Sessions](https://docs.stripe.com/api/checkout/sessions)
- [Webhook Events](https://docs.stripe.com/webhooks/webhook-events)
- [Webhook Signatures](https://docs.stripe.com/webhooks/signatures)
- [Test Cards](https://docs.stripe.com/testing)

## Troubleshooting

### Webhook signature verification fails
- Ensure using raw request body (not parsed JSON)
- Verify `STRIPE_WEBHOOK_SECRET` matches endpoint in Dashboard
- Use async verification on Cloudflare Workers

### Subscription not created after checkout
- Check webhook logs in Stripe Dashboard
- Verify `checkout.session.completed` event is selected
- Check your webhook handler for errors

### Customer not found
- Ensure creating Stripe customer before checkout
- Or use `customer_email` in checkout session to auto-create
