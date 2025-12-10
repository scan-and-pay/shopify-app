# Shopify Webhook Deployment Guide - Complete Solution

## Architecture Overview

Your setup uses:
- **Frontend**: Flutter web app deployed to Google Cloud Run at `merchants.scanandpay.com.au`
- **Backend**: Firebase Functions for webhook handlers
- **Routing**: Nginx in the Cloud Run container proxies `/webhooks/*` to Firebase Functions

## Files Created/Updated

### 1. `functions/shopify_webhooks.js` ✅
- Four webhook handlers with proper HMAC verification using `req.rawBody`
- `appUninstalled` - Handles app uninstall
- `customersDataRequest` - GDPR data request
- `customersRedact` - GDPR customer deletion
- `shopRedact` - Complete shop data deletion

### 2. `functions/index.js` ✅
- Exports all four webhook handlers
- Maintains existing function exports

### 3. `nginx-webhook.conf` ✅
- Proxies `/webhooks/*` routes to Firebase Functions
- Preserves Shopify headers for HMAC verification
- Disables buffering for webhook requests

### 4. `Dockerfile` ✅
- Updated to use custom nginx config
- Copies `nginx-webhook.conf` to container

---

## Deployment Steps

### Step 1: Configure Shopify API Secret in Firebase

```bash
cd C:\dev\shopify-app\flutter-app\functions

# Set the Shopify API secret (REQUIRED for HMAC verification)
firebase functions:config:set shopify.api_secret="YOUR_SHOPIFY_API_SECRET"

# Verify it's set
firebase functions:config:get
```

**Important**: Replace `YOUR_SHOPIFY_API_SECRET` with your actual secret from Shopify Partner Dashboard → Apps → Scan & Pay → App credentials → API secret key.

### Step 2: Deploy Firebase Functions

```bash
cd C:\dev\shopify-app\flutter-app\functions

# Install dependencies (if not already done)
npm install

# Deploy all webhook functions
firebase deploy --only functions:appUninstalled,functions:customersDataRequest,functions:customersRedact,functions:shopRedact
```

**Expected Output:**
```
✔  functions[appUninstalled(us-central1)] Successful create operation.
Function URL (appUninstalled): https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/appUninstalled
✔  functions[customersDataRequest(us-central1)] Successful create operation.
Function URL (customersDataRequest): https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/customersDataRequest
✔  functions[customersRedact(us-central1)] Successful create operation.
Function URL (customersRedact): https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/customersRedact
✔  functions[shopRedact(us-central1)] Successful create operation.
Function URL (shopRedact): https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/shopRedact
```

### Step 3: Test Firebase Functions Directly (Optional)

Test that functions are deployed and HMAC verification works:

```bash
# Test without HMAC (should return 401)
curl -X POST https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/appUninstalled \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Expected: "Unauthorized - Invalid HMAC"
```

This 401 response is **CORRECT** - it means HMAC verification is working!

### Step 4: Rebuild and Deploy Flutter Cloud Run Service

```bash
cd C:\dev\shopify-app\flutter-app

# Commit changes (optional but recommended)
git add Dockerfile nginx-webhook.conf functions/
git commit -m "Add Shopify webhook handlers with nginx proxy"

# Push to trigger GitHub Actions deployment
git push origin main
```

**OR manually deploy:**

```bash
# Build Docker image
docker build -t gcr.io/scan-and-pay-guihzm/flutter-app:latest .

# Push to GCR
docker push gcr.io/scan-and-pay-guihzm/flutter-app:latest

# Deploy to Cloud Run
gcloud run deploy flutter-app \
  --image=gcr.io/scan-and-pay-guihzm/flutter-app:latest \
  --platform=managed \
  --region=us-central1 \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=10
```

### Step 5: Verify Webhook Endpoints Are Reachable

```bash
# Test each webhook endpoint through Cloud Run
curl -X POST https://merchants.scanandpay.com.au/webhooks/app/uninstalled \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/data_request \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/redact \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

curl -X POST https://merchants.scanandpay.com.au/webhooks/shop/redact \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

**Expected Response**: `"Unauthorized - Invalid HMAC"` (HTTP 401)

✅ **401 = SUCCESS** - Endpoint is reachable and HMAC verification is working!
❌ **404 = FAILURE** - Nginx routing is broken

### Step 6: Configure Shopify Webhooks

You have two options:

#### Option A: Using Shopify CLI (for scan-pay backend)

If you want to use the React Router backend in `C:\dev\shopify-app\scan-pay`:

```bash
cd C:\dev\shopify-app\scan-pay

# Edit shopify.app.toml (already done - see file)
# Verify webhooks are configured:
cat shopify.app.toml | grep -A 20 webhooks

# Deploy to Shopify
npm run deploy
```

#### Option B: Manual Configuration in Partner Dashboard

1. Go to Shopify Partners Dashboard
2. Navigate to **Apps** → **Scan & Pay**
3. Go to **Configuration** → **Webhooks**
4. Add these webhook subscriptions:

| Event | URL |
|-------|-----|
| `app/uninstalled` | `https://merchants.scanandpay.com.au/webhooks/app/uninstalled` |
| `customers/data_request` | `https://merchants.scanandpay.com.au/webhooks/customers/data_request` |
| `customers/redact` | `https://merchants.scanandpay.com.au/webhooks/customers/redact` |
| `shop/redact` | `https://merchants.scanandpay.com.au/webhooks/shop/redact` |

### Step 7: Run Shopify Automated Compliance Tests

1. Go to Shopify Partners Dashboard
2. Navigate to **Apps** → **Scan & Pay**
3. Go to **Distribution** → **Compliance**
4. Click **"Run automated tests"**
5. All webhook tests should now **PASS** ✅

---

## How It Works

### Request Flow

```
Shopify
  ↓ POST /webhooks/app/uninstalled
Cloud Run (nginx on port 8080)
  ↓ proxy_pass
Firebase Functions (us-central1)
  ↓ HMAC verification using req.rawBody
Handler function
  ↓ Update Firestore
Response 200 OK
```

### HMAC Verification

1. Shopify sends webhook with `X-Shopify-Hmac-Sha256` header
2. Nginx preserves all Shopify headers when proxying
3. Firebase Function receives `req.rawBody` (raw bytes)
4. Function computes HMAC-SHA256 using `SHOPIFY_API_SECRET`
5. Compares computed hash with header value
6. Returns 401 if mismatch, proceeds if valid

**Key Detail**: Using `req.rawBody` (Buffer) instead of `JSON.stringify(req.body)` ensures byte-perfect HMAC verification.

---

## Troubleshooting

### Issue: Firebase deploy fails with "SHOPIFY_API_SECRET not configured"

**Solution**: Set the secret:
```bash
firebase functions:config:set shopify.api_secret="your_actual_secret"
firebase deploy --only functions
```

### Issue: Getting 404 on webhook endpoints

**Cause**: Nginx config not applied or Cloud Run not redeployed

**Solution**:
1. Verify `nginx-webhook.conf` exists in flutter-app directory
2. Rebuild Docker image: `docker build -t gcr.io/scan-and-pay-guihzm/flutter-app .`
3. Redeploy to Cloud Run

### Issue: Getting 401 from manual curl tests

**This is CORRECT!** Manual requests don't have valid Shopify HMAC signatures. Only real Shopify webhooks will return 200 OK.

To test with a valid signature:
1. Install your app on a Shopify test store
2. Trigger a real webhook (e.g., uninstall the app)
3. Check Cloud Functions logs: `firebase functions:log`

### Issue: Functions deployed but webhooks still fail

**Check Firebase Function logs:**
```bash
firebase functions:log --only appUninstalled
firebase functions:log --only customersDataRequest
```

Look for:
- "HMAC verification failed" → Check `SHOPIFY_API_SECRET` matches Partner Dashboard
- "SHOPIFY_API_SECRET not configured" → Run `firebase functions:config:set`

### Issue: Cloud Run returns 502 Bad Gateway

**Cause**: Firebase Functions URL incorrect in nginx config

**Solution**: Verify your Firebase project ID in `nginx-webhook.conf`:
```nginx
proxy_pass https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/appUninstalled;
```

Should be:
```nginx
proxy_pass https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/appUninstalled;
```

---

## Verification Checklist

- [ ] Firebase Functions deployed successfully
- [ ] `SHOPIFY_API_SECRET` configured in Firebase
- [ ] Cloud Run service redeployed with new Docker image
- [ ] All 4 webhook endpoints return 401 (not 404) on manual curl
- [ ] Webhooks configured in Shopify Partner Dashboard
- [ ] Shopify automated compliance tests run and pass

---

## Environment Variables

### Firebase Functions

Set via Firebase CLI:
```bash
firebase functions:config:set shopify.api_secret="YOUR_SECRET"
```

Access in code:
```javascript
const shopifySecret = functions.config().shopify?.api_secret;
```

### Cloud Run (if needed)

Currently not needed, but can set via:
```bash
gcloud run services update flutter-app \
  --region=us-central1 \
  --set-env-vars="KEY=VALUE"
```

---

## Monitoring & Logs

### Firebase Functions Logs

```bash
# Real-time logs for all functions
firebase functions:log

# Specific function
firebase functions:log --only appUninstalled

# Last 50 lines
firebase functions:log --lines 50
```

### Cloud Run Logs

```bash
# View Cloud Run logs
gcloud run services logs read flutter-app --region=us-central1 --limit=50

# Follow logs in real-time
gcloud run services logs tail flutter-app --region=us-central1
```

### What to Look For

**Successful webhook:**
```
Received webhook: app/uninstalled from example.myshopify.com
HMAC verification passed
Marked shop example.myshopify.com as uninstalled
Deleted 2 sessions for shop example.myshopify.com
```

**Failed HMAC:**
```
Received webhook: app/uninstalled from example.myshopify.com
HMAC verification failed
```

---

## Security Considerations

1. **HMAC Verification**: Always enabled, prevents unauthorized webhook calls
2. **HTTPS Only**: All endpoints use HTTPS (Cloud Run + Firebase Functions)
3. **Secret Management**: API secret stored in Firebase config, not in code
4. **CORS**: Set to allow Shopify origins only (currently `*` for testing)
5. **Request Validation**: Only POST methods accepted

---

## Cost Estimation

### Firebase Functions
- **Free tier**: 2M invocations/month
- **Shopify webhooks**: ~4-10 calls per merchant lifecycle
- **Estimated cost**: $0 for most apps

### Cloud Run
- **Free tier**: 2M requests/month
- **Current usage**: Frontend + webhook proxying
- **Estimated cost**: $0-5/month

---

## Next Steps After Deployment

1. **Test on Development Store**: Install app, uninstall, check logs
2. **Monitor GDPR Requests**: Check `gdpr_requests` collection in Firestore
3. **Implement Data Export**: Complete TODO items in webhook handlers
4. **Add Logging**: Consider Cloud Logging for production monitoring
5. **Set Up Alerts**: Configure Firebase alerts for function failures

---

## Support Commands Reference

```bash
# Check Firebase project
firebase projects:list
firebase use scan-and-pay-guihzm

# List deployed functions
firebase functions:list

# Check function config
firebase functions:config:get

# Test local functions
cd functions && npm run serve

# Check Cloud Run status
gcloud run services describe flutter-app --region=us-central1

# View webhook URLs
gcloud run services describe flutter-app --region=us-central1 --format='value(status.url)'
```

---

## Summary

Your Shopify compliance webhooks are now:

1. ✅ **Implemented** in Firebase Functions with proper HMAC verification
2. ✅ **Exposed** at `merchants.scanandpay.com.au/webhooks/*`
3. ✅ **Proxied** through nginx in Cloud Run container
4. ✅ **Secured** with HMAC-SHA256 signature verification
5. ✅ **Logged** to Firestore for compliance tracking

Follow the deployment steps above to go live!
