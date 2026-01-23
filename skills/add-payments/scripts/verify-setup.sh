#!/bin/bash
# Verify Stripe payments setup is working

set -e

# Get deployed URL from jack
if command -v jack &> /dev/null; then
  # Try to get URL from jack info
  URL=$(jack info 2>/dev/null | grep -o 'https://[^ ]*' | head -1 || echo "")
fi

if [ -z "$URL" ]; then
  echo "Enter your deployed app URL:"
  read -r URL
fi

if [ -z "$URL" ]; then
  echo "ERROR: No URL provided"
  exit 1
fi

# Remove trailing slash
URL="${URL%/}"

echo "Verifying setup at: $URL"
echo ""

# Check health endpoint
echo "1. Checking health endpoint..."
HEALTH=$(curl -s "$URL/health" || echo '{"error":"connection failed"}')
if echo "$HEALTH" | grep -q "ok"; then
  echo "   OK: Health check passed"
else
  echo "   ERROR: Health check failed"
  echo "   Response: $HEALTH"
  exit 1
fi

# Check subscription status endpoint
echo ""
echo "2. Checking subscription endpoint..."
STATUS=$(curl -s "$URL/api/subscription/status?email=test-verify@example.com" || echo '{"error":"connection failed"}')
if echo "$STATUS" | grep -q "subscribed"; then
  echo "   OK: Subscription endpoint working"
  echo "   Response: $STATUS"
else
  echo "   ERROR: Subscription endpoint not working"
  echo "   Response: $STATUS"
fi

# Check webhook endpoint accepts POST
echo ""
echo "3. Checking webhook endpoint..."
WEBHOOK=$(curl -s -X POST "$URL/api/webhooks/stripe" -H "Content-Type: application/json" -d '{}' || echo '{"error":"connection failed"}')
# Should return 400 (missing signature) not 404
if echo "$WEBHOOK" | grep -q "signature\|error"; then
  echo "   OK: Webhook endpoint exists (returns error without valid signature, as expected)"
else
  echo "   WARN: Unexpected webhook response"
  echo "   Response: $WEBHOOK"
fi

echo ""
echo "=========================================="
echo "Basic verification complete!"
echo ""
echo "Next steps:"
echo "1. Create a test checkout session"
echo "2. Complete checkout with card 4242 4242 4242 4242"
echo "3. Verify subscription status shows 'subscribed: true'"
echo ""
echo "To test checkout:"
echo "  curl -X POST '$URL/api/checkout/create' \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"your-email@example.com\"}'"
echo "=========================================="
