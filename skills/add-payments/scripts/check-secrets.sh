#!/bin/bash
# Check that required Stripe secrets are configured
# Stack-agnostic: only checks secrets exist, not implementation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔍 Checking Stripe secrets..."
echo ""

ERRORS=0
WARNINGS=0

check_secret() {
  local key=$1
  local prefix=$2
  local required=$3

  if [ -f ".secrets.json" ]; then
    value=$(grep -o "\"$key\": *\"[^\"]*\"" .secrets.json 2>/dev/null | cut -d'"' -f4)
    if [ -n "$value" ]; then
      if [ -n "$prefix" ] && [[ ! "$value" == $prefix* ]]; then
        echo -e "${YELLOW}⚠${NC} $key exists but doesn't start with '$prefix'"
        WARNINGS=$((WARNINGS + 1))
      else
        # Mask the value for display
        masked="${value:0:10}..."
        echo -e "${GREEN}✓${NC} $key: $masked"
      fi
    else
      if [ "$required" = "required" ]; then
        echo -e "${RED}✗${NC} $key: not found (required)"
        ERRORS=$((ERRORS + 1))
      else
        echo -e "${YELLOW}○${NC} $key: not found (optional)"
      fi
    fi
  else
    echo -e "${RED}✗${NC} .secrets.json not found"
    ERRORS=$((ERRORS + 1))
  fi
}

# Check each secret
check_secret "STRIPE_SECRET_KEY" "sk_" "required"
check_secret "STRIPE_WEBHOOK_SECRET" "whsec_" "required"
check_secret "STRIPE_PRO_PRICE_ID" "price_" "optional"
check_secret "STRIPE_ENTERPRISE_PRICE_ID" "price_" "optional"

# Check gitignore
echo ""
if grep -q "\.secrets\.json" .gitignore 2>/dev/null; then
  echo -e "${GREEN}✓${NC} .secrets.json is gitignored"
else
  echo -e "${YELLOW}⚠${NC} .secrets.json may not be gitignored"
  WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo "━━━ Summary ━━━"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}All secrets configured correctly!${NC}"
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}$WARNINGS warning(s), but can proceed${NC}"
  exit 0
else
  echo -e "${RED}$ERRORS required secret(s) missing${NC}"
  echo ""
  echo "Add missing secrets to .secrets.json:"
  echo '{'
  echo '  "STRIPE_SECRET_KEY": "sk_test_...",'
  echo '  "STRIPE_WEBHOOK_SECRET": "whsec_..."'
  echo '}'
  exit 1
fi
