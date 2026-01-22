-- D1 Schema for Stripe Subscriptions
-- Stack-agnostic: adapt column names to your ORM conventions

-- Subscription table
CREATE TABLE IF NOT EXISTS subscription (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  stripe_customer_id TEXT,
  stripe_subscription_id TEXT UNIQUE,
  stripe_price_id TEXT,
  plan TEXT NOT NULL DEFAULT 'free',
  status TEXT NOT NULL DEFAULT 'active',
  cancel_at_period_end INTEGER DEFAULT 0,
  current_period_start TEXT,
  current_period_end TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES user(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_subscription_user ON subscription(user_id);
CREATE INDEX IF NOT EXISTS idx_subscription_stripe ON subscription(stripe_subscription_id);
CREATE INDEX IF NOT EXISTS idx_subscription_status ON subscription(status);

-- Add stripe_customer_id to existing user table
-- Run this if user table already exists:
-- ALTER TABLE user ADD COLUMN stripe_customer_id TEXT;
-- CREATE INDEX IF NOT EXISTS idx_user_stripe ON user(stripe_customer_id);

-- Webhook events table (optional, for idempotency)
CREATE TABLE IF NOT EXISTS stripe_webhook_event (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_id TEXT UNIQUE NOT NULL,
  event_type TEXT NOT NULL,
  processed_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Status values:
-- 'active'     - Subscription is current and paid
-- 'trialing'   - In trial period
-- 'past_due'   - Payment failed, grace period
-- 'canceled'   - Subscription ended
-- 'incomplete' - Initial payment pending

-- Plan values (customize to your plans):
-- 'free'       - No active subscription
-- 'pro'        - Pro tier
-- 'enterprise' - Enterprise tier
