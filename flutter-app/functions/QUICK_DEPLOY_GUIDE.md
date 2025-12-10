# 🚀 Quick Deploy Guide - Secret Manager Migration

## ✅ Pre-Deployment (1 minute)

```bash
# 1. Navigate to functions directory
cd C:\dev\shopify-app\flutter-app\functions

# 2. Verify you're logged in
firebase login:list
# Should show: connect@scanandpay.com.au

# 3. Run configuration check
node verify-function-config.js
# Should show: "✅ All checks passed!"
```

---

## 🚀 Deploy (3-5 minutes)

```bash
# Deploy all functions
firebase deploy --only functions
```

**What to expect:**
```
=== Deploying to 'your-project'...

i  deploying functions
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
i  functions: ensuring required API cloudbuild.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
✔  functions: required API cloudbuild.googleapis.com is enabled
i  functions: preparing codebase default for deployment
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (XX KB) for uploading
✔  functions: functions folder uploaded successfully

The following functions will deploy to australia-southeast1:
  - sendOtp
  - verifyOtp
  - generatePayIDQR
  - checkPayIDStatus
  - createGlobalPaymentsCustomer
  - createPayToAgreement
  - createPayIdInstrument
  - processGlobalPayment
  - getGlobalPaymentsCustomer
  - getGlobalPaymentInstrument
  - cancelGlobalPaymentAgreement
  - checkGlobalPaymentsHealth
  - deleteUserAccount
  - appUninstalled
  - customersDataRequest
  - customersRedact
  - shopRedact

✔  functions: all functions deployed successfully!
```

---

## 🧪 Quick Test (2 minutes)

### Test 1: Check Function List
```bash
firebase functions:list
```
**Expected:** All 17 functions listed with region `australia-southeast1`

### Test 2: Check Logs
```bash
firebase functions:log --limit 20
```
**Expected:** No INTERNAL errors, deployment success messages

### Test 3: Test Flutter App
1. Open Flutter app
2. Try email sign-in (OTP flow)
3. Generate a PayID QR code

**Expected:** Everything works as before, no errors

### Test 4: Test Shopify Dashboard
1. Open web dashboard at Cloud Run URL
2. Try Generate QR tab
3. Check History tab

**Expected:** QR generation works, history loads

---

## ❌ If Something Goes Wrong

### Issue: Deployment fails with "permission denied"
```bash
# Grant secret access to Cloud Functions service account
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:YOUR_PROJECT_ID@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Issue: Function shows INTERNAL error
```bash
# Check specific function logs
firebase functions:log --only FUNCTION_NAME

# Common fixes:
# 1. Verify secret exists in Secret Manager
gcloud secrets list --project=YOUR_PROJECT_ID

# 2. Delete and redeploy specific function
firebase functions:delete FUNCTION_NAME
firebase deploy --only functions:FUNCTION_NAME
```

### Issue: Still getting errors
```bash
# View real-time logs
firebase functions:log --tail

# Try calling the function and watch logs for specific error
```

---

## 📊 What Changed (Summary)

| File | Changes | Impact |
|------|---------|--------|
| `index.js` | Removed `module.exports.secrets` | Cleaner exports |
| `shopify_webhooks.js` | Added `.region()` to 4 functions | Fixes INTERNAL error |
| All other files | No changes | Already correct |

**Client Impact:** ZERO - No code changes needed in Flutter or Shopify apps

---

## ✅ Success Checklist

After deployment, verify:

- [ ] All 17 functions deployed (check Firebase Console)
- [ ] No INTERNAL errors in logs
- [ ] Flutter app OTP works
- [ ] Flutter app QR generation works
- [ ] Shopify dashboard login works
- [ ] Shopify dashboard QR generation works
- [ ] No permission errors

---

## 🎯 One-Command Deploy

```bash
cd C:\dev\shopify-app\flutter-app\functions && node verify-function-config.js && firebase deploy --only functions
```

This command:
1. Navigates to functions directory
2. Verifies configuration
3. Deploys (only if verification passes)

---

## 📞 Need Help?

1. **Check logs first:** `firebase functions:log --limit 50`
2. **Read full docs:**
   - `SECRET_MANAGER_MIGRATION_SUMMARY.md` - Complete details
   - `DEPLOYMENT_CHECKLIST.md` - Step-by-step guide
3. **Verify secrets exist:** `gcloud secrets list`

---

**Last Updated:** 2024-12-11
**Status:** ✅ Ready to Deploy
**Estimated Time:** 5 minutes total
