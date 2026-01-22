#!/bin/bash
# Verify Stripe payment setup is complete
# Stack-agnostic: checks secrets and attempts to verify webhook

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Verifying Stripe payment setup..."
echo ""

ERRORS=0

# Step 1: Check secrets
echo "━━━ Checking Secrets ━━━"
./scripts/check-secrets.sh || ERRORS=$((ERRORS + 1))

# Step 2: Check if deployed
echo ""
echo "━━━ Checking Deployment ━━━"

# Try to find deployed URL from wrangler or jack
DEPLOYED_URL=""

if [ -f ".jack.json" ]; then
  # Try to get URL from jack project info
  if command -v jack &> /dev/null; then
    DEPLOYED_URL=$(jack status 2>/dev/null | grep -o 'https://[^ ]*' | head -1)
  fi
fi

if [ -z "$DEPLOYED_URL" ]; then
  # Try wrangler
  if [ -f "wrangler.jsonc" ] || [ -f "wrangler.toml" ]; then
    # Extract name from config
    PROJECT_NAME=$(grep -o '"name": *"[^"]*"' wrangler.jsonc 2>/dev/null | cut -d'"' -f4)
    if [ -n "$PROJECT_NAME" ]; then
      DEPLOYED_URL="https://${PROJECT_NAME}.workers.dev"
      echo -e "${YELLOW}○${NC} Assuming URL: $DEPLOYED_URL"
    fi
  fi
fi

if [ -z "$DEPLOYED_URL" ]; then
  echo -e "${YELLOW}⚠${NC} Could not determine deployed URL"
  echo "  Run 'jack ship' to deploy, then run this script again"
else
  echo -e "${GREEN}✓${NC} Deployed URL: $DEPLOYED_URL"
fi

# Step 3: Test webhook endpoint (if URL known)
echo ""
echo "━━━ Checking Webhook Endpoint ━━━"

if [ -n "$DEPLOYED_URL" ]; then
  # Common webhook paths
  WEBHOOK_PATHS=(
    "/api/webhooks/stripe"
    "/api/auth/stripe/webhook"
    "/webhook"
    "/stripe/webhook"
  )

  WEBHOOK_FOUND=0
  for path in "${WEBHOOK_PATHS[@]}"; do
    URL="${DEPLOYED_URL}${path}"

    # Send a test request (Stripe sends POST)
    # We expect 400 (bad signature) not 404 (not found)
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$URL" -d '{}' -H "Content-Type: application/json" 2>/dev/null || echo "000")

    if [ "$STATUS" = "400" ] || [ "$STATUS" = "401" ]; then
      echo -e "${GREEN}✓${NC} Webhook endpoint found: $path"
      echo "  Status $STATUS = signature verification working (expected without valid signature)"
      WEBHOOK_FOUND=1
      break
    elif [ "$STATUS" = "200" ]; then
      echo -e "${YELLOW}⚠${NC} Webhook endpoint at $path returned 200"
      echo "  This might indicate signature verification is not enabled"
      WEBHOOK_FOUND=1
      break
    fi
  done

  if [ $WEBHOOK_FOUND -eq 0 ]; then
    echo -e "${YELLOW}⚠${NC} Could not verify webhook endpoint"
    echo "  Tried: ${WEBHOOK_PATHS[*]}"
    echo "  Ensure your webhook handler is deployed"
  fi
else
  echo -e "${YELLOW}○${NC} Skipping webhook check (no URL)"
fi

# Step 4: Check Stripe Dashboard
echo ""
echo "━━━ Manual Checks ━━━"
echo ""
echo "Verify in Stripe Dashboard:"
echo "  1. Webhook endpoint is configured"
echo "     https://dashboard.stripe.com/webhooks"
echo ""
echo "  2. Required events are selected:"
echo "     • checkout.session.completed"
echo "     • customer.subscription.created"
echo "     • customer.subscription.updated"
echo "     • customer.subscription.deleted"
echo ""
echo "  3. Test with card: 4242 4242 4242 4242"

echo ""
echo "━━━ Summary ━━━"

if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}Setup looks good!${NC}"
  echo "Complete manual checks above to confirm."
else
  echo -e "${RED}$ERRORS issue(s) found${NC}"
  echo "Fix issues above and run this script again."
  exit 1
fi
