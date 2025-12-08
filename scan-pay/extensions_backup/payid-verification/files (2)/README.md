# Scan & Pay - Shopify Payment System

Complete documentation and source code for the 5-terminal PayID payment system.

## 📦 What's Included

This package contains all the code and documentation for the complete Scan & Pay system that we built together:

### Documentation
- **CLAUDE.md** - Complete system documentation with architecture, code examples, and deployment guide
- **README.md** - This file (quick start guide)

### Code Files
- **payid-qr-payment.html** - Standalone QR code payment page
- **shopify-buyer-checkout.html** - Complete Shopify client checkout flow
- **global-payments-webhook.js** - Firebase Cloud Function for webhook handling

### Referenced Chats
All code was developed across multiple chat sessions. Links to each chat are in CLAUDE.md under "Chat History References".

---

## 🏗️ System Architecture

### The 5-Terminal System

```
Terminal 1: Core API (Authentication & OTP)
Terminal 2: Shopify Merchant Backend
Terminal 3: Firebase Data Layer
Terminal 4: Payment Verification API ← The Innovation
Terminal 5: Shopify Client/Buyer Frontend
```

**Key Innovation**: Terminal 4 is a dedicated API that ONLY verifies payments. It doesn't process them - it just checks with Global Payments if a payment was received and returns one of 3 states:
- `paid` - Payment confirmed
- `unpaid` - No payment received
- `pending` - Payment initiated but not settled

---

## 🚀 Quick Start

### 1. Read the Documentation

Start with **CLAUDE.md** - it contains everything:
- Complete architecture explanation
- All code with comments
- Firebase setup instructions
- Global Payments webhook configuration
- Deployment guide
- Testing procedures

### 2. Set Up Firebase

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize project
firebase init
```

### 3. Deploy Cloud Functions

```bash
# Copy global-payments-webhook.js to your functions directory
cp global-payments-webhook.js your-project/functions/

# Install dependencies
cd your-project/functions
npm install firebase-functions firebase-admin

# Deploy
firebase deploy --only functions
```

### 4. Configure Environment

```bash
# Set Global Payments private key
firebase functions:config:set globalpayments.private_key="YOUR_KEY"

# Set Twilio credentials (for SMS OTP)
firebase functions:config:set \
  twilio.account_sid="YOUR_SID" \
  twilio.auth_token="YOUR_TOKEN" \
  twilio.phone_number="+61XXXXXXXXX"

# View all config
firebase functions:config:get
```

### 5. Configure Global Payments Webhook

1. Login to https://docs.gpaunz.com
2. Go to Webhooks → Create Subscription
3. Enter your Cloud Function URL:
   ```
   https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook
   ```
4. Select event type: `transactions`
5. Save and note your Private Key
6. Add Private Key to Firebase config (see step 4)

### 6. Test the System

```bash
# Test webhook receiver
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook \
  -H "Content-Type: application/json" \
  -d @test-webhook.json

# Test payment verification
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/verifyPayment \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "REF-2024-TEST123",
    "amount": 150.00,
    "payId": "payments@test.com.au"
  }'
```

---

## 📁 File Descriptions

### CLAUDE.md
**The Master Document** - Contains:
- Complete system architecture
- All 5 terminals explained in detail
- Code for every component
- Firebase schema
- Global Payments webhook integration
- Reference generation logic
- QR code implementation
- Deployment instructions
- Testing procedures
- Links to all chat history

**Start here** if you want to understand the entire system.

### payid-qr-payment.html
Standalone payment page that displays:
- Total amount
- PayID email (clickable to copy)
- Payment reference (clickable to copy)
- QR code for scanning
- Step-by-step payment instructions

**Use case**: Embed in any website for quick PayID payments

### shopify-buyer-checkout.html
Complete checkout flow for Shopify buyers:
- Shopping cart summary
- Address collection form
- QR code generation
- Payment verification polling
- Success/error handling

**Use case**: Main checkout page for Shopify store customers

### global-payments-webhook.js
Firebase Cloud Functions for:
- Receiving Global Payments webhooks
- Verifying webhook signatures
- Storing transactions in Firestore
- Updating order statuses
- Payment verification API endpoint

**Use case**: Backend processing for all payments

---

## 🔑 Key Concepts

### Reference Generation

We use **crypto.getRandomValues()** instead of Math.random() for:
- True randomness
- Cryptographic security
- Unpredictable references
- Prevents collision attacks

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
    
    return reference; // e.g., REF-2024-A3K9N7P4X2M8
}
```

### Amount Handling

**CRITICAL**: Global Payments sends amounts in CENTS, not dollars!

```javascript
// Webhook receives:
const amountCents = 15000; // From Global Payments

// Convert for display:
const amountDollars = amountCents / 100; // $150.00

// When comparing:
if (webhookAmount === cartTotal * 100) {
    // Amounts match!
}
```

### Payment Status States

The system uses 3 states:

```javascript
const PAYMENT_STATUS = {
  PAID: 'paid',        // Payment confirmed, verified
  UNPAID: 'unpaid',    // No payment or declined
  PENDING: 'pending'   // Payment initiated, not settled
};
```

Terminal 4 (Payment Verification API) returns ONLY these 3 values.

---

## 🎯 How It Works

### Buyer Flow

```
1. Buyer adds products to cart
   ↓
2. Clicks "Checkout with Scan & Pay"
   ↓
3. Enters delivery address
   ↓
4. System generates unique reference (REF-2024-XXXXXX)
   ↓
5. QR code displayed with:
   - Amount: $150.00
   - PayID: payments@merchant.com.au
   - Reference: REF-2024-ABC123
   ↓
6. Buyer scans QR with banking app
   ↓
7. Buyer completes payment in bank
   ↓
8. Global Payments sends webhook to our system
   ↓
9. We store transaction and update order status
   ↓
10. Buyer clicks "I've Paid" button
    ↓
11. System calls Terminal 4 to verify
    ↓
12. Terminal 4 queries Firebase and returns: paid/unpaid/pending
    ↓
13. If "paid": Order confirmed!
    If "pending": Keep polling
    If "unpaid": Show error
```

### Technical Flow

```
┌─────────────────────┐
│  Buyer pays via     │
│  Banking App        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Global Payments    │
│  Processes Payment  │
└──────────┬──────────┘
           │
           │ Webhook (POST)
           ▼
┌─────────────────────────────────────┐
│  Terminal 4: Cloud Function         │
│  globalPaymentsWebhook()            │
│                                     │
│  1. Verify signature                │
│  2. Extract transaction data        │
│  3. Store in Firestore              │
│  4. Update order status             │
└─────────────────────────────────────┘
           │
           ▼
┌─────────────────────┐
│  Firebase           │
│  (Transaction DB)   │
└─────────────────────┘
           │
           │ Query
           ▼
┌─────────────────────────────────────┐
│  Terminal 4: Verification API       │
│  verifyPayment()                    │
│                                     │
│  1. Query transaction by reference  │
│  2. Check amount matches            │
│  3. Return paid/unpaid/pending      │
└──────────┬──────────────────────────┘
           │
           ▼
┌─────────────────────┐
│  Terminal 5:        │
│  Buyer Frontend     │
│  (Order confirm)    │
└─────────────────────┘
```

---

## 📚 Chat History

All code was developed across multiple conversations. CLAUDE.md contains links to every relevant chat under "Chat History References".

**Key Chats:**
- Main Implementation: https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24
- Shopify Integration: https://claude.ai/chat/acdc4a46-19b9-4cd8-a42d-1e3354da2982
- Webhook Setup: https://claude.ai/chat/aa565c61-6951-4f5e-978b-77d99febe32e
- Payment Verification: https://claude.ai/chat/977ab5bd-04c0-4fea-8217-ccc56d3dd5c6

---

## 🔧 Configuration Checklist

Before deploying, ensure you have:

- [ ] Firebase project created
- [ ] Firebase CLI installed and authenticated
- [ ] Global Payments account with Oceania API access
- [ ] PayID credentials for testing
- [ ] Twilio account (for SMS OTP)
- [ ] SendGrid account (for Email OTP)
- [ ] Shopify store (for production)
- [ ] Domain name (optional)

---

## 🧪 Testing

### Local Testing

```bash
# Start Firebase emulators
firebase emulators:start

# Test functions locally
http://localhost:5001/YOUR-PROJECT/us-central1/verifyPayment
```

### Production Testing

Use test data from Global Payments:
- Test PayID: provided by GP
- Test amounts: $1.00, $10.00, etc.
- Test references: REF-2024-TEST001

---

## 🐛 Troubleshooting

### Webhook Not Received

1. Check webhook URL in Global Payments dashboard
2. Verify Cloud Function is deployed: `firebase functions:list`
3. Check function logs: `firebase functions:log`
4. Test with curl (see Testing section)

### Payment Not Verifying

1. Check transaction stored in Firebase: `firebase firestore:get transactions`
2. Verify amount is in cents (multiply by 100)
3. Check reference matches exactly (case-sensitive)
4. Confirm webhook was received: check logs

### OTP Not Sending

1. Verify Twilio/SendGrid credentials
2. Check phone number format: +61XXXXXXXXX
3. Check Firebase config: `firebase functions:config:get`
4. Review function logs for errors

---

## 📞 Support

For technical questions about this system:

1. **Read CLAUDE.md first** - It has answers to most questions
2. **Check chat history** - Links in CLAUDE.md
3. **Review Firebase logs** - Most errors are logged
4. **Test with curl** - Isolate the issue

---

## 🎓 Learning Resources

To understand this system better:

1. **Start with CLAUDE.md** - Complete documentation
2. **Firebase Documentation** - https://firebase.google.com/docs
3. **Global Payments API** - https://docs.gpaunz.com
4. **Shopify Storefront API** - https://shopify.dev/api/storefront
5. **PayID Specifications** - https://payid.com.au

---

## 📝 License

This code was developed collaboratively through multiple chat sessions with Claude.
Review CLAUDE.md for complete development history and chat references.

**Project**: Scan & Pay - Shopify Payment System  
**Company**: Senax Enterprises Pty Ltd  
**Created**: November-December 2024

---

## ✨ Credits

**Technologies Used:**
- Firebase (Backend & Auth)
- Shopify (E-commerce Platform)
- Global Payments Oceania (Payment Processing)
- QRCode.js (QR Generation)
- Twilio (SMS OTP)
- SendGrid (Email OTP)

**Developed with:** Claude (Anthropic)  
**Documentation:** Auto-generated from chat history

---

*For complete details, see CLAUDE.md*
