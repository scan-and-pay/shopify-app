# PayID Verification - Setup Guide

## Quick Start

### 1. Configure Firebase URL

Edit `src/Checkout.jsx` and replace line 22:

```javascript
const FIREBASE_FUNCTION_URL = 'https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net';
```

With your actual Firebase function URL (from `C:\scanandpayWeb` project).

### 2. Set Merchant PayID

Edit line 24:

```javascript
const MERCHANT_PAYID = 'payments@scanandpay.com.au';
```

Replace with the merchant's PayID email address.

### 3. Deploy Extension

```bash
cd C:\Shopify\scan-pay
npm install
shopify app deploy
```

### 4. Activate in Shopify

1. Go to Shopify Admin → Settings → Checkout
2. Scroll to "Apps and sales channels"
3. Find "PayID Verification"
4. Click "Customize" → Enable the extension
5. Position it in the payment method section

### 5. Test

1. Create a test order
2. Proceed to checkout
3. Click "Pay with PayID QR Code"
4. Verify QR code displays correctly
5. Use test payment reference to verify backend integration

## Configuration Options

### Polling Settings

Adjust verification polling in `src/Checkout.jsx`:

```javascript
// Line 146 - Max attempts (default: 40 * 3s = 2 minutes)
if (verificationAttempts < 40) {
  setTimeout(() => verifyPayment(), 3000); // Poll interval: 3 seconds
}
```

### QR Code Size

Adjust QR code dimensions in `src/Checkout.jsx` line 75:

```javascript
const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(qrData)}`;
//                                                                  ↑ Change size here
```

## Backend Integration

This extension requires these Firebase Cloud Functions to be deployed:

1. **verifyPayment** - Payment verification endpoint
2. **globalPaymentsWebhook** - Receives Global Payments notifications

Both are defined in:
```
C:\Shopify\scan-pay\extensions\files (2)\global-payments-webhook.js
```

Deploy them from your `C:\scanandpayWeb` project:

```bash
cd C:\scanandpayWeb
firebase deploy --only functions:verifyPayment,functions:globalPaymentsWebhook
```

## Merchant-Specific Setup

For each merchant installation:

1. **Get their PayID**: Ask merchant for their PayID email
2. **Update configuration**: Set `MERCHANT_PAYID` in extension
3. **Store in Firebase**: Add merchant record to Firestore:

```javascript
db.collection('merchants').add({
  shopifyStoreId: 'store.myshopify.com',
  payId: 'merchant-payid@bank.com.au',
  settings: {
    notificationsEnabled: true
  }
});
```

4. **Configure webhook**: Ensure Global Payments webhook points to Firebase function
5. **Test end-to-end**: Complete test transaction

## Advanced: Dynamic PayID Configuration

To make PayID dynamic per merchant, modify `src/Checkout.jsx`:

```javascript
// Add at top with other hooks
const [merchantPayId, setMerchantPayId] = useState('');

// Add useEffect to fetch merchant PayID
useEffect(() => {
  async function fetchMerchantConfig() {
    try {
      // Get shop domain from Shopify
      const shopDomain = await query('shop { myshopifyDomain }');

      // Fetch from Firebase
      const response = await fetch(`${FIREBASE_FUNCTION_URL}/getMerchantConfig`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ shopDomain: shopDomain.data.shop.myshopifyDomain })
      });

      const config = await response.json();
      setMerchantPayId(config.payId);
    } catch (error) {
      console.error('Failed to fetch merchant config:', error);
      // Fallback to default
      setMerchantPayId(MERCHANT_PAYID);
    }
  }

  fetchMerchantConfig();
}, []);

// Then use merchantPayId instead of MERCHANT_PAYID throughout
```

Create the Firebase function:

```javascript
exports.getMerchantConfig = functions.https.onRequest(async (req, res) => {
  const { shopDomain } = req.body;

  const merchant = await db.collection('merchants')
    .where('shopifyStoreId', '==', shopDomain)
    .limit(1)
    .get();

  if (merchant.empty) {
    return res.status(404).json({ error: 'Merchant not found' });
  }

  const data = merchant.docs[0].data();
  return res.json({
    payId: data.payId,
    businessName: data.profile.businessName
  });
});
```

## Troubleshooting

**Q: Extension doesn't show up in checkout**
A: Verify checkout extensibility is enabled (Shopify Plus required)

**Q: QR code shows broken image**
A: Check `network_access = true` in `shopify.extension.toml`

**Q: Verification always fails**
A: Check Firebase function URL is correct and functions are deployed

**Q: Checkout completes without payment**
A: Ensure `useBuyerJourneyIntercept` is working (check Shopify Plus status)

## Next Steps

1. Review full documentation in `DOCUMENTATION.md`
2. Test with real PayID payment (small amount)
3. Monitor Firebase function logs during testing
4. Set up production Global Payments webhook
5. Train merchant on payment flow
