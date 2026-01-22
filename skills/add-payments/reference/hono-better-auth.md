# Hono + Better Auth Example

This is a reference implementation for the common Jack stack. Adapt for your framework.

## Dependencies

```bash
bun add stripe @better-auth/stripe better-auth kysely kysely-d1
```

## Auth Configuration (src/auth.ts)

```typescript
import { betterAuth } from "better-auth";
import { stripe } from "@better-auth/stripe";
import Stripe from "stripe";
import { Kysely } from "kysely";
import { D1Dialect } from "kysely-d1";

type Env = {
  DB: D1Database;
  BETTER_AUTH_SECRET: string;
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET?: string;
  STRIPE_PRO_PRICE_ID?: string;
  STRIPE_ENTERPRISE_PRICE_ID?: string;
};

export function createAuth(env: Env) {
  const stripeClient = env.STRIPE_SECRET_KEY
    ? new Stripe(env.STRIPE_SECRET_KEY)
    : null;

  const plugins = [];

  if (env.STRIPE_SECRET_KEY && stripeClient) {
    if (!env.STRIPE_WEBHOOK_SECRET) {
      console.error("[Stripe] Plugin disabled - STRIPE_WEBHOOK_SECRET required");
    } else {
      plugins.push(
        stripe({
          stripeClient,
          stripeWebhookSecret: env.STRIPE_WEBHOOK_SECRET,
          createCustomerOnSignUp: true,
          subscription: {
            enabled: true,
            plans: [
              { name: "pro", priceId: env.STRIPE_PRO_PRICE_ID || "" },
              { name: "enterprise", priceId: env.STRIPE_ENTERPRISE_PRICE_ID || "" },
            ],
          },
        })
      );
    }
  }

  const db = new Kysely<any>({
    dialect: new D1Dialect({ database: env.DB }),
  });

  return betterAuth({
    database: { db, type: "sqlite" },
    emailAndPassword: { enabled: true },
    secret: env.BETTER_AUTH_SECRET,
    plugins,
  });
}
```

## Routes (src/index.ts)

```typescript
import { Hono } from "hono";
import { cors } from "hono/cors";
import { createAuth } from "./auth";

type Env = {
  DB: D1Database;
  BETTER_AUTH_SECRET: string;
  STRIPE_SECRET_KEY: string;
  STRIPE_WEBHOOK_SECRET?: string;
  STRIPE_PRO_PRICE_ID?: string;
  STRIPE_ENTERPRISE_PRICE_ID?: string;
};

const app = new Hono<{ Bindings: Env }>();

// CORS for API routes
app.use("/api/*", cors());

// Better Auth handles:
// - /api/auth/signup, signin, signout
// - /api/auth/stripe/webhook (automatic)
// - /api/auth/subscription/*
app.on(["GET", "POST"], "/api/auth/*", (c) => {
  const auth = createAuth(c.env);
  return auth.handler(c.req.raw);
});

// Health check
app.get("/api/health", (c) => {
  return c.json({ status: "ok" });
});

export default app;
```

## Client (src/client/lib/auth-client.ts)

```typescript
import { createAuthClient } from "better-auth/react";
import { stripeClient } from "@better-auth/stripe/client";

export const authClient = createAuthClient({
  baseURL: window.location.origin,
  plugins: [stripeClient({ subscription: true })],
});

export const { signIn, signUp, signOut, useSession } = authClient;
```

## Subscription Hook (src/client/hooks/useSubscription.ts)

```typescript
import { useState, useEffect } from "react";
import { authClient } from "../lib/auth-client";

type Subscription = {
  id: string;
  plan: string;
  status: string;
  cancelAtPeriodEnd?: boolean;
  cancelAt?: Date | string | null;
  periodEnd?: Date | string | null;
};

export function useSubscription() {
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    authClient.subscription.list()
      .then((result) => {
        if ("data" in result && result.data) {
          setSubscriptions(result.data as Subscription[]);
        }
      })
      .catch((err) => setError(err as Error))
      .finally(() => setIsLoading(false));
  }, []);

  const activeSubscription = subscriptions.find(
    (s) => s.status === "active" || s.status === "trialing"
  );

  const isCancelling =
    activeSubscription?.cancelAtPeriodEnd ||
    !!activeSubscription?.cancelAt ||
    false;

  return {
    subscriptions,
    activeSubscription: activeSubscription ?? null,
    plan: activeSubscription?.plan ?? "free",
    isSubscribed: !!activeSubscription,
    isCancelling,
    periodEnd: activeSubscription?.periodEnd
      ? String(activeSubscription.periodEnd)
      : null,
    isLoading,
    error,
    upgrade: (plan: "pro" | "enterprise") =>
      authClient.subscription.upgrade({
        plan,
        successUrl: `${window.location.origin}/dashboard?upgraded=true`,
        cancelUrl: `${window.location.origin}/pricing`,
      }),
  };
}
```

## Plans Config (src/client/lib/plans.ts)

```typescript
export type PlanId = "free" | "pro" | "enterprise";

export interface PlanConfig {
  id: PlanId;
  name: string;
  price: string;
  priceMonthly: number;
  description: string;
  features: string[];
  highlighted?: boolean;
}

export const plans: PlanConfig[] = [
  {
    id: "free",
    name: "Free",
    price: "$0",
    priceMonthly: 0,
    description: "Perfect for getting started",
    features: ["Basic features", "Community support"],
  },
  {
    id: "pro",
    name: "Pro",
    price: "$19",
    priceMonthly: 19,
    description: "For growing businesses",
    features: ["All Free features", "Priority support", "Advanced analytics"],
    highlighted: true,
  },
  {
    id: "enterprise",
    name: "Enterprise",
    price: "$99",
    priceMonthly: 99,
    description: "For large organizations",
    features: ["All Pro features", "Dedicated support", "Custom integrations"],
  },
];

export function getPlan(id: PlanId | string): PlanConfig | undefined {
  return plans.find((p) => p.id === id);
}

export function isPaidPlan(id: PlanId | string): boolean {
  const plan = getPlan(id);
  return plan ? plan.priceMonthly > 0 : false;
}
```

## Upgrade Button Component

```tsx
import { useSubscription } from "../hooks/useSubscription";

export function UpgradeButton({ plan }: { plan: "pro" | "enterprise" }) {
  const { upgrade, isLoading } = useSubscription();

  const handleUpgrade = async () => {
    const result = await upgrade(plan);
    if (result.data?.url) {
      window.location.href = result.data.url;
    }
  };

  return (
    <button onClick={handleUpgrade} disabled={isLoading}>
      Upgrade to {plan}
    </button>
  );
}
```

## Notes

- Better Auth creates tables automatically on first request
- Webhook is handled at `/api/auth/stripe/webhook`
- Customer is created automatically on signup
- Subscription state syncs via webhooks

## Up-to-date References

For current Hono API, fetch: `https://hono.dev/llms.txt`

For other frameworks (Express, Next.js), adapt the patterns but keep the same flow.
