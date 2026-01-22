# Hono + Custom Auth Example

This example shows manual Stripe webhook handling without Better Auth.

## Dependencies

```bash
bun add stripe
```

## Webhook Handler (src/routes/webhook.ts)

```typescript
import { Hono } from "hono";
import Stripe from "stripe";

type Env = {
  DB: D1Database;
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET: string;
};

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
    // Use async version for Cloudflare Workers
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      c.env.STRIPE_WEBHOOK_SECRET
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return c.json({ error: "Invalid signature" }, 400);
  }

  // Handle events
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      await handleCheckoutComplete(c.env.DB, session);
      break;
    }

    case "customer.subscription.updated": {
      const subscription = event.data.object as Stripe.Subscription;
      await handleSubscriptionUpdate(c.env.DB, subscription);
      break;
    }

    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      await handleSubscriptionDelete(c.env.DB, subscription);
      break;
    }

    default:
      console.log(`Unhandled event: ${event.type}`);
  }

  return c.json({ received: true });
});

async function handleCheckoutComplete(db: D1Database, session: Stripe.Checkout.Session) {
  // Get customer and subscription from session
  const customerId = session.customer as string;
  const subscriptionId = session.subscription as string;

  // Find user by customer ID or email
  const user = await db
    .prepare("SELECT id FROM user WHERE stripe_customer_id = ? OR email = ?")
    .bind(customerId, session.customer_email)
    .first();

  if (!user) {
    console.error("User not found for checkout:", session.id);
    return;
  }

  // Update user's customer ID if not set
  await db
    .prepare("UPDATE user SET stripe_customer_id = ? WHERE id = ?")
    .bind(customerId, user.id)
    .run();

  // Subscription will be created by subscription.created event
}

async function handleSubscriptionUpdate(db: D1Database, subscription: Stripe.Subscription) {
  const priceId = subscription.items.data[0]?.price.id;
  const plan = getPlanFromPriceId(priceId);

  await db
    .prepare(`
      INSERT INTO subscription (id, user_id, stripe_subscription_id, stripe_price_id, plan, status, cancel_at_period_end, current_period_end)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(stripe_subscription_id) DO UPDATE SET
        status = excluded.status,
        plan = excluded.plan,
        cancel_at_period_end = excluded.cancel_at_period_end,
        current_period_end = excluded.current_period_end,
        updated_at = CURRENT_TIMESTAMP
    `)
    .bind(
      crypto.randomUUID(),
      await getUserIdFromCustomer(db, subscription.customer as string),
      subscription.id,
      priceId,
      plan,
      subscription.status,
      subscription.cancel_at_period_end ? 1 : 0,
      new Date(subscription.current_period_end * 1000).toISOString()
    )
    .run();
}

async function handleSubscriptionDelete(db: D1Database, subscription: Stripe.Subscription) {
  await db
    .prepare("UPDATE subscription SET status = 'canceled', updated_at = CURRENT_TIMESTAMP WHERE stripe_subscription_id = ?")
    .bind(subscription.id)
    .run();
}

async function getUserIdFromCustomer(db: D1Database, customerId: string): Promise<string> {
  const user = await db
    .prepare("SELECT id FROM user WHERE stripe_customer_id = ?")
    .bind(customerId)
    .first();
  return user?.id as string;
}

function getPlanFromPriceId(priceId: string): string {
  // Map price IDs to plan names
  // You'd get these from env in real implementation
  const plans: Record<string, string> = {
    // Add your price ID mappings
  };
  return plans[priceId] || "pro";
}

export default webhook;
```

## Mount in Main App

```typescript
import { Hono } from "hono";
import webhook from "./routes/webhook";

const app = new Hono();

app.route("/api/webhooks", webhook);

export default app;
```

## Create Checkout Session

```typescript
import { Hono } from "hono";
import Stripe from "stripe";

const checkout = new Hono<{ Bindings: Env }>();

checkout.post("/create", async (c) => {
  const stripe = new Stripe(c.env.STRIPE_SECRET_KEY);
  const { priceId, userId } = await c.req.json();

  // Get or create customer
  const user = await c.env.DB
    .prepare("SELECT * FROM user WHERE id = ?")
    .bind(userId)
    .first();

  let customerId = user?.stripe_customer_id;

  if (!customerId) {
    const customer = await stripe.customers.create({
      email: user?.email,
      metadata: { userId },
    });
    customerId = customer.id;

    await c.env.DB
      .prepare("UPDATE user SET stripe_customer_id = ? WHERE id = ?")
      .bind(customerId, userId)
      .run();
  }

  // Create checkout session
  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: "subscription",
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${c.req.header("origin")}/dashboard?upgraded=true`,
    cancel_url: `${c.req.header("origin")}/pricing`,
  });

  return c.json({ url: session.url });
});

export default checkout;
```

## Webhook URL

When configuring in Stripe Dashboard, use:
```
https://your-app.workers.dev/api/webhooks/stripe
```

## Up-to-date References

For current Hono API, fetch: `https://hono.dev/llms.txt`
