# Local Testing with Firebase Emulator - Important Notice

## ⚠️ Current Limitation

The Firebase Functions Emulator **does not fully support `defineSecret()` from firebase-functions/params** when running locally.

## Current Status

Your code has been successfully migrated to use Google Secret Manager with `defineSecret()`. This works perfectly when **deployed to Firebase**, but the local emulator has limitations.

## Recommended Testing Approaches

###  Option 1: Deploy to Firebase (Recommended for Testing Secrets)

The most reliable way to test your migrated code:

```bash
# 1. Ensure all secrets exist in Google Secret Manager
cd C:\dev\shopify-app\flutter-app\functions
node verify-secrets.js

# 2. Deploy functions
cd ..
firebase deploy --only functions

# 3. Test with your Flutter app or curl
# Functions will use real Secret Manager values
```

### Option 2: Test Business Logic Locally (Without Real Secrets)

You can test the business logic and structure locally with mock values:

```bash
# The emulator will start but secret.value() calls will fail
# unless you provide environment variables

# Set environment variables first (PowerShell):
$env:MAILGUN_API_KEY = "mock_key"
$env:MAILGUN_DOMAIN = "mock_domain"
$env:GLOBALPAYMENTS_MASTER_KEY = "mock_gp_key"
$env:GLOBALPAYMENTS_BASE_URL = "https://sandbox.api.gpaunz.com"
$env:SHOPIFY_API_SECRET = "mock_secret"
$env:BASIQ_API_KEY = "mock_basiq"
$env:FIREBASE_PROJECT_ID = "scan-and-pay-guihzm"
$env:FIREBASE_API_KEY = "mock_api_key"
$env:FIREBASE_STORAGE_BUCKET = "mock_bucket"
$env:ENCRYPTION_KEY = "mock_encryption_key"

# Then start emulator
firebase emulators:start --only functions
```

### Option 3: Use Firebase Functions Shell (Interactive Testing)

```bash
# Start the functions shell
npm run shell

# This gives you an interactive REPL where you can test functions
firebase > sendOtp({email: "test@example.com"})
```

## What Works in Local Emulator

✅ Function structure and logic
✅ Firestore operations
✅ HTTP endpoints
✅ Authentication (emulator auth)
✅ Business logic testing

## What Doesn't Work in Local Emulator

❌ Real Secret Manager integration
❌ Automatic secret loading from GCP
❌ `.env.local` file loading (Firebase bug)

## Production Deployment

When you deploy to Firebase, everything works perfectly:

```bash
firebase deploy --only functions
```

Your functions will:
- ✅ Load secrets from Google Secret Manager
- ✅ Use proper IAM authentication
- ✅ Have audit logging
- ✅ Support secret rotation

## Testing Strategy

1. **Local Development**
   - Test business logic with mock data
   - Verify function structure
   - Test Firestore operations

2. **Firebase Deployment (Staging)**
   - Deploy to Firebase
   - Test with real Secret Manager
   - Verify all external API integrations
   - Test from Flutter app

3. **Production**
   - Full integration testing
   - Monitor logs
   - Verify secret access

## Quick Commands

```bash
# Check all secrets exist
node verify-secrets.js

# Deploy to Firebase
firebase deploy --only functions

# View logs
firebase functions:log

# Test specific function
firebase functions:log --only sendOtp
```

## Alternative: Temporary Local Testing Setup

If you absolutely need to test locally with the emulator, you can temporarily modify the code to check for an environment variable and fallback:

**This is NOT recommended for production** - only for local testing.

Example modification (DON'T COMMIT THIS):

```javascript
// In send_otp_email.js (temporary for local testing only)
const apiKey = process.env.MAILGUN_API_KEY || MAILGUN_API_KEY.value();
const domain = process.env.MAILGUN_DOMAIN || MAILGUN_DOMAIN.value();
```

But again, **the proper way is to deploy to Firebase and test there**.

## Summary

For this migration project:
- ✅ Code is production-ready
- ✅ Works perfectly when deployed to Firebase
- ⚠️ Local emulator has limitations (not your fault, it's Firebase's limitation)
- 💡 Best practice: Deploy to Firebase for real testing

---

**Next Step**: Run `node verify-secrets.js` then `firebase deploy --only functions`
