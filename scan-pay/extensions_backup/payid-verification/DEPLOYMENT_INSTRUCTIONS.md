# PayID Verification Extension - Deployment Instructions

## Overview

This Shopify Checkout UI Extension enables PayID payments with QR code scanning, integrated with your existing Firebase/Global Payments backend located at `C:\scanandpayWeb`.

## Pre-Deployment Checklist

### 1. Backend Services

Ensure these are deployed and operational:

- [ ] Firebase Cloud Functions deployed from `C:\scanandpayWeb`
- [ ] `verifyPayment` function accessible
- [ ] `globalPaymentsWebhook` function accessible
- [ ] Global Payments webhook configured to call Firebase function
- [ ] Firebase project has CORS enabled for Shopify domains

### 2. Configuration

- [ ] Firebase function URL updated in `src/Checkout.jsx` (line 22)
- [ ] Merchant PayID configured in `src/Checkout.jsx` (line 24)
- [ ] Network access enabled in `shopify.extension.toml` (line 30)
- [ ] Shopify app scopes updated in `shopify.app.toml`

### 3. Dependencies

```bash
cd C:\Shopify\scan-pay\extensions\payid-verification
npm install
```

## Deployment Steps

### Step 1: Update Configuration

Edit `C:\Shopify\scan-pay\extensions\payid-verification\src\Checkout.jsx`:

```javascript
// Line 22 - Your Firebase Cloud Functions URL
const FIREBASE_FUNCTION_URL = 'https://us-central1-YOUR-PROJECT-ID.cloudfunctions.net';

// Line 24 - Merchant PayID
const MERCHANT_PAYID = 'payments@merchant-business.com.au';
```

To find your Firebase URL:
```bash
cd C:\scanandpayWeb
firebase functions:list
```

### Step 2: Build and Deploy

```bash
# From project root
cd C:\Shopify\scan-pay

# Login to Shopify (if not already)
shopify auth login

# Deploy the extension
shopify app deploy
```

Follow the prompts:
- Select your Shopify organization: **Scan & Pay**
- Select your app: **Scan & Pay**
- Confirm deployment

### Step 3: Activate in Shopify Admin

1. Go to your Shopify admin: `https://scan-and-pay-2.myshopify.com/admin`
2. Navigate to **Settings** → **Checkout**
3. Scroll to **Checkout Customizations** or **Apps and sales channels**
4. Find **payid-verification** extension
5. Click **Activate** or **Turn on**

### Step 4: Position the Extension

1. Click **Customize** next to the extension
2. In the checkout editor:
   - Drag the extension to the **Payment** section
   - Position it AFTER payment methods
   - This ensures it's visible after customer enters payment info
3. Save changes

### Step 5: Test in Development

```bash
# Start development server
cd C:\Shopify\scan-pay
shopify app dev
```

This opens your test store with the extension live.

Test flow:
1. Add product to cart
2. Proceed to checkout
3. Enter shipping address
4. See "Pay with PayID" option
5. Click to generate QR code
6. Verify QR code displays
7. Note the payment reference

### Step 6: Backend Verification Test

Create a test transaction in Firebase to verify polling:

```bash
# Using Firebase CLI
firebase firestore:write transactions/TEST-001 '{
  "reference": "REF-2024-TEST123",
  "amount": 10000,
  "status": "approved",
  "verified": true,
  "currencyCode": "AUD",
  "transactionId": "TEST-TXN-001",
  "createdDateTime": "2024-12-05T00:00:00Z"
}'
```

Then in checkout:
1. Manually enter reference `REF-2024-TEST123`
2. Click "I've Paid - Verify Now"
3. Should show payment verified ✅

### Step 7: Production Deployment

When ready for production:

```bash
# Deploy to production
shopify app deploy --production

# OR use the Shopify Partners dashboard
# to promote the extension to production
```

## Post-Deployment Configuration

### Global Payments Webhook

Ensure webhook is configured:

1. Login to [Global Payments Dashboard](https://docs.gpaunz.com)
2. Navigate to **Webhooks** → **Create Subscription**
3. Set webhook URL to your Firebase function:
   ```
   https://us-central1-YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook
   ```
4. Select event types: **transactions**
5. Save and note the private key
6. Add private key to Firebase config:
   ```bash
   cd C:\scanandpayWeb
   firebase functions:config:set globalpayments.private_key="YOUR-KEY-HERE"
   firebase deploy --only functions
   ```

### Firebase CORS Configuration

If you get CORS errors, configure Firebase:

```javascript
// In your Cloud Function
const cors = require('cors')({ origin: true });

exports.verifyPayment = functions.https.onRequest((req, res) => {
  return cors(req, res, async () => {
    // Your function code
  });
});
```

Or allow specific Shopify domains:

```javascript
const corsOptions = {
  origin: [
    'https://scan-and-pay-2.myshopify.com',
    'https://checkout.shopify.com',
    /\.shopify\.com$/
  ]
};

const cors = require('cors')(corsOptions);
```

## Monitoring & Debugging

### View Extension Logs

During development:
```bash
shopify app dev --verbose
```

### View Firebase Logs

```bash
cd C:\scanandpayWeb
firebase functions:log --only verifyPayment
firebase functions:log --only globalPaymentsWebhook
```

### Test Payment Verification API

```bash
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/verifyPayment \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "REF-2024-TEST123",
    "amount": 100.00,
    "payId": "payments@test.com.au"
  }'
```

### Browser Console

In checkout, open browser console (F12) to see:
- QR code generation logs
- Payment verification requests
- Error messages

## Troubleshooting

### Extension Not Showing

**Issue**: Extension doesn't appear in checkout

**Fix**:
1. Verify Shopify Plus or checkout extensibility enabled
2. Check extension is activated in Settings → Checkout
3. Ensure extension is positioned in checkout editor
4. Try incognito/private browser window

### QR Code Not Loading

**Issue**: Broken image icon where QR code should be

**Fix**:
1. Check `network_access = true` in `shopify.extension.toml`
2. Verify QR API is accessible: https://api.qrserver.com/v1/create-qr-code/
3. Check browser console for errors
4. Try alternative QR API or library

### Payment Verification Fails

**Issue**: "Payment not received" even after paying

**Fix**:
1. Check Firebase function URL is correct
2. Verify `verifyPayment` function is deployed:
   ```bash
   firebase functions:list
   ```
3. Check Firebase logs for errors:
   ```bash
   firebase functions:log --only verifyPayment
   ```
4. Verify transaction was created in Firestore:
   - Go to Firebase Console → Firestore
   - Check `transactions` collection
   - Look for matching reference
5. Test API directly with curl (see above)

### Webhook Not Receiving Events

**Issue**: Global Payments webhook not triggering

**Fix**:
1. Verify webhook URL in GP dashboard
2. Check webhook signature validation
3. View GP webhook delivery logs
4. Check Firebase function logs:
   ```bash
   firebase functions:log --only globalPaymentsWebhook
   ```
5. Test webhook manually:
   ```bash
   curl -X POST https://YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook \
     -H "Content-Type: application/json" \
     -d @test-webhook.json
   ```

### Checkout Completes Without Payment

**Issue**: Customer can complete order without paying

**Fix**:
1. Verify `useBuyerJourneyIntercept` is implemented
2. Check Shopify Plus features are enabled
3. Ensure extension is not returning `behavior: 'allow'` prematurely
4. Review checkout attributes are being set

## Security Considerations

### 1. Reference Generation

The extension uses `crypto.getRandomValues()` for secure reference generation:
```javascript
const array = new Uint8Array(length);
crypto.getRandomValues(array);
```

This is cryptographically secure, unlike `Math.random()`.

### 2. Backend Verification

Payment verification happens server-side via Firebase Cloud Functions, not client-side. The extension only polls the backend - it cannot mark payments as verified on its own.

### 3. Webhook Signatures

Global Payments webhook includes HMAC signature verification:
```javascript
// In globalPaymentsWebhook function
const signature = req.headers['x-signature'];
const isValid = verifyWebhookSignature(payload, signature, privateKey);
```

### 4. HTTPS Only

All communications use HTTPS:
- Shopify checkout (always HTTPS)
- Firebase Cloud Functions (always HTTPS)
- QR API (HTTPS)

## Rollback Procedure

If issues arise in production:

### Quick Rollback

1. Go to Shopify Admin → Settings → Checkout
2. Find payid-verification extension
3. Click **Deactivate** or **Turn off**
4. Extension is immediately disabled

### Full Rollback

```bash
# Revert to previous version
shopify app versions list
shopify app versions activate --version <previous-version-id>
```

## Support Contacts

**Shopify Extension Issues**:
- Shopify Partners support
- Documentation: https://shopify.dev/docs/api/checkout-ui-extensions

**Firebase/Backend Issues**:
- Check existing documentation: `C:\Shopify\scan-pay\extensions\files (2)\CLAUDE.md`
- Firebase logs: `firebase functions:log`

**Global Payments Issues**:
- Global Payments Oceania support
- Documentation: https://docs.gpaunz.com

## Production Go-Live Checklist

Before enabling for real customers:

- [ ] Test with actual bank account (small amount like $1)
- [ ] Verify order creates in Shopify admin
- [ ] Confirm email/SMS notifications send (if enabled)
- [ ] Test on mobile device (iOS and Android)
- [ ] Test on desktop (Chrome, Firefox, Safari)
- [ ] Verify refund process (if applicable)
- [ ] Monitor for 1 hour after launch
- [ ] Have rollback procedure ready
- [ ] Document merchant support process

## Next Steps

1. Complete initial deployment to test store
2. Run through full test transaction
3. Monitor Firebase logs for any errors
4. Adjust configuration as needed
5. Deploy to production when ready

For detailed technical documentation, see:
- **Full Documentation**: `DOCUMENTATION.md` (to be created)
- **Setup Guide**: `SETUP_GUIDE.md`
- **Existing System Docs**: `C:\Shopify\scan-pay\extensions\files (2)\CLAUDE.md`
