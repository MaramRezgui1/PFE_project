#!/bin/bash
set -e

echo "🎭 Playwright E2E Test Runner"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "BASE_URL: ${BASE_URL}"
echo ""

# Wait for the service to be reachable (max 120 seconds)
echo "⏳ Waiting for service to be reachable at ${BASE_URL}..."
RETRIES=0
MAX_RETRIES=40
until curl -sf --max-time 3 "${BASE_URL}" > /dev/null 2>&1; do
  RETRIES=$((RETRIES + 1))
  if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
    echo "❌ Service at ${BASE_URL} did not become reachable after $((MAX_RETRIES * 3)) seconds"
    echo "Attempting to get more info..."
    curl -v "${BASE_URL}" 2>&1 || true
    exit 1
  fi
  echo "  Attempt ${RETRIES}/${MAX_RETRIES} - service not ready, retrying in 3s..."
  sleep 3
done

echo "✅ Service is reachable!"
echo ""

# Verify the page returns HTML content
echo "🔍 Verifying service returns valid HTML..."
RESPONSE=$(curl -s --max-time 10 "${BASE_URL}")
if echo "$RESPONSE" | grep -q "<html"; then
  echo "✅ Service returns valid HTML"
else
  echo "⚠️  Service response doesn't contain HTML. Response preview:"
  echo "$RESPONSE" | head -5
fi
echo ""

# Run Playwright tests
echo "🎭 Running Playwright tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
npx playwright test --project=chromium

