#!/bin/bash
# Check if required Stripe secrets are configured

set -e

SECRETS_FILE=".secrets.json"

if [ ! -f "$SECRETS_FILE" ]; then
  echo "ERROR: $SECRETS_FILE not found"
  echo ""
  echo "Create it with:"
  echo '{'
  echo '  "STRIPE_SECRET_KEY": "sk_test_...",'
  echo '  "STRIPE_WEBHOOK_SECRET": "whsec_...",'
  echo '  "STRIPE_PRO_PRICE_ID": "price_..."'
  echo '}'
  exit 1
fi

# Check for jq
if ! command -v jq &> /dev/null; then
  echo "WARNING: jq not installed, using basic check"
  if grep -q "STRIPE_SECRET_KEY" "$SECRETS_FILE"; then
    echo "OK: STRIPE_SECRET_KEY found"
  else
    echo "ERROR: STRIPE_SECRET_KEY not found"
    exit 1
  fi
  exit 0
fi

# Use jq for proper JSON parsing
echo "Checking secrets in $SECRETS_FILE..."
echo ""

check_secret() {
  local key=$1
  local required=$2
  local value=$(jq -r ".$key // empty" "$SECRETS_FILE")

  if [ -z "$value" ]; then
    if [ "$required" = "required" ]; then
      echo "ERROR: $key - MISSING (required)"
      return 1
    else
      echo "WARN:  $key - not set (optional)"
      return 0
    fi
  elif [[ "$value" == *"..."* ]] || [[ "$value" == "sk_test_" ]] || [[ "$value" == "whsec_" ]]; then
    echo "ERROR: $key - placeholder value, needs real key"
    return 1
  else
    # Show first/last few chars for verification
    local preview="${value:0:10}...${value: -4}"
    echo "OK:    $key - $preview"
    return 0
  fi
}

errors=0

check_secret "STRIPE_SECRET_KEY" "required" || ((errors++))
check_secret "STRIPE_WEBHOOK_SECRET" "required" || ((errors++))
check_secret "STRIPE_PRO_PRICE_ID" "optional"
check_secret "STRIPE_ENTERPRISE_PRICE_ID" "optional"

echo ""

if [ $errors -gt 0 ]; then
  echo "Found $errors error(s). Fix before deploying."
  exit 1
else
  echo "All required secrets configured!"
fi
