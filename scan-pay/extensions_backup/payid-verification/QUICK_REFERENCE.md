# PayID Checkout Extension - Quick Reference

## 🚀 Quick Start

```bash
# Deploy extension
cd C:\Shopify\scan-pay\extensions\payid-verification
npm run deploy

# Configure in Shopify Partner Dashboard
# Settings → PayID Verification → Configure:
# - Merchant PayID: your-payid@email.com
# - Merchant Name: Your Business Name
```

---

## 📋 API Endpoints

### Base URL
```
https://australia-southeast1-scan-and-pay-guihzm.cloudfunctions.net
```

### Generate QR Code
```javascript
POST /generatePayIDQR
{
  "payId": "merchant@example.com",
  "amount": 125.50,
  "reference": "REF-2024-ABC123",
  "merchantName": "My Store"
}
```

### Verify Payment
```javascript
GET /verifyPayment?reference={ref}&amount={cents}&payId={payid}
// Returns: { status: 'paid' | 'unpaid' | 'pending' }
```

---

## 🗄️ Firestore Collections

```
/payments/{paymentId}         - Payment records
/transactions/{webhookId}     - Webhook transaction data
/users/{userId}               - User/merchant profiles
/orders/{orderId}             - Order records
```

---

## ⚙️ Extension Settings

| Setting | Type | Required | Default | Example |
|---------|------|----------|---------|---------|
| `merchant_payid` | string | Yes | - | `pay@store.com.au` |
| `merchant_name` | string | Yes | - | `My Store Pty Ltd` |
| `firebase_project_id` | string | No | `scan-and-pay-guihzm` | - |
| `enable_manual_entry` | boolean | No | `true` | - |

---

## 🔐 Security

**Webhook Signature**:
- Algorithm: HMAC SHA-256
- Secret: Stored in Google Cloud Secret Manager
- Header: `X-GP-Signature`

**Amount Validation**:
- Exact match required (to the cent)
- Convert to cents: `Math.round(amount * 100)`

---

## 🧪 Testing

### Test Payment
```bash
# 1. Create order ($0.50 recommended)
# 2. Scan QR code with banking app
# 3. Complete payment
# 4. Click "I've Paid"
# 5. Verify order completes
```

### Check Logs
```bash
firebase functions:log --only verifyPayment
firebase functions:log --only generatePayIDQR
```

### Query Firestore
```javascript
// Check recent payments
db.collection('payments')
  .orderBy('createdAt', 'desc')
  .limit(10)
  .get()

// Find by reference
db.collection('transactions')
  .where('reference', '==', 'REF-2024-ABC123')
  .get()
```

---

## 🐛 Common Issues

### QR Code Not Showing
- ✅ Check `network_access = true` in `shopify.extension.toml`
- ✅ Verify Firebase URL is correct
- ✅ Test with curl: `curl -X POST {GENERATE_QR_URL}`

### Payment Verification Fails
- ✅ Check Firestore `/transactions` collection
- ✅ Verify webhook received (check logs)
- ✅ Confirm amount in cents: `12550` = $125.50

### Checkout Blocked
- ✅ Check `payid_status` order attribute
- ✅ Verify payment status state updated
- ✅ Review browser console errors

---

## 📊 Order Attributes

After payment confirmation, these attributes are stored:

```javascript
{
  payid_reference: "REF-2024-ABC123",
  payid_transaction_id: "txn_xyz789",
  payid_status: "paid",
  payid_amount_cents: "12550"
}
```

Access in Shopify Admin:
`Orders → [Order] → Additional Details → Custom Attributes`

---

## 📞 Support

| Issue Type | Response Time | Contact |
|------------|---------------|---------|
| Critical (payment down) | <1 hour | 1800 SCAN PAY |
| High (checkout error) | <4 hours | merchant-support@scanandpay.com.au |
| Normal (general) | <24 hours | developer@scanandpay.com.au |

---

## 🔧 Key Files

```
src/Checkout.jsx              - Main component
shopify.extension.toml        - Extension config
INTEGRATION_GUIDE.md          - Technical docs
MERCHANT_SETUP.md             - Setup guide
INTEGRATION_SUMMARY.md        - Overview
```

---

## 🎯 Payment Flow (40 seconds typical)

```
00s: Customer clicks "Pay with PayID"
01s: QR code generated
15s: Customer scans QR
30s: Customer confirms in bank
35s: NPP processes payment (instant)
36s: Global Payments webhook sent
38s: Extension verifies payment ✓
39s: Checkout proceeds
```

---

## 💰 Pricing

**Global Payments Fee**: 0.5% + $0.10 per transaction

Examples:
- $10 order → $0.15 fee
- $100 order → $0.60 fee
- $1,000 order → $5.10 fee

---

## ✅ Pre-Launch Checklist

- [ ] Extension deployed to production
- [ ] Merchant settings configured
- [ ] Test order completed successfully
- [ ] Webhook receiving payments
- [ ] Firestore transactions logging
- [ ] Error monitoring set up
- [ ] Support contact info added
- [ ] Customer instructions clear
- [ ] Bank account verified
- [ ] PayID active and tested

---

## 📈 Monitoring

### Firebase Console
```
https://console.firebase.google.com/project/scan-and-pay-guihzm
```

### Key Metrics
- Payment success rate (target: >95%)
- Verification time (target: <10s)
- QR generation success (target: >99%)
- Webhook delivery (target: >99%)

---

## 🔄 Version

**Current**: v1.0.0
**Last Updated**: 2024-12-05
**Shopify API**: 2025-07
**UI Extensions**: 2025.7.0
**Node.js**: 20.x

---

## 📚 Links

- [Shopify Extensions Docs](https://shopify.dev/docs/api/checkout-ui-extensions)
- [Firebase Functions](https://firebase.google.com/docs/functions)
- [Global Payments API](https://developer.globalpay.com/oceania)
- [PayID Official](https://payid.com.au)

---

**Ready to launch!** 🚀
