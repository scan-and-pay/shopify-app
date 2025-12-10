# Firebase Functions Secret Manager Migration - Deployment Checklist

## ✅ Changes Summary

### Fixed Files
1. **index.js** - Removed conflicting `module.exports.secrets` export
2. **shopify_webhooks.js** - Added missing `.region('australia-southeast1')` to all 4 webhook functions

### Root Cause
When using `defineSecret()` at the top level, ALL functions must declare:
- `.region('region-name')`
- `.runWith({ secrets: [...] })` with required secrets

Missing region specification causes `[firebase_functions/internal] INTERNAL` errors.

---

## 🔐 Required Secrets in Google Secret Manager

Ensure these secrets exist in your GCP project:

```bash
# Verify secrets exist
gcloud secrets list --project=YOUR_PROJECT_ID
```

Required secrets:
- ✅ `FIREBASE_PROJECT_ID`
- ✅ `FIREBASE_API_KEY`
- ✅ `FIREBASE_STORAGE_BUCKET`
- ✅ `GLOBALPAYMENTS_MASTER_KEY`
- ✅ `GLOBALPAYMENTS_BASE_URL`
- ✅ `MAILGUN_API_KEY`
- ✅ `MAILGUN_DOMAIN`
- ✅ `BASIQ_API_KEY`
- ✅ `ENCRYPTION_KEY`
- ✅ `SHOPIFY_API_SECRET`

---

## 📋 Pre-Deployment Checklist

### 1. Verify Firebase Login
```bash
firebase login
firebase projects:list
```

Expected: You should be logged in as `connect@scanandpay.com.au`

### 2. Set Active Project
```bash
cd C:\dev\shopify-app\flutter-app\functions
firebase use --add
# Select your project when prompted
```

### 3. Verify Syntax (Already Done ✅)
```bash
node -c index.js
node -c shopify_webhooks.js
node -c global_payments_api.js
node -c payid_qr.js
```

### 4. Test Local Emulator (Optional but Recommended)
```bash
npm run serve
# This starts local emulator - test your functions before deploying
```

---

## 🚀 Deployment Steps

### Option A: Deploy All Functions
```bash
cd C:\dev\shopify-app\flutter-app\functions
firebase deploy --only functions
```

### Option B: Deploy Individual Functions (Safer)
```bash
# Deploy OTP functions
firebase deploy --only functions:sendOtp,functions:verifyOtp

# Deploy PayID functions
firebase deploy --only functions:generatePayIDQR,functions:checkPayIDStatus

# Deploy Global Payments functions
firebase deploy --only functions:createGlobalPaymentsCustomer,functions:createPayToAgreement,functions:createPayIdInstrument,functions:processGlobalPayment,functions:getGlobalPaymentsCustomer,functions:getGlobalPaymentInstrument,functions:cancelGlobalPaymentAgreement,functions:checkGlobalPaymentsHealth

# Deploy Shopify webhooks
firebase deploy --only functions:appUninstalled,functions:customersDataRequest,functions:customersRedact,functions:shopRedact

# Deploy user management
firebase deploy --only functions:deleteUserAccount
```

---

## ✅ Post-Deployment Verification

### 1. List Deployed Functions
```bash
firebase functions:list
```

Expected output should show all functions in `australia-southeast1` region:
```
┌────────────────────────────────────┬─────────────────────────┬────────────┐
│ Function                           │ Region                  │ Type       │
├────────────────────────────────────┼─────────────────────────┼────────────┤
│ sendOtp                            │ australia-southeast1    │ callable   │
│ verifyOtp                          │ australia-southeast1    │ callable   │
│ generatePayIDQR                    │ australia-southeast1    │ callable   │
│ checkPayIDStatus                   │ australia-southeast1    │ callable   │
│ createGlobalPaymentsCustomer       │ australia-southeast1    │ callable   │
│ createPayToAgreement               │ australia-southeast1    │ callable   │
│ createPayIdInstrument              │ australia-southeast1    │ callable   │
│ processGlobalPayment               │ australia-southeast1    │ callable   │
│ getGlobalPaymentsCustomer          │ australia-southeast1    │ callable   │
│ getGlobalPaymentInstrument         │ australia-southeast1    │ callable   │
│ cancelGlobalPaymentAgreement       │ australia-southeast1    │ callable   │
│ checkGlobalPaymentsHealth          │ australia-southeast1    │ callable   │
│ deleteUserAccount                  │ australia-southeast1    │ callable   │
│ appUninstalled                     │ australia-southeast1    │ https      │
│ customersDataRequest               │ australia-southeast1    │ https      │
│ customersRedact                    │ australia-southeast1    │ https      │
│ shopRedact                         │ australia-southeast1    │ https      │
└────────────────────────────────────┴─────────────────────────┴────────────┘
```

### 2. Check Function Logs
```bash
firebase functions:log --limit 50
```

Look for successful deployment messages, no errors about missing secrets.

### 3. Test from Firebase Console
1. Go to Firebase Console → Functions
2. Click on any callable function (e.g., `checkGlobalPaymentsHealth`)
3. View the "Details" tab - verify secrets are listed
4. Check logs for any initialization errors

---

## 🧪 Testing with Existing Clients

### Flutter Android App Test
1. Open Flutter app on device/emulator
2. Test OTP email flow (should call `sendOtp` and `verifyOtp`)
3. Test PayID QR generation (should call `generatePayIDQR`)
4. Test payment flow (should call Global Payments functions)
5. Check app logs for any function call errors

### Shopify Web App Test
1. Open web dashboard at Cloud Run URL
2. Test Generate QR tab (should call `generatePayIDQR`)
3. Test History tab (should call `checkPayIDStatus`)
4. Test Settings tab (should read user profile)
5. Check browser console for any errors

### Expected Behavior
- ✅ All function calls succeed
- ✅ No `[firebase_functions/internal] INTERNAL` errors
- ✅ Secrets are properly injected (check logs for API key creation, email sending)
- ✅ No client code changes needed

---

## 🔍 Troubleshooting

### Issue: "Secret not found" error
**Solution:** Verify secret exists in GCP Secret Manager
```bash
gcloud secrets describe SECRET_NAME --project=YOUR_PROJECT_ID
```

### Issue: "Permission denied" accessing secrets
**Solution:** Grant Cloud Functions service account access to secrets
```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Issue: Function still shows INTERNAL error
**Solution:** Check function logs for specific error
```bash
firebase functions:log --only FUNCTION_NAME
```

### Issue: Old function version still running
**Solution:** Wait 60 seconds for cold start, or delete and redeploy
```bash
firebase functions:delete FUNCTION_NAME
firebase deploy --only functions:FUNCTION_NAME
```

---

## 📊 Monitoring

### View Real-Time Logs
```bash
firebase functions:log --tail
```

### Check Specific Function
```bash
firebase functions:log --only sendOtp
```

### Firebase Console
- Go to: https://console.firebase.google.com/
- Select your project
- Navigate to: Functions → Logs
- Filter by function name or error level

---

## 🎯 Success Criteria

✅ All 17 functions deployed successfully
✅ All functions show correct region (australia-southeast1)
✅ All functions show correct type (callable/https)
✅ No INTERNAL errors in logs
✅ Flutter app works without code changes
✅ Shopify web app works without code changes
✅ Secrets properly injected (check function logs)
✅ No permission errors accessing secrets

---

## 📝 Rollback Plan (If Needed)

If the new deployment causes issues:

1. **Revert to previous deployment:**
```bash
# Firebase keeps previous versions for 7 days
# Contact Firebase support to rollback via console
```

2. **Quick fix: Remove Secret Manager temporarily**
   - Comment out `defineSecret()` lines in `index.js`
   - Use environment variables instead (`.env` file)
   - Redeploy

3. **Emergency: Delete functions and start fresh**
```bash
firebase functions:delete --all
# Then redeploy from scratch
```

---

## 📞 Support

If you encounter issues:
1. Check Firebase Functions logs first
2. Verify all secrets exist in Secret Manager
3. Ensure service account has `secretAccessor` role
4. Check this checklist for common issues

**Firebase Project ID:** (Add your project ID here)
**Logged in as:** connect@scanandpay.com.au
**Region:** australia-southeast1
