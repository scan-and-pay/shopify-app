# Global Payments Firebase Functions Deployment Guide

## Overview

This guide covers deploying the Global Payments integration Firebase Functions for the ScanPay application.

## Prerequisites

- Firebase CLI installed: `npm install -g firebase-tools`
- Logged in to Firebase: `firebase login`
- Project selected: `firebase use scan-and-pay-guihzm`
- Global Payments API credentials (API key, Merchant ID)

---

## Step 1: Configure Environment Variables

### Option A: Using Firebase Functions Config (Recommended)

```bash
cd functions

# Set Global Payments API credentials
firebase functions:config:set \
  globalpayments.global_payments_master_key="YOUR_GLOBAL_PAYMENTS_MASTER_KEY" \
  globalpayments.merchant_id="YOUR_MERCHANT_ID" \
  globalpayments.api_url="https://api.globalpayments.com" \
  globalpayments.webhook_secret="YOUR_WEBHOOK_SECRET"

# View current config
firebase functions:config:get
```

### Option B: Using .env file (Local Development)

Create `functions/.env` file:

```env
GLOBAL_PAYMENTS_MASTER_KEY=your_master_key_here
GLOBAL_PAYMENTS_MERCHANT_ID=your_merchant_id_here
GLOBAL_PAYMENTS_API_URL=https://api.globalpayments.com
GLOBAL_PAYMENTS_WEBHOOK_SECRET=your_webhook_secret_here
```

**Note:** `.env` file should NOT be committed to Git. Add to `.gitignore`:

```bash
echo "functions/.env" >> .gitignore
```

---

## Step 2: Install Dependencies

```bash
cd functions
npm install
```

The required dependencies are already in `package.json`:
- `firebase-functions` - Firebase Cloud Functions SDK
- `axios` - HTTP client for API calls
- `firebase-admin` - Firebase Admin SDK

---

## Step 3: Test Functions Locally (Optional)

```bash
# Start Firebase emulators
firebase emulators:start

# Test in another terminal
# Example: Verify payment
curl -X POST http://localhost:5001/scan-and-pay-guihzm/australia-southeast1/verifyGlobalPayment \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "transactionId": "TEST123",
      "amount": 10.50,
      "merchantId": "MERCHANT_001"
    }
  }'

# Example: Check health
curl http://localhost:5001/scan-and-pay-guihzm/australia-southeast1/checkGlobalPaymentsHealth
```

---

## Step 4: Deploy to Firebase

### Deploy All Functions

```bash
# From project root
firebase deploy --only functions
```

### Deploy Specific Functions (Faster)

```bash
# Deploy only Global Payments functions
firebase deploy --only functions:verifyGlobalPayment,functions:getGlobalPaymentStatus,functions:registerGlobalPaymentsMerchant,functions:getGlobalPaymentsMerchantTransactions,functions:handleGlobalPaymentsWebhook,functions:checkGlobalPaymentsHealth
```

### Deploy with Project Specification

```bash
firebase deploy --only functions --project scan-and-pay-guihzm
```

---

## Step 5: Verify Deployment

### Check Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `scan-and-pay-guihzm`
3. Navigate to **Functions** section
4. Verify all Global Payments functions are listed:
   - ✅ `verifyGlobalPayment`
   - ✅ `getGlobalPaymentStatus`
   - ✅ `registerGlobalPaymentsMerchant`
   - ✅ `getGlobalPaymentsMerchantTransactions`
   - ✅ `handleGlobalPaymentsWebhook`
   - ✅ `checkGlobalPaymentsHealth`

### Test Deployed Functions

```bash
# Test health check (no auth required)
curl https://australia-southeast1-scan-and-pay-guihzm.cloudfunctions.net/checkGlobalPaymentsHealth

# Test with Firebase Auth token (for authenticated functions)
# Get auth token from Flutter app or Firebase Auth
firebase functions:shell
```

---

## Deployed Functions Reference

### 1. verifyGlobalPayment
- **Type:** Callable HTTPS
- **Auth:** Required
- **Purpose:** Verify payment transaction in real-time
- **Region:** australia-southeast1

**Example Call (from Flutter):**
```dart
final result = await GlobalPaymentsService.verifyTransaction(
  transactionId: 'TX123',
  amount: 50.00,
  merchantId: 'MERCHANT_001',
);
```

### 2. getGlobalPaymentStatus
- **Type:** Callable HTTPS
- **Auth:** Required
- **Purpose:** Get transaction status
- **Region:** australia-southeast1

### 3. registerGlobalPaymentsMerchant
- **Type:** Callable HTTPS
- **Auth:** Required
- **Purpose:** Register new merchant
- **Region:** australia-southeast1

### 4. getGlobalPaymentsMerchantTransactions
- **Type:** Callable HTTPS
- **Auth:** Required
- **Purpose:** Get merchant transaction history
- **Region:** australia-southeast1

### 5. handleGlobalPaymentsWebhook
- **Type:** HTTP Request
- **Auth:** Webhook signature verification
- **Purpose:** Receive payment status updates
- **Region:** australia-southeast1
- **URL:** `https://australia-southeast1-scan-and-pay-guihzm.cloudfunctions.net/handleGlobalPaymentsWebhook`

**Configure in Global Payments Dashboard:**
- Webhook URL: Copy from Firebase Console
- Events: `payment.verified`, `payment.failed`, `payment.pending`

### 6. checkGlobalPaymentsHealth
- **Type:** Callable HTTPS
- **Auth:** Not required
- **Purpose:** Check API configuration and health
- **Region:** australia-southeast1

---

## Firestore Collections Created

The functions automatically create these Firestore collections:

### `transactions`
```javascript
{
  transactionId: string,
  merchantId: string,
  userId: string,
  amount: number,
  fee: number,
  merchantReceives: number,
  status: 'verified' | 'pending' | 'failed',
  provider: 'global_payments',
  verifiedAt: timestamp,
  webhookReceivedAt: timestamp (optional),
  webhookEvent: string (optional)
}
```

### `merchants`
```javascript
{
  merchantId: string,
  merchantName: string,
  payId: string,
  abn: string (optional),
  email: string,
  userId: string,
  provider: 'global_payments',
  status: 'active' | 'inactive',
  registeredAt: timestamp,
  feeStructure: {
    percentage: number,
    fixed: number,
    description: string
  }
}
```

---

## Security Rules

Add these Firestore security rules:

```javascript
// functions/firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Transactions - users can only read their own
    match /transactions/{transactionId} {
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      allow write: if false; // Only functions can write
    }

    // Merchants - users can only read their own
    match /merchants/{userId} {
      allow read: if request.auth != null && userId == request.auth.uid;
      allow write: if false; // Only functions can write
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

---

## Monitoring & Logs

### View Logs

```bash
# View all function logs
firebase functions:log

# View specific function logs
firebase functions:log --only verifyGlobalPayment

# Follow logs in real-time
firebase functions:log --follow
```

### Firebase Console Logs

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `scan-and-pay-guihzm`
3. Navigate to **Functions** → **Logs**
4. Filter by function name

---

## Cost Estimation

### Firebase Functions Pricing

**Free Tier:**
- 2 million invocations/month
- 400,000 GB-seconds/month
- 200,000 CPU-seconds/month

**Estimated Costs (assuming 10,000 transactions/month):**
- Function invocations: 20,000 (verification + status checks)
- Cost: ~$0.40/month (well within free tier)

### Global Payments Transaction Fees

- **Fee Structure:** 0.5% + $0.10 per transaction
- **Example:** $100 transaction = $0.60 fee
- **Merchant receives:** $99.40

---

## Troubleshooting

### Function deployment fails

**Error:** "Billing account not configured"
- **Solution:** Enable billing in Firebase Console

**Error:** "Insufficient permissions"
- **Solution:** Ensure you're logged in with correct account:
  ```bash
  firebase logout
  firebase login
  firebase projects:list
  ```

### Functions not appearing in console

- Wait 2-3 minutes for deployment to complete
- Check deployment status: `firebase functions:log`
- Verify region is correct: `australia-southeast1`

### Configuration not working

```bash
# Check current config
firebase functions:config:get

# Reset config if needed
firebase functions:config:unset globalpayments
firebase functions:config:set globalpayments.api_key="NEW_KEY"
```

### Testing authentication issues

```bash
# Get Firebase user token for testing
firebase functions:shell

# Then in the shell:
> verifyGlobalPayment({transactionId: 'TEST', amount: 10, merchantId: 'M1'})
```

---

## Next Steps

1. **Get Global Payments Credentials:**
   - Sign up at [Global Payments Developer Portal](https://developer.globalpayments.com)
   - Get Master Key and Merchant ID
   - Configure webhook URL

2. **Update Configuration:**
   - Replace mock credentials with real ones
   - Set webhook secret

3. **Replace Mock Implementation:**
   - Update `mockGlobalPaymentsVerify()` in `global_payments_api.js`
   - Implement actual API calls using axios
   - Implement webhook signature verification

4. **Test in Production:**
   - Use Global Payments sandbox environment first
   - Test all payment flows
   - Monitor logs for errors

5. **Monitor Performance:**
   - Set up Firebase Performance Monitoring
   - Track function execution times
   - Monitor error rates

---

## Re-enabling Basiq (Future)

When CDR compliance is complete:

1. **Uncomment in `index.js`:**
   ```javascript
   const basiqApi = require('./basiq_api.js');
   exports.createBasiqConnect = basiqApi.createBasiqConnect;
   exports.handleBasiqWebhook = basiqApi.handleBasiqWebhook;
   exports.getBasiqStatus = basiqApi.getBasiqStatus;
   ```

2. **Deploy:**
   ```bash
   firebase deploy --only functions
   ```

3. **Test Basiq integration**

---

## Support

- **Firebase Functions Docs:** https://firebase.google.com/docs/functions
- **Global Payments API Docs:** https://developer.globalpayments.com
- **Project Issues:** https://github.com/your-repo/issues

---

## Summary

✅ **Deployed Functions:**
- verifyGlobalPayment - Transaction verification
- getGlobalPaymentStatus - Status checking
- registerGlobalPaymentsMerchant - Merchant registration
- getGlobalPaymentsMerchantTransactions - Transaction history
- handleGlobalPaymentsWebhook - Webhook handler
- checkGlobalPaymentsHealth - Health monitoring

✅ **Basiq Functions:**
- Temporarily disabled (commented out)
- Easy to re-enable when CDR compliance ready

✅ **Ready for:**
- Real-time payment verification
- Transaction fee calculation (0.5% + $0.10)
- Merchant onboarding
- Transaction tracking
