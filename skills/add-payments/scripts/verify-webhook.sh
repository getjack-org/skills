#!/bin/bash
# Verify Stripe webhook setup for Jack project

set -e

echo "🔍 Verifying Stripe webhook setup..."
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

ERRORS=0

# Check .secrets.json exists
if [ -f ".secrets.json" ]; then
  echo -e "${GREEN}✓${NC} .secrets.json exists"
else
  echo -e "${RED}✗${NC} .secrets.json not found"
  ERRORS=$((ERRORS + 1))
fi

# Check required secrets
check_secret() {
  local key=$1
  local prefix=$2

  if [ -f ".secrets.json" ]; then
    value=$(grep -o "\"$key\": *\"[^\"]*\"" .secrets.json 2>/dev/null | cut -d'"' -f4)
    if [ -n "$value" ]; then
      if [ -n "$prefix" ] && [[ ! "$value" == $prefix* ]]; then
        echo -e "${YELLOW}⚠${NC} $key exists but doesn't start with '$prefix'"
      else
        echo -e "${GREEN}✓${NC} $key is set"
      fi
    else
      echo -e "${RED}✗${NC} $key not found in .secrets.json"
      ERRORS=$((ERRORS + 1))
    fi
  fi
}

check_secret "STRIPE_SECRET_KEY" "sk_"
check_secret "STRIPE_WEBHOOK_SECRET" "whsec_"
check_secret "STRIPE_PRO_PRICE_ID" "price_"
check_secret "STRIPE_ENTERPRISE_PRICE_ID" "price_"

# Check .gitignore
if grep -q "\.secrets\.json" .gitignore 2>/dev/null; then
  echo -e "${GREEN}✓${NC} .secrets.json is gitignored"
else
  echo -e "${YELLOW}⚠${NC} .secrets.json might not be gitignored"
fi

# Check wrangler.jsonc for D1
if grep -q "d1_databases" wrangler.jsonc 2>/dev/null; then
  echo -e "${GREEN}✓${NC} D1 database configured"
else
  echo -e "${RED}✗${NC} D1 database not configured in wrangler.jsonc"
  ERRORS=$((ERRORS + 1))
fi

# Check for stripe package
if grep -q '"stripe"' package.json 2>/dev/null; then
  echo -e "${GREEN}✓${NC} stripe package installed"
else
  echo -e "${RED}✗${NC} stripe package not found in package.json"
  ERRORS=$((ERRORS + 1))
fi

# Check for webhook handler (common paths)
WEBHOOK_FOUND=0
for path in "src/index.ts" "src/index.js" "src/app.ts" "src/server.ts"; do
  if [ -f "$path" ]; then
    if grep -q "stripe" "$path" 2>/dev/null || grep -q "webhook" "$path" 2>/dev/null; then
      WEBHOOK_FOUND=1
      break
    fi
  fi
done

if [ $WEBHOOK_FOUND -eq 1 ]; then
  echo -e "${GREEN}✓${NC} Webhook handler appears to be configured"
else
  echo -e "${YELLOW}⚠${NC} Could not verify webhook handler (check manually)"
fi

echo ""

# Summary
if [ $ERRORS -eq 0 ]; then
  echo -e "${GREEN}All checks passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Deploy: jack ship"
  echo "2. Configure webhook in Stripe Dashboard"
  echo "3. Test with card 4242 4242 4242 4242"
else
  echo -e "${RED}$ERRORS check(s) failed${NC}"
  echo ""
  echo "Fix the issues above and run this script again."
  exit 1
fi
