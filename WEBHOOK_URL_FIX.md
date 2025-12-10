# Webhook URL Configuration Fix

## Problem Discovered

After fixing the HMAC verification code, the Shopify automated check "Verifies webhooks with HMAC signatures" was **still failing** because of incorrect webhook URL configuration in `shopify.app.toml`.

## Root Cause

The `shopify.app.toml` file had **all compliance webhooks pointing to a single generic path** that doesn't exist:

```toml
# ❌ WRONG - This was causing 404/405 errors
[[webhooks.subscriptions]]
compliance_topics = ["customers/data_request", "customers/redact", "shop/redact"]
uri = "/webhooks"
```

Shopify's automated check was trying to call:
- ❌ `https://merchants.scanandpay.com.au/webhooks` → **405 Method Not Allowed**

But the actual endpoints are:
- ✅ `https://merchants.scanandpay.com.au/webhooks/customers/data_request`
- ✅ `https://merchants.scanandpay.com.au/webhooks/customers/redact`
- ✅ `https://merchants.scanandpay.com.au/webhooks/shop/redact`

## Solution

Changed `shopify.app.toml` to specify **individual URIs for each compliance topic**:

```toml
# ✅ CORRECT - Each webhook has its own specific path
[[webhooks.subscriptions]]
topics = [ "app/uninstalled" ]
uri = "/webhooks/app/uninstalled"

[[webhooks.subscriptions]]
compliance_topics = ["customers/data_request"]
uri = "/webhooks/customers/data_request"

[[webhooks.subscriptions]]
compliance_topics = ["customers/redact"]
uri = "/webhooks/customers/redact"

[[webhooks.subscriptions]]
compliance_topics = ["shop/redact"]
uri = "/webhooks/shop/redact"
```

## Verification

### Before Fix
```bash
curl -X POST https://merchants.scanandpay.com.au/webhooks
# Result: 405 Method Not Allowed ❌
```

### After Fix
```bash
# All compliance endpoints now work correctly
curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/data_request
# Result: 401 Unauthorized (expected - invalid HMAC) ✅

curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/redact
# Result: 401 Unauthorized (expected - invalid HMAC) ✅

curl -X POST https://merchants.scanandpay.com.au/webhooks/shop/redact
# Result: 401 Unauthorized (expected - invalid HMAC) ✅
```

### With Valid HMAC (using test script)
```powershell
.\test-webhook-with-valid-hmac.ps1
# Result: 200 OK ✅
```

## Files Changed

1. **shopify-app/scan-pay/shopify.app.toml**
   - Split single compliance webhook into 3 separate subscriptions
   - Each subscription now has the correct URI path

## Deployment

- **Shopify App Version**: scan-pay-16
- **Deployed**: 2025-12-10
- **Git Commit**: 34ce82b
- **Branch**: webhook-shopify

## Expected Result

Now when Shopify runs its automated check, it will:

1. ✅ Call the correct endpoint URLs (not `/webhooks`)
2. ✅ Send a test webhook with valid HMAC signature
3. ✅ Receive `200 OK` response
4. ✅ **Mark "Verifies webhooks with HMAC signatures" as PASSED**

## Webhook Configuration Summary

| Topic | URI | Method | Expected Response |
|-------|-----|--------|-------------------|
| `app/uninstalled` | `/webhooks/app/uninstalled` | POST | 200 OK (valid HMAC) / 401 (invalid) |
| `customers/data_request` | `/webhooks/customers/data_request` | POST | 200 OK (valid HMAC) / 401 (invalid) |
| `customers/redact` | `/webhooks/customers/redact` | POST | 200 OK (valid HMAC) / 401 (invalid) |
| `shop/redact` | `/webhooks/shop/redact` | POST | 200 OK (valid HMAC) / 401 (invalid) |

All endpoints:
- ✅ Verify HMAC signature
- ✅ Return 401 for invalid HMAC
- ✅ Return 200 OK for valid HMAC
- ✅ Process webhook asynchronously after returning 200

## Testing

To verify the fix works:

```powershell
# 1. Get your SHOPIFY_API_SECRET
firebase functions:secrets:access SHOPIFY_API_SECRET --project scan-and-pay-guihzm

# 2. Run test script
cd C:\dev
.\test-webhook-with-valid-hmac.ps1

# Expected: 200 OK ✅
```

## Next Steps

1. ✅ Fixed HMAC verification code (returns 200 immediately)
2. ✅ Fixed webhook URL configuration (correct paths)
3. ✅ Deployed Shopify app (scan-pay-16)
4. ⏳ Wait for Shopify to re-run automated checks (or trigger manually)
5. ⏳ Verify green checkmark in Partner Dashboard

---

**Status**: Ready for Shopify automated check to run ✅

**Note**: The automated check may take a few minutes to recognize the new app version and re-test. Check the Partner Dashboard in 5-10 minutes.
