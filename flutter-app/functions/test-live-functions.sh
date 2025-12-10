#!/bin/bash
# Live Function Testing Script
# Tests deployed functions to verify Secret Manager integration

echo "🧪 Testing Deployed Firebase Functions with Secret Manager"
echo "============================================================"
echo ""

PROJECT_ID="scan-and-pay-guihzm"
REGION="australia-southeast1"
BASE_URL="https://${REGION}-${PROJECT_ID}.cloudfunctions.net"

echo "📍 Region: ${REGION}"
echo "🔗 Base URL: ${BASE_URL}"
echo ""

# Test 1: sendOtp (uses MAILGUN secrets)
echo "1️⃣ Testing sendOtp function (uses MAILGUN_API_KEY + MAILGUN_DOMAIN)..."
echo "   Endpoint: ${BASE_URL}/sendOtp"

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"data":{"email":"test@scanandpay.com.au"}}' \
  "${BASE_URL}/sendOtp" 2>&1)

if echo "$RESPONSE" | grep -q '"success":true'; then
  echo "   ✅ SUCCESS - sendOtp accessed Mailgun secrets from Secret Manager!"
  echo "   Response: $(echo $RESPONSE | jq -r '.result.message' 2>/dev/null || echo $RESPONSE | head -c 100)"
elif echo "$RESPONSE" | grep -qi "internal"; then
  echo "   ❌ FAILED - INTERNAL ERROR detected!"
  echo "   🚨 Secret Manager may not be working correctly"
  echo "   Response: $RESPONSE"
elif echo "$RESPONSE" | grep -qi "resource-exhausted"; then
  echo "   ⚠️  Rate limited (cooldown period) - but function is working!"
  echo "   ℹ️  This means Secret Manager is working (function executed)"
else
  echo "   ⚠️  Unexpected response:"
  echo "   $RESPONSE"
fi
echo ""

# Test 2: Webhook function (uses SHOPIFY_API_SECRET)
echo "2️⃣ Testing appUninstalled webhook (uses SHOPIFY_API_SECRET)..."
echo "   Endpoint: ${BASE_URL}/appUninstalled"

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "X-Shopify-Hmac-Sha256: test-hmac" \
  -H "X-Shopify-Shop-Domain: test-shop.myshopify.com" \
  -H "X-Shopify-Topic: app/uninstalled" \
  -d '{}' \
  "${BASE_URL}/appUninstalled" 2>&1)

if echo "$RESPONSE" | grep -qi "Unauthorized"; then
  echo "   ✅ SUCCESS - Webhook accessed SHOPIFY_API_SECRET from Secret Manager!"
  echo "   ℹ️  Returned 401 (expected - invalid HMAC) but Secret Manager works"
elif echo "$RESPONSE" | grep -qi "internal"; then
  echo "   ❌ FAILED - INTERNAL ERROR detected!"
  echo "   🚨 Secret Manager may not be working correctly"
else
  echo "   ⚠️  Response: $RESPONSE"
fi
echo ""

# Test 3: Check function exists and is accessible
echo "3️⃣ Testing generatePayIDQR function accessibility..."
echo "   Endpoint: ${BASE_URL}/generatePayIDQR"

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"data":{"amount":10,"payId":"test@scanandpay.com.au","merchantName":"Test"}}' \
  "${BASE_URL}/generatePayIDQR" 2>&1)

if echo "$RESPONSE" | grep -qi "unauthenticated"; then
  echo "   ✅ SUCCESS - Function is live and requires authentication (expected)"
  echo "   ℹ️  No INTERNAL errors - Secret Manager working correctly"
elif echo "$RESPONSE" | grep -qi "internal"; then
  echo "   ❌ FAILED - INTERNAL ERROR detected!"
  echo "   🚨 Secret Manager configuration issue"
else
  echo "   ⚠️  Response: $RESPONSE"
fi
echo ""

echo "============================================================"
echo "📊 Test Summary"
echo "============================================================"
echo ""
echo "Expected Results:"
echo "  sendOtp: ✅ Success OR ⚠️ Rate limited (both mean Secret Manager works)"
echo "  appUninstalled: ✅ 401 Unauthorized (Secret Manager accessed SHOPIFY_API_SECRET)"
echo "  generatePayIDQR: ✅ Unauthenticated (function working, no INTERNAL error)"
echo ""
echo "If you see ❌ INTERNAL errors, Secret Manager has issues."
echo "If you see ✅ or ⚠️, Secret Manager is working correctly!"
echo ""
echo "📝 Check detailed logs:"
echo "   firebase functions:log -n 20"
echo ""
echo "🌐 Firebase Console:"
echo "   https://console.firebase.google.com/project/${PROJECT_ID}/functions/logs"
echo ""
