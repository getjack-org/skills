#!/bin/bash
# Create Stripe products and prices programmatically
# Mimics the stripe-setup hook action from jack templates

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔧 Setting up Stripe products and prices..."
echo ""

# Check for Stripe key
if [ -f ".secrets.json" ]; then
  STRIPE_KEY=$(grep -o '"STRIPE_SECRET_KEY": *"[^"]*"' .secrets.json 2>/dev/null | cut -d'"' -f4)
fi

if [ -z "$STRIPE_KEY" ]; then
  echo -e "${RED}✗${NC} STRIPE_SECRET_KEY not found in .secrets.json"
  echo ""
  echo "Add your Stripe key first:"
  echo '  {"STRIPE_SECRET_KEY": "sk_test_..."}'
  exit 1
fi

# Check if stripe CLI is available, otherwise use curl
if command -v stripe &> /dev/null; then
  USE_CLI=true
  echo "Using Stripe CLI..."
else
  USE_CLI=false
  echo "Using Stripe API directly..."
fi

create_product_and_price() {
  local name=$1
  local amount=$2
  local interval=$3
  local secret_key=$4

  echo ""
  echo "Creating $name plan ($amount cents/$interval)..."

  if [ "$USE_CLI" = true ]; then
    # Use Stripe CLI
    PRODUCT_ID=$(stripe products create \
      --name="$name" \
      --api-key="$STRIPE_KEY" \
      --format=json 2>/dev/null | grep -o '"id": *"[^"]*"' | head -1 | cut -d'"' -f4)

    PRICE_ID=$(stripe prices create \
      --product="$PRODUCT_ID" \
      --unit-amount="$amount" \
      --currency=usd \
      --recurring-interval="$interval" \
      --api-key="$STRIPE_KEY" \
      --format=json 2>/dev/null | grep -o '"id": *"[^"]*"' | head -1 | cut -d'"' -f4)
  else
    # Use curl
    PRODUCT_RESPONSE=$(curl -s -X POST https://api.stripe.com/v1/products \
      -u "$STRIPE_KEY:" \
      -d "name=$name")

    PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | grep -o '"id": *"prod_[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$PRODUCT_ID" ]; then
      echo -e "${RED}✗${NC} Failed to create product: $name"
      echo "$PRODUCT_RESPONSE"
      return 1
    fi

    PRICE_RESPONSE=$(curl -s -X POST https://api.stripe.com/v1/prices \
      -u "$STRIPE_KEY:" \
      -d "product=$PRODUCT_ID" \
      -d "unit_amount=$amount" \
      -d "currency=usd" \
      -d "recurring[interval]=$interval")

    PRICE_ID=$(echo "$PRICE_RESPONSE" | grep -o '"id": *"price_[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -z "$PRICE_ID" ]; then
      echo -e "${RED}✗${NC} Failed to create price for: $name"
      echo "$PRICE_RESPONSE"
      return 1
    fi
  fi

  echo -e "${GREEN}✓${NC} Created $name: $PRICE_ID"
  echo "$PRICE_ID"
}

# Create Pro plan
PRO_PRICE=$(create_product_and_price "Pro" 1900 "month" "$STRIPE_KEY")

# Create Enterprise plan
ENTERPRISE_PRICE=$(create_product_and_price "Enterprise" 9900 "month" "$STRIPE_KEY")

# Extract just the price IDs (last line of each output)
PRO_PRICE_ID=$(echo "$PRO_PRICE" | tail -1)
ENTERPRISE_PRICE_ID=$(echo "$ENTERPRISE_PRICE" | tail -1)

echo ""
echo "━━━ Updating .secrets.json ━━━"

# Update .secrets.json with price IDs
if [ -f ".secrets.json" ]; then
  # Use node/bun if available for proper JSON manipulation
  if command -v node &> /dev/null; then
    node -e "
      const fs = require('fs');
      const secrets = JSON.parse(fs.readFileSync('.secrets.json', 'utf8'));
      secrets.STRIPE_PRO_PRICE_ID = '$PRO_PRICE_ID';
      secrets.STRIPE_ENTERPRISE_PRICE_ID = '$ENTERPRISE_PRICE_ID';
      fs.writeFileSync('.secrets.json', JSON.stringify(secrets, null, 2));
    "
  elif command -v bun &> /dev/null; then
    bun -e "
      const secrets = JSON.parse(Bun.file('.secrets.json').text());
      secrets.STRIPE_PRO_PRICE_ID = '$PRO_PRICE_ID';
      secrets.STRIPE_ENTERPRISE_PRICE_ID = '$ENTERPRISE_PRICE_ID';
      Bun.write('.secrets.json', JSON.stringify(secrets, null, 2));
    "
  else
    echo -e "${YELLOW}⚠${NC} Could not auto-update .secrets.json"
    echo ""
    echo "Add these manually:"
    echo "  STRIPE_PRO_PRICE_ID: $PRO_PRICE_ID"
    echo "  STRIPE_ENTERPRISE_PRICE_ID: $ENTERPRISE_PRICE_ID"
    exit 0
  fi

  echo -e "${GREEN}✓${NC} Updated .secrets.json with price IDs"
fi

echo ""
echo "━━━ Done! ━━━"
echo ""
echo "Price IDs saved to .secrets.json:"
echo "  STRIPE_PRO_PRICE_ID: $PRO_PRICE_ID"
echo "  STRIPE_ENTERPRISE_PRICE_ID: $ENTERPRISE_PRICE_ID"
echo ""
echo "Next: Deploy with 'jack ship'"
