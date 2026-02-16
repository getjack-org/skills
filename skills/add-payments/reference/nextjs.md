# Next.js Example

This example shows Stripe integration with Next.js API routes.

## Dependencies

```bash
npm install stripe
```

## Webhook Handler (app/api/webhooks/stripe/route.ts)

```typescript
import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(request: NextRequest) {
  const body = await request.text();
  const signature = request.headers.get("stripe-signature");

  if (!signature) {
    return NextResponse.json({ error: "Missing signature" }, { status: 400 });
  }

  let event: Stripe.Event;

  try {
    // IMPORTANT: Use constructEventAsync for Cloudflare Workers deployment
    // The sync version fails with "SubtleCryptoProvider cannot be used in a synchronous context"
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error("Webhook verification failed:", err);
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      // Handle checkout complete
      // Update your database
      break;
    }

    case "customer.subscription.updated": {
      const subscription = event.data.object as Stripe.Subscription;
      // Update subscription in database
      break;
    }

    case "customer.subscription.deleted": {
      const subscription = event.data.object as Stripe.Subscription;
      // Mark subscription as canceled
      break;
    }
  }

  return NextResponse.json({ received: true });
}
```

## Create Checkout Session (app/api/checkout/route.ts)

```typescript
import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";
import { getServerSession } from "next-auth"; // or your auth library

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);

export async function POST(request: NextRequest) {
  const session = await getServerSession();

  if (!session?.user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { priceId } = await request.json();

  // Get or create Stripe customer
  // This depends on your database setup
  let customerId = await getCustomerIdForUser(session.user.id);

  if (!customerId) {
    const customer = await stripe.customers.create({
      email: session.user.email!,
      metadata: { userId: session.user.id },
    });
    customerId = customer.id;
    await saveCustomerIdForUser(session.user.id, customerId);
  }

  // Create checkout session
  const checkoutSession = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: "subscription",
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${request.nextUrl.origin}/dashboard?upgraded=true`,
    cancel_url: `${request.nextUrl.origin}/pricing`,
  });

  return NextResponse.json({ url: checkoutSession.url });
}
```

## Client Component

```tsx
"use client";

export function UpgradeButton({ priceId }: { priceId: string }) {
  const handleUpgrade = async () => {
    const response = await fetch("/api/checkout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ priceId }),
    });

    const { url } = await response.json();

    if (url) {
      window.location.href = url;
    }
  };

  return <button onClick={handleUpgrade}>Upgrade</button>;
}
```

## Environment Variables

```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRO_PRICE_ID=price_...
STRIPE_ENTERPRISE_PRICE_ID=price_...
```

## Notes for Jack Cloud

When deploying Next.js to Cloudflare Workers via Jack:

1. Use `@cloudflare/next-on-pages` or similar adapter
2. Secrets go in `.secrets.json` (Jack syncs them)
3. D1 database via Cloudflare bindings
4. **Use `constructEventAsync`** for webhook signature verification (required for Workers runtime)
5. Stripe timestamps are Unix seconds - multiply by 1000 for JavaScript Date:
   ```typescript
   const periodEnd = new Date(subscription.current_period_end * 1000).toISOString();
   ```

## Webhook URL

When configuring in Stripe Dashboard, use:
```
https://your-app.workers.dev/api/webhooks/stripe
```

## Up-to-date References

For current Next.js docs: `https://nextjs.org/docs`
