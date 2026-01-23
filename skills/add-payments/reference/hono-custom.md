# Hono + Custom Auth Example

This example shows Stripe webhook handling with custom/no auth.

## Dependencies

```bash
bun add stripe
```

## Types (src/types.ts)

```typescript
export type Env = {
  DB: D1Database;
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET: string;
  STRIPE_PRO_PRICE_ID?: string;
  STRIPE_ENTERPRISE_PRICE_ID?: string;
};

export interface User {
  id: string;
  email: string;
  stripe_customer_id: string | null;
  created_at: string;
}

export interface Subscription {
  id: string;
  user_id: string;
  stripe_subscription_id: string;
  stripe_price_id: string;
  plan: string;
  status: string;
  cancel_at_period_end: boolean;
  current_period_end: string;
  created_at: string;
  updated_at: string;
}
```

## Webhook Handler (src/routes/webhook.ts)

```typescript
import { Hono } from "hono";
import Stripe from "stripe";
import type { Env } from "../types";

const webhook = new Hono<{ Bindings: Env }>();

webhook.post("/stripe", async (c) => {
  const stripe = new Stripe(c.env.STRIPE_SECRET_KEY);

  // Get raw body for signature verification
  const body = await c.req.text();
  const signature = c.req.header("stripe-signature");

  if (!signature) {
    return c.json({ error: "Missing signature" }, 400);
  }

  let event: Stripe.Event;

  try {
    // IMPORTANT: Use async version for Jack Cloud
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      c.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return c.json({ error: "Invalid signature" }, 400);
  }

  // Idempotency check
  const existingEvent = await c.env.DB
    .prepare("SELECT id FROM stripe_webhook_event WHERE stripe_event_id = ?")
    .bind(event.id)
    .first();

  if (existingEvent) {
    return c.json({ received: true, duplicate: true });
  }

  // Store event for idempotency
  await c.env.DB
    .prepare("INSERT INTO stripe_webhook_event (id, stripe_event_id, event_type) VALUES (?, ?, ?)")
    .bind(crypto.randomUUID(), event.id, event.type)
    .run();

  // Handle events
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      await handleCheckoutComplete(c.env.DB, session);
      break;
    }

    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const subscription = event.data.object as Stripe.Subscription;
      await handleSubscriptionUpsert(c.env.DB, subscription, c.env);
      break;
    }

    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      await handleSubscriptionDelete(c.env.DB, subscription);
      break;
    }

    case "invoice.paid": {
      const invoice = event.data.object as Stripe.Invoice;
      console.log(`Invoice paid: ${invoice.id}`);
      break;
    }

    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice;
      console.log(`Invoice payment failed: ${invoice.id}`);
      // TODO: Notify user
      break;
    }

    default:
      console.log(`Unhandled event: ${event.type}`);
  }

  return c.json({ received: true });
});

async function handleCheckoutComplete(db: D1Database, session: Stripe.Checkout.Session) {
  const customerId = session.customer as string;
  const email = session.customer_email;

  // Find or create user
  let user = await db
    .prepare("SELECT id FROM user WHERE stripe_customer_id = ? OR email = ?")
    .bind(customerId, email)
    .first();

  if (!user) {
    // Create user if not exists
    const userId = crypto.randomUUID();
    await db
      .prepare("INSERT INTO user (id, email, stripe_customer_id) VALUES (?, ?, ?)")
      .bind(userId, email, customerId)
      .run();
    user = { id: userId };
  } else {
    // Update customer ID if not set
    await db
      .prepare("UPDATE user SET stripe_customer_id = ? WHERE id = ?")
      .bind(customerId, user.id)
      .run();
  }
}

async function handleSubscriptionUpsert(db: D1Database, subscription: Stripe.Subscription, env: Env) {
  // Get price ID from first subscription item
  const priceId = subscription.items.data[0]?.price.id;
  const plan = getPlanFromPriceId(priceId, env);

  // Get period end from subscription (Stripe SDK v20+)
  // Note: current_period_start/end are on the Subscription object
  const periodEnd = new Date(subscription.current_period_end * 1000).toISOString();

  const userId = await getUserIdFromCustomer(db, subscription.customer as string);
  if (!userId) {
    console.error("User not found for subscription:", subscription.id);
    return;
  }

  await db
    .prepare(`
      INSERT INTO subscription (id, user_id, stripe_subscription_id, stripe_price_id, plan, status, cancel_at_period_end, current_period_end)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(stripe_subscription_id) DO UPDATE SET
        status = excluded.status,
        plan = excluded.plan,
        stripe_price_id = excluded.stripe_price_id,
        cancel_at_period_end = excluded.cancel_at_period_end,
        current_period_end = excluded.current_period_end,
        updated_at = CURRENT_TIMESTAMP
    `)
    .bind(
      crypto.randomUUID(),
      userId,
      subscription.id,
      priceId,
      plan,
      subscription.status,
      subscription.cancel_at_period_end ? 1 : 0,
      periodEnd
    )
    .run();
}

async function handleSubscriptionDelete(db: D1Database, subscription: Stripe.Subscription) {
  await db
    .prepare("UPDATE subscription SET status = 'canceled', updated_at = CURRENT_TIMESTAMP WHERE stripe_subscription_id = ?")
    .bind(subscription.id)
    .run();
}

async function getUserIdFromCustomer(db: D1Database, customerId: string): Promise<string | null> {
  const user = await db
    .prepare("SELECT id FROM user WHERE stripe_customer_id = ?")
    .bind(customerId)
    .first();
  return user?.id as string | null;
}

function getPlanFromPriceId(priceId: string, env: Env): string {
  if (priceId === env.STRIPE_PRO_PRICE_ID) return "pro";
  if (priceId === env.STRIPE_ENTERPRISE_PRICE_ID) return "enterprise";
  return "pro"; // Default
}

export default webhook;
```

## Checkout Endpoints (src/routes/checkout.ts)

```typescript
import { Hono } from "hono";
import Stripe from "stripe";
import type { Env } from "../types";

const checkout = new Hono<{ Bindings: Env }>();

// Create checkout session
checkout.post("/create", async (c) => {
  const stripe = new Stripe(c.env.STRIPE_SECRET_KEY);
  const { email, priceId, successUrl, cancelUrl } = await c.req.json();

  const effectivePriceId = priceId || c.env.STRIPE_PRO_PRICE_ID;

  if (!effectivePriceId) {
    return c.json({ error: "No price ID configured" }, 400);
  }

  // Check for existing customer
  let user = await c.env.DB
    .prepare("SELECT id, stripe_customer_id FROM user WHERE email = ?")
    .bind(email)
    .first();

  let customerId = user?.stripe_customer_id as string | undefined;

  // Create customer if needed
  if (!customerId) {
    const customer = await stripe.customers.create({
      email,
      metadata: { source: "jack-checkout" },
    });
    customerId = customer.id;

    if (user) {
      await c.env.DB
        .prepare("UPDATE user SET stripe_customer_id = ? WHERE id = ?")
        .bind(customerId, user.id)
        .run();
    } else {
      await c.env.DB
        .prepare("INSERT INTO user (id, email, stripe_customer_id) VALUES (?, ?, ?)")
        .bind(crypto.randomUUID(), email, customerId)
        .run();
    }
  }

  // Create checkout session
  // Note: For curl/API testing, pass explicit successUrl/cancelUrl in request body
  // For browser requests, origin header is used automatically
  const baseUrl = c.req.header("origin") || c.req.header("referer") || "";
  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: "subscription",
    line_items: [{ price: effectivePriceId, quantity: 1 }],
    success_url: successUrl || `${baseUrl}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: cancelUrl || `${baseUrl}/pricing`,
  });

  return c.json({ url: session.url });
});

// Create billing portal session
checkout.post("/portal", async (c) => {
  const stripe = new Stripe(c.env.STRIPE_SECRET_KEY);
  const { email } = await c.req.json();

  const user = await c.env.DB
    .prepare("SELECT stripe_customer_id FROM user WHERE email = ?")
    .bind(email)
    .first();

  if (!user?.stripe_customer_id) {
    return c.json({ error: "No subscription found" }, 404);
  }

  const baseUrl = c.req.header("origin") || c.req.header("referer") || "";
  const { returnUrl } = await c.req.json().catch(() => ({}));
  const session = await stripe.billingPortal.sessions.create({
    customer: user.stripe_customer_id as string,
    return_url: returnUrl || `${baseUrl}/dashboard`,
  });

  return c.json({ url: session.url });
});

export default checkout;
```

## Subscription Endpoints (src/routes/subscription.ts)

```typescript
import { Hono } from "hono";
import type { Env, Subscription } from "../types";

const subscription = new Hono<{ Bindings: Env }>();

// Get subscription status
subscription.get("/status", async (c) => {
  const email = c.req.query("email");
  const userId = c.req.query("userId");

  if (!email && !userId) {
    return c.json({ error: "email or userId required" }, 400);
  }

  // Find user
  const user = await c.env.DB
    .prepare("SELECT id, stripe_customer_id FROM user WHERE email = ? OR id = ?")
    .bind(email || "", userId || "")
    .first();

  if (!user) {
    return c.json({
      subscribed: false,
      plan: "free",
      status: null,
    });
  }

  // Find active subscription
  const sub = await c.env.DB
    .prepare(`
      SELECT * FROM subscription
      WHERE user_id = ? AND status IN ('active', 'trialing')
      ORDER BY created_at DESC LIMIT 1
    `)
    .bind(user.id)
    .first() as Subscription | null;

  if (!sub) {
    return c.json({
      subscribed: false,
      plan: "free",
      status: null,
    });
  }

  return c.json({
    subscribed: true,
    plan: sub.plan,
    status: sub.status,
    cancelAtPeriodEnd: Boolean(sub.cancel_at_period_end),
    currentPeriodEnd: sub.current_period_end,
    userId: user.id,
  });
});

export default subscription;
```

## Database Schema (schema.sql)

```sql
-- Users table
CREATE TABLE IF NOT EXISTS user (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  stripe_customer_id TEXT UNIQUE,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS subscription (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES user(id),
  stripe_subscription_id TEXT UNIQUE NOT NULL,
  stripe_price_id TEXT NOT NULL,
  plan TEXT NOT NULL,
  status TEXT NOT NULL,
  cancel_at_period_end INTEGER DEFAULT 0,
  current_period_end TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Webhook idempotency table
CREATE TABLE IF NOT EXISTS stripe_webhook_event (
  id TEXT PRIMARY KEY,
  stripe_event_id TEXT UNIQUE NOT NULL,
  event_type TEXT NOT NULL,
  processed_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_subscription_user ON subscription(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_status ON subscription(status);
CREATE INDEX IF NOT EXISTS idx_user_email ON user(email);
CREATE INDEX IF NOT EXISTS idx_user_customer ON user(stripe_customer_id);
```

## Main App (src/index.ts)

```typescript
import { Hono } from "hono";
import type { Env } from "./types";
import webhook from "./routes/webhook";
import checkout from "./routes/checkout";
import subscription from "./routes/subscription";

const app = new Hono<{ Bindings: Env }>();

app.get("/", (c) => c.json({ status: "ok" }));
app.get("/health", (c) => c.json({ status: "ok" }));

// Mount routes
app.route("/api/webhooks", webhook);
app.route("/api/checkout", checkout);
app.route("/api/subscription", subscription);

export default app;
```

## .secrets.json Template

```json
{
  "STRIPE_SECRET_KEY": "sk_test_...",
  "STRIPE_WEBHOOK_SECRET": "whsec_...",
  "STRIPE_PRO_PRICE_ID": "price_...",
  "STRIPE_ENTERPRISE_PRICE_ID": "price_..."
}
```

**Note on redirects**: When testing via curl (no browser), checkout redirect goes to empty URL - this is fine, the payment still works. For frontend apps, the `origin` header handles redirects automatically.
