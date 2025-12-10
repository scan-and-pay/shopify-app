# Quick Deployment Guide - Shopify Webhooks

## Your Shopify API Secret
```
YOUR_SHOPIFY_API_SECRET_HERE
```
**Note**: Get your API secret from Shopify Partner Dashboard → Apps → Scan & Pay → Configuration → Client credentials

## 🚀 Deploy in 3 Steps

### Step 1: Deploy Firebase Functions
```bash
# Run this batch file:
deploy-webhooks.bat

# OR manually:
cd C:\dev\shopify-app\flutter-app\functions
firebase login --reauth
firebase functions:config:set shopify.api_secret="YOUR_SHOPIFY_API_SECRET_HERE"
firebase deploy --only functions:appUninstalled,functions:customersDataRequest,functions:customersRedact,functions:shopRedact
```

### Step 2: Deploy Cloud Run
```bash
# Run this batch file:
deploy-cloud-run.bat

# OR manually:
cd C:\dev\shopify-app\flutter-app
gcloud auth login
docker build -t gcr.io/scan-and-pay-guihzm/flutter-app:latest .
docker push gcr.io/scan-and-pay-guihzm/flutter-app:latest
gcloud run deploy flutter-app --image=gcr.io/scan-and-pay-guihzm/flutter-app:latest --region=us-central1 --allow-unauthenticated --port=8080
```

### Step 3: Test Webhooks
```bash
# Run this batch file:
test-webhooks.bat

# OR manually test each endpoint:
curl -X POST https://merchants.scanandpay.com.au/webhooks/app/uninstalled
curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/data_request
curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/redact
curl -X POST https://merchants.scanandpay.com.au/webhooks/shop/redact
```

**Expected Response**: `"Unauthorized - Invalid HMAC"` ✅

---

## 🔧 Shopify Configuration

### Webhook URLs to Configure

In Shopify Partner Dashboard → Apps → Scan & Pay → Configuration → Webhooks:

| Event | URL | Format |
|-------|-----|--------|
| `app/uninstalled` | `https://merchants.scanandpay.com.au/webhooks/app/uninstalled` | JSON |
| `customers/data_request` | `https://merchants.scanandpay.com.au/webhooks/customers/data_request` | JSON |
| `customers/redact` | `https://merchants.scanandpay.com.au/webhooks/customers/redact` | JSON |
| `shop/redact` | `https://merchants.scanandpay.com.au/webhooks/shop/redact` | JSON |

**OR** if using `shopify.app.toml` in `scan-pay` backend:

```toml
[webhooks]
api_version = "2025-10"

  [[webhooks.subscriptions]]
  topics = [ "app/uninstalled" ]
  uri = "/webhooks/app/uninstalled"

  [[webhooks.subscriptions]]
  topics = [ "customers/data_request" ]
  uri = "/webhooks/customers/data_request"

  [[webhooks.subscriptions]]
  topics = [ "customers/redact" ]
  uri = "/webhooks/customers/redact"

  [[webhooks.subscriptions]]
  topics = [ "shop/redact" ]
  uri = "/webhooks/shop/redact"
```

Then deploy:
```bash
cd C:\dev\shopify-app\scan-pay
npm run deploy
```

---

## ✅ Final Verification

### 1. Check Firebase Functions
```bash
firebase functions:list
```

Should show:
- `appUninstalled`
- `customersDataRequest`
- `customersRedact`
- `shopRedact`

### 2. Check Function Logs
```bash
firebase functions:log --only appUninstalled
```

### 3. Run Shopify Automated Tests

1. Go to: https://partners.shopify.com/
2. Navigate to: Apps → Scan & Pay → Distribution → Compliance
3. Click: **"Run automated tests"**
4. Result: All webhook tests should **PASS** ✅

---

## 🐛 Troubleshooting

### Issue: Firebase login fails
**Solution**: Use incognito mode or different browser:
```bash
firebase login --no-localhost
```

### Issue: Docker build fails
**Solution**: Ensure Docker Desktop is running:
```bash
docker ps
```

### Issue: 404 on webhook endpoints
**Solution**: Cloud Run not redeployed with nginx config. Redeploy:
```bash
deploy-cloud-run.bat
```

### Issue: 502 Bad Gateway
**Solution**: Firebase Functions not deployed. Deploy:
```bash
deploy-webhooks.bat
```

### Issue: HMAC verification still failing in Shopify tests
**Check**:
1. Firebase config: `firebase functions:config:get`
2. Should show: `shopify.api_secret: "YOUR_SHOPIFY_API_SECRET_HERE"`
3. If not, redeploy functions after setting secret

---

## 📊 Monitoring

### View Firebase Logs
```bash
firebase functions:log --lines 100
```

### View Cloud Run Logs
```bash
gcloud run services logs read flutter-app --region=us-central1 --limit=50
```

### Check Function Status
```bash
firebase functions:list
```

---

## 🎯 Success Criteria

✅ **Firebase Functions deployed** - Check with `firebase functions:list`
✅ **Shopify secret configured** - Check with `firebase functions:config:get`
✅ **Cloud Run updated** - Check with `gcloud run services describe flutter-app --region=us-central1`
✅ **Endpoints return 401** - Test with `test-webhooks.bat`
✅ **Shopify tests pass** - Run automated compliance tests in Partner Dashboard

---

## 📞 Quick Commands

```bash
# Deploy everything
deploy-webhooks.bat && deploy-cloud-run.bat

# Test everything
test-webhooks.bat

# View logs
firebase functions:log
gcloud run services logs tail flutter-app --region=us-central1

# Rollback if needed
firebase functions:delete appUninstalled
```

---

## 🔐 Important Notes

- ✅ **HMAC verification** is enabled (uses `req.rawBody`)
- ✅ **Nginx proxying** preserves all Shopify headers
- ✅ **Firebase config** stores secret securely
- ✅ **401 responses** on manual tests are **CORRECT**
- ⚠️ **Only Shopify's webhooks** will return 200 OK

---

## Need Help?

Check the full guide: `SHOPIFY_WEBHOOK_DEPLOYMENT.md`

View logs:
- Firebase: `firebase functions:log`
- Cloud Run: `gcloud run services logs read flutter-app --region=us-central1`

Test locally:
- Firebase emulator: `cd functions && npm run serve`
- Docker: `docker run -p 8080:8080 gcr.io/scan-and-pay-guihzm/flutter-app:test`
