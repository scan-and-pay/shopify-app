# Quick Reference: Secret Manager Migration

## Summary of Changes

All Firebase Cloud Functions have been migrated from `functions.config()` to Google Secret Manager using `defineSecret()`.

## Files Modified

| File | Changes | Status |
|------|---------|--------|
| `index.js` | Added secret definitions, exported secrets | ✅ Complete |
| `send_otp_email.js` | Mailgun secrets (API key, domain) | ✅ Complete |
| `global_payments_api.js` | Global Payments secrets (master key, base URL) | ✅ Complete |
| `shopify_webhooks.js` | Shopify API secret for HMAC verification | ✅ Complete |
| `basiq_api.js` | Basiq API key (disabled, ready for future) | ✅ Complete |

## Required Secrets

| Secret Name | Purpose | Used In |
|-------------|---------|---------|
| `MAILGUN_API_KEY` | Email delivery | send_otp_email.js |
| `MAILGUN_DOMAIN` | Email domain | send_otp_email.js |
| `GLOBALPAYMENTS_MASTER_KEY` | Payment processing auth | global_payments_api.js |
| `GLOBALPAYMENTS_BASE_URL` | Payment API endpoint | global_payments_api.js |
| `SHOPIFY_API_SECRET` | Webhook HMAC verification | shopify_webhooks.js |
| `BASIQ_API_KEY` | Bank connection (disabled) | basiq_api.js |
| `FIREBASE_PROJECT_ID` | Reserved for future use | - |
| `FIREBASE_API_KEY` | Reserved for future use | - |
| `FIREBASE_STORAGE_BUCKET` | Reserved for future use | - |
| `ENCRYPTION_KEY` | Reserved for future use | - |

## Quick Deploy

```bash
# 1. Verify secrets
node verify-secrets.js

# 2. Deploy
firebase deploy --only functions

# 3. Monitor
firebase functions:log
```

## Key Code Changes

### Before (functions.config())
```javascript
const config = functions.config();
const apiKey = config.mailgun.key;
```

### After (Secret Manager)
```javascript
const { defineSecret } = require('firebase-functions/params');
const MAILGUN_API_KEY = defineSecret('MAILGUN_API_KEY');

exports.myFunction = functions
  .runWith({ secrets: [MAILGUN_API_KEY] })
  .https.onCall(async (data, context) => {
    const apiKey = MAILGUN_API_KEY.value();
  });
```

## Flutter App Compatibility

✅ **No changes needed** - All API endpoints and response formats remain identical.

## Testing Checklist

- [ ] Email OTP (sendOtp, verifyOtp)
- [ ] Global Payments health check
- [ ] PayID QR generation
- [ ] Shopify webhooks
- [ ] Flutter app login flow
- [ ] Payment processing

## Common Commands

```bash
# Check deployed functions
firebase functions:list

# View logs
firebase functions:log

# View specific function logs
firebase functions:log --only sendOtp

# Create a secret
echo "VALUE" | gcloud secrets create SECRET_NAME --data-file=-

# List all secrets
gcloud secrets list

# Update a secret
echo "NEW_VALUE" | gcloud secrets versions add SECRET_NAME --data-file=-
```

## Troubleshooting Quick Fixes

| Error | Fix |
|-------|-----|
| Permission denied | `gcloud projects add-iam-policy-binding PROJECT_ID --member="serviceAccount:PROJECT_ID@appspot.gserviceaccount.com" --role="roles/secretmanager.secretAccessor"` |
| Secret not found | `echo "VALUE" \| gcloud secrets create SECRET_NAME --data-file=-` |
| Function timeout | Increase timeout in `runWith({ timeoutSeconds: 120 })` |

## Rollback

```bash
git checkout HEAD~1 functions/
firebase deploy --only functions
```

## Documentation Files

- `MIGRATION_SUMMARY.md` - Detailed migration overview
- `DEPLOYMENT_GUIDE.md` - Step-by-step deployment instructions
- `verify-secrets.js` - Secret verification script
- `QUICK_REFERENCE.md` - This file

---

**Ready to deploy?** Run `node verify-secrets.js` to get started!
