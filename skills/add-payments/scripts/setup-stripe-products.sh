#!/bin/bash
# Create Stripe products and prices
# Requires: STRIPE_SECRET_KEY in .secrets.json or environment

set -e

# Get Stripe key
if [ -n "$STRIPE_SECRET_KEY" ]; then
  KEY="$STRIPE_SECRET_KEY"
elif [ -f ".secrets.json" ]; then
  if command -v jq &> /dev/null; then
    KEY=$(jq -r '.STRIPE_SECRET_KEY' .secrets.json)
  else
    echo "ERROR: jq not installed. Install with: brew install jq"
    exit 1
  fi
else
  echo "ERROR: No Stripe key found"
  echo "Set STRIPE_SECRET_KEY or add to .secrets.json"
  exit 1
fi

if [ -z "$KEY" ] || [ "$KEY" = "null" ]; then
  echo "ERROR: STRIPE_SECRET_KEY is empty"
  exit 1
fi

echo "Creating Stripe products..."
echo ""

# Create Pro product
echo "Creating Pro Plan product..."
PRO_PRODUCT=$(curl -s -X POST https://api.stripe.com/v1/products \
  -u "$KEY:" \
  -d "name=Pro Plan" \
  -d "description=Pro subscription plan")

PRO_PRODUCT_ID=$(echo "$PRO_PRODUCT" | jq -r '.id')

if [ "$PRO_PRODUCT_ID" = "null" ] || [ -z "$PRO_PRODUCT_ID" ]; then
  echo "ERROR: Failed to create Pro product"
  echo "$PRO_PRODUCT" | jq .
  exit 1
fi

echo "Created product: $PRO_PRODUCT_ID"

# Create Pro price ($19/month)
echo "Creating Pro Plan price ($19/month)..."
PRO_PRICE=$(curl -s -X POST https://api.stripe.com/v1/prices \
  -u "$KEY:" \
  -d "product=$PRO_PRODUCT_ID" \
  -d "unit_amount=1900" \
  -d "currency=usd" \
  -d "recurring[interval]=month")

PRO_PRICE_ID=$(echo "$PRO_PRICE" | jq -r '.id')

if [ "$PRO_PRICE_ID" = "null" ] || [ -z "$PRO_PRICE_ID" ]; then
  echo "ERROR: Failed to create Pro price"
  echo "$PRO_PRICE" | jq .
  exit 1
fi

echo "Created price: $PRO_PRICE_ID"
echo ""

# Create Enterprise product
echo "Creating Enterprise Plan product..."
ENT_PRODUCT=$(curl -s -X POST https://api.stripe.com/v1/products \
  -u "$KEY:" \
  -d "name=Enterprise Plan" \
  -d "description=Enterprise subscription plan")

ENT_PRODUCT_ID=$(echo "$ENT_PRODUCT" | jq -r '.id')

if [ "$ENT_PRODUCT_ID" = "null" ] || [ -z "$ENT_PRODUCT_ID" ]; then
  echo "ERROR: Failed to create Enterprise product"
  echo "$ENT_PRODUCT" | jq .
  exit 1
fi

echo "Created product: $ENT_PRODUCT_ID"

# Create Enterprise price ($99/month)
echo "Creating Enterprise Plan price ($99/month)..."
ENT_PRICE=$(curl -s -X POST https://api.stripe.com/v1/prices \
  -u "$KEY:" \
  -d "product=$ENT_PRODUCT_ID" \
  -d "unit_amount=9900" \
  -d "currency=usd" \
  -d "recurring[interval]=month")

ENT_PRICE_ID=$(echo "$ENT_PRICE" | jq -r '.id')

if [ "$ENT_PRICE_ID" = "null" ] || [ -z "$ENT_PRICE_ID" ]; then
  echo "ERROR: Failed to create Enterprise price"
  echo "$ENT_PRICE" | jq .
  exit 1
fi

echo "Created price: $ENT_PRICE_ID"
echo ""

# Summary
echo "=========================================="
echo "Products created successfully!"
echo ""
echo "Add to .secrets.json:"
echo ""
echo "  \"STRIPE_PRO_PRICE_ID\": \"$PRO_PRICE_ID\","
echo "  \"STRIPE_ENTERPRISE_PRICE_ID\": \"$ENT_PRICE_ID\""
echo ""
echo "=========================================="

# Update .secrets.json if jq is available
if [ -f ".secrets.json" ] && command -v jq &> /dev/null; then
  echo ""
  read -p "Update .secrets.json automatically? (y/n) " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    jq ".STRIPE_PRO_PRICE_ID = \"$PRO_PRICE_ID\" | .STRIPE_ENTERPRISE_PRICE_ID = \"$ENT_PRICE_ID\"" .secrets.json > .secrets.json.tmp
    mv .secrets.json.tmp .secrets.json
    echo "Updated .secrets.json"
  fi
fi
