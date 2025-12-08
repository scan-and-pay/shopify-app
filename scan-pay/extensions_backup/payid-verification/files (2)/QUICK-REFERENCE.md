# 📋 Quick Reference Card

Essential information for the Scan & Pay system. Keep this handy!

---

## 🏗️ The 5 Terminals

```
Terminal 1: Core API          → Authentication (OTP, PIN, Login/Logout)
Terminal 2: Shopify Backend   → Merchant dashboard & settings
Terminal 3: Firebase          → Database & cloud functions
Terminal 4: Verification API  → Payment status (paid/unpaid/pending)
Terminal 5: Shopify Frontend  → Buyer checkout with QR codes
```

---

## 🔑 Key Endpoints

### Cloud Functions

```
POST /globalPaymentsWebhook
     → Receives webhooks from Global Payments
     → Stores transactions in Firebase
     
POST /verifyPayment
     → Checks payment status
     → Returns: paid | unpaid | pending
     
POST /sendSMSOTP
     → Sends SMS verification code
     
POST /verifyOTP
     → Validates OTP code
```

---

## 💰 Payment States

```javascript
'paid'     // ✅ Payment confirmed and verified
'unpaid'   // ❌ No payment received or declined  
'pending'  // ⏳ Payment initiated, awaiting settlement
```

---

## 🎯 Reference Generation

```javascript
function generatePaymentReference() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const length = 12;
    let reference = 'REF-2024-';
    
    const array = new Uint8Array(length);
    crypto.getRandomValues(array);
    
    for (let i = 0; i < length; i++) {
        reference += chars[array[i] % chars.length];
    }
    
    return reference; // REF-2024-A3K9N7P4X2M8
}
```

**Why crypto?** True randomness, unpredictable, secure

---

## 💸 Amount Handling

⚠️ **CRITICAL**: Global Payments uses CENTS, not dollars!

```javascript
// Webhook receives CENTS
const webhookAmount = 15000; // From Global Payments

// Convert to dollars for display
const displayAmount = webhookAmount / 100; // $150.00

// When comparing cart total
if (webhookAmount === cartTotal * 100) {
    // Amounts match!
}
```

---

## 📦 Global Payments Webhook

### Webhook Payload

```json
{
  "id": "webhook-id",
  "reference": "REF-2024-ABC123",
  "payload": {
    "id": "transaction-id",
    "payment": {
      "amount": 15000,  // ⚠️ CENTS
      "currencyCode": "AUD"
    },
    "result": {
      "status": "approved"  // or "declined", "pending"
    }
  }
}
```

### What We Extract

```javascript
const transactionId = payload.id;
const amount = payload.payment.amount;        // CENTS
const status = payload.result.status;         // approved/declined/pending
const verified = (status === 'approved');     // true/false
```

---

## 🔐 Environment Variables

### Firebase Functions Config

```bash
# Global Payments
firebase functions:config:set \
  globalpayments.private_key="YOUR_KEY"

# Twilio (SMS)
firebase functions:config:set \
  twilio.account_sid="YOUR_SID" \
  twilio.auth_token="YOUR_TOKEN" \
  twilio.phone_number="+61XXXXXXXXX"

# SendGrid (Email)
firebase functions:config:set \
  sendgrid.api_key="YOUR_KEY" \
  sendgrid.from_email="noreply@example.com"

# View config
firebase functions:config:get
```

---

## 🧪 Testing Commands

### Test Webhook

```bash
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook \
  -H "Content-Type: application/json" \
  -d '{
    "id": "test-001",
    "reference": "REF-2024-TEST",
    "payload": {
      "id": "txn-123",
      "payment": {"amount": 15000, "currencyCode": "AUD"},
      "result": {"status": "approved"}
    }
  }'
```

### Test Verification

```bash
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/verifyPayment \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "REF-2024-TEST",
    "amount": 150.00,
    "payId": "test@example.com"
  }'
```

### View Logs

```bash
# All functions
firebase functions:log

# Specific function
firebase functions:log --only verifyPayment

# Errors only
firebase functions:log --severity error
```

---

## 📱 QR Code Generation

```javascript
// Using QRCode.js
new QRCode(document.getElementById("qrcode"), {
    text: `PayID: ${payId}\nAmount: $${amount}\nReference: ${ref}`,
    width: 200,
    height: 200,
    colorDark: "#000000",
    colorLight: "#ffffff",
    correctLevel: QRCode.CorrectLevel.H  // High error correction
});
```

---

## 🔍 Firestore Schema

```
/merchants/{merchantId}
  - profile
  - settings
  - payId
  
/products/{productId}
  - name
  - price
  - sku
  
/orders/{orderId}
  - orderId: "ORD-XXXXXXXX"
  - paymentRef: "REF-2024-XXXXXX"
  - paymentStatus: "pending" | "PAID" | "DECLINED"
  - total
  
/transactions/{transactionId}
  - transactionId
  - reference
  - amount (cents)
  - status: "approved" | "declined" | "pending"
  - verified: true | false
```

---

## 🚀 Deployment

### Quick Deploy

```bash
# Deploy everything
firebase deploy

# Functions only
firebase deploy --only functions

# Firestore rules only
firebase deploy --only firestore:rules

# Specific function
firebase deploy --only functions:verifyPayment
```

### After Deploy

1. Get function URLs: `firebase functions:list`
2. Update Global Payments webhook URL
3. Test with curl commands
4. Check logs: `firebase functions:log`

---

## 🐛 Common Issues

### Issue: Webhook not received
**Solution:**
```bash
# 1. Check function deployed
firebase functions:list | grep globalPaymentsWebhook

# 2. Check logs
firebase functions:log --only globalPaymentsWebhook

# 3. Verify URL in GP dashboard
# 4. Test with curl
```

### Issue: Payment not verifying
**Solution:**
```bash
# 1. Check amount (cents vs dollars)
# Expected: 15000 (cents) = 150.00 (dollars)

# 2. Check reference matches exactly
# Case-sensitive!

# 3. Query Firestore
firebase firestore:get transactions
```

### Issue: OTP not sending
**Solution:**
```bash
# 1. Check config
firebase functions:config:get

# 2. Verify credentials in Twilio/SendGrid

# 3. Check logs
firebase functions:log --only sendSMSOTP
```

---

## 📞 Important URLs

```
Firebase Console:     https://console.firebase.google.com
Global Payments:      https://docs.gpaunz.com
Shopify Partners:     https://partners.shopify.com
Twilio:              https://console.twilio.com
SendGrid:            https://app.sendgrid.com
```

---

## 📚 Documentation Files

```
CLAUDE.md                → Complete system documentation
README.md                → Quick start guide
DEPLOYMENT-CHECKLIST.md  → Step-by-step deployment
QUICK-REFERENCE.md       → This file
```

---

## 🔗 Key Chats

All code developed in these conversations:

**Main Implementation:**
https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24
- Complete QR code system
- PayID integration
- OTP authentication
- Global Payments webhook

**Shopify Integration:**
https://claude.ai/chat/acdc4a46-19b9-4cd8-a42d-1e3354da2982
- Shopify Storefront API
- Cart and checkout
- Product management

**Webhook Setup:**
https://claude.ai/chat/aa565c61-6951-4f5e-978b-77d99febe32e
- Webhook configuration
- Event handling
- Payload structure

**Payment Processing:**
https://claude.ai/chat/977ab5bd-04c0-4fea-8217-ccc56d3dd5c6
- SoftPOS comparison
- Global Payments API
- Terminal integration

---

## ⚡ Emergency Commands

### Rollback Deployment

```bash
# List recent deployments
firebase functions:list

# Rollback to previous version
firebase functions:delete FUNCTION_NAME
firebase deploy --only functions:FUNCTION_NAME
```

### View Recent Errors

```bash
firebase functions:log --severity error --limit 10
```

### Test Everything

```bash
# Run all tests
npm test

# Start emulators
firebase emulators:start

# Test in browser
open http://localhost:5000
```

---

## 💡 Best Practices

1. **Always test in sandbox first**
   - Use Global Payments sandbox mode
   - Test with small amounts ($1.00)
   - Verify webhooks working

2. **Monitor logs actively**
   - Check Firebase logs daily
   - Set up error alerts
   - Review transaction data

3. **Keep backups**
   - Export Firestore data weekly
   - Backup environment config
   - Version control all code

4. **Security first**
   - Verify webhook signatures
   - Use environment variables
   - Never commit API keys
   - Enable Firestore security rules

5. **Document changes**
   - Comment all code
   - Update CLAUDE.md
   - Note breaking changes
   - Keep changelog

---

## 🎯 Success Metrics

Monitor these:
- ✅ Webhook delivery rate (should be 100%)
- ✅ Payment verification success rate
- ✅ Average verification time (< 5 seconds)
- ✅ OTP delivery rate
- ✅ Order completion rate

---

**Print this card and keep it visible while working!**

For complete details, see CLAUDE.md
