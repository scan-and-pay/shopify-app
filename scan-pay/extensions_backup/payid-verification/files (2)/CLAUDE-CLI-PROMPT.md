# Claude CLI Project Brief: Scan & Pay - Shopify PayID Payment System

## Project Overview

**What We're Building:**
A Shopify payment plugin that enables merchants to accept PayID payments via QR codes. The system uses a unique 5-terminal architecture where payment VERIFICATION is separated from payment PROCESSING.

**Company:** Senax Enterprises Pty Ltd (trading as Scan & Pay)  
**Target Market:** Australian Shopify merchants  
**Payment Method:** PayID (Australian instant bank transfer system)  
**Payment Processor:** Global Payments Oceania (existing partnership)

---

## The 5-Terminal Architecture

This is the core innovation - we separate concerns across 5 independent terminals:

```
Terminal 1: Core API
├── Authentication (login/logout)
├── OTP generation & verification (SMS + Email)
├── PIN code management
└── User session handling

Terminal 2: Shopify Merchant Backend
├── Plugin installation flow
├── Merchant onboarding (collect PayID, address)
├── Dashboard (sales, orders, analytics)
└── Settings (PIN, notifications, webhooks)

Terminal 3: Firebase Data Layer
├── Firestore (database)
├── Firebase Auth (authentication)
├── Cloud Functions (backend API)
└── Real-time updates

Terminal 4: Payment Verification API ⭐ THE INNOVATION
├── Single responsibility: Verify if payment was received
├── Does NOT process payments - only CHECKS them
├── Returns ONLY 3 states: paid | unpaid | pending
├── Queries Firebase transactions
└── Called by Terminal 5 after buyer pays

Terminal 5: Shopify Client/Buyer Frontend
├── Product display (from Shopify)
├── Shopping cart
├── QR code generation
├── Checkout form (delivery address)
└── Payment verification polling
```

---

## Why This Architecture?

**Problem:** Traditional payment systems combine processing AND verification.

**Our Solution:** Separate them completely.

- **Terminal 4 doesn't process payments** - Global Payments does that
- **Terminal 4 only verifies** - Did the merchant receive the money? Yes/No/Pending
- This makes the system:
  - More reliable (verification independent of processing)
  - Easier to scale (can scale verification separately)
  - Simpler to debug (isolated concerns)
  - Vendor-agnostic (can switch processors easily)

---

## Technical Stack

**Backend:**
- Firebase (Firestore, Auth, Cloud Functions)
- Node.js (Cloud Functions)
- Global Payments Oceania API

**Frontend:**
- HTML5, CSS3, JavaScript (ES6+)
- QRCode.js (for QR generation)
- Firebase SDK (web)
- Shopify Storefront API

**Authentication:**
- Firebase Auth (Phone, Email)
- Twilio (SMS OTP)
- SendGrid (Email OTP)
- Custom PIN codes (hashed with SHA-256)

**Payment Processing:**
- Global Payments Oceania Single API
- PayID (Australian instant transfers)
- Webhook integration (for real-time notifications)

---

## Key Components & Current State

### 1. Reference Generation System

**Purpose:** Generate unique payment references for each transaction

**Implementation:**
```javascript
function generatePaymentReference() {
    // Use crypto.getRandomValues() for true randomness
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // No confusing chars
    const length = 12;
    let reference = 'REF-2024-';
    
    const array = new Uint8Array(length);
    crypto.getRandomValues(array); // NOT Math.random()
    
    for (let i = 0; i < length; i++) {
        reference += chars[array[i] % chars.length];
    }
    
    return reference; // e.g., REF-2024-A3K9N7P4X2M8
}
```

**Why crypto?**
- True randomness (not pseudo-random)
- Cryptographically secure
- Same standard as OTP generation
- Prevents collision attacks

### 2. Global Payments Webhook Integration

**What They Send:**
```json
{
  "id": "webhook-id",
  "reference": "REF-2024-ABC123",
  "created": "2023-01-01T02:02:48Z",
  "event": "transactions",
  "payload": {
    "id": "transaction-id",
    "payment": {
      "amount": 15000,  // ⚠️ IN CENTS, NOT DOLLARS
      "currencyCode": "AUD"
    },
    "result": {
      "status": "approved"  // or "declined" or "pending"
    }
  }
}
```

**What We Extract:**
- Transaction ID: `payload.id`
- Amount (cents): `payload.payment.amount`
- Status: `payload.result.status`
- Our reference: `reference`

**Critical:** Amount is ALWAYS in cents. $150.00 = 15000 cents.

### 3. Payment Verification Flow

```
1. Buyer adds products to cart (Terminal 5)
   ↓
2. Generates reference: REF-2024-XXXXXX (crypto-based)
   ↓
3. Displays QR code with:
   - Amount: $150.00
   - PayID: merchant@example.com.au
   - Reference: REF-2024-XXXXXX
   ↓
4. Buyer scans QR → pays in banking app
   ↓
5. Global Payments receives payment → sends webhook
   ↓
6. Our webhook handler (Terminal 4) stores transaction in Firebase
   ↓
7. Buyer clicks "I've Paid" button (Terminal 5)
   ↓
8. Frontend calls verifyPayment API (Terminal 4)
   ↓
9. Terminal 4 queries Firebase:
   - Find transaction by reference
   - Check amount matches (convert to cents!)
   - Check status from Global Payments
   ↓
10. Return one of 3 states:
    - paid: Payment confirmed ✅
    - unpaid: No payment or declined ❌
    - pending: Payment initiated, not settled ⏳
```

---

## Current Code Files

We have these files ready:

**Backend:**
- `global-payments-webhook.js` - Cloud Function
  - Receives Global Payments webhooks
  - Verifies webhook signatures (HMAC SHA-256)
  - Stores transactions in Firestore
  - Provides verifyPayment API endpoint
  - Updates order statuses

**Frontend:**
- `payid-qr-payment.html` - Standalone QR payment page
  - Displays amount, PayID, reference
  - Generates QR code
  - Click-to-copy functionality
  
- `shopify-buyer-checkout.html` - Complete checkout flow
  - Shopping cart display
  - Address collection form
  - QR code generation
  - Payment verification polling
  - Success/error handling

**Documentation:**
- `CLAUDE.md` - Complete system documentation
- `README.md` - Quick start guide
- `DEPLOYMENT-CHECKLIST.md` - Step-by-step deployment
- `QUICK-REFERENCE.md` - Essential reference card

---

## Firebase Schema

**Firestore Collections:**

```javascript
/merchants/{merchantId}
{
  shopifyStoreId: "store.myshopify.com",
  userId: "firebase-auth-uid",
  profile: {
    businessName: string,
    payId: "payments@example.com.au",
    email: string,
    phone: "+61400000000",
    address: { street, city, state, postcode }
  },
  settings: {
    pinEnabled: boolean,
    pinHash: "sha256-hash",
    notificationsEnabled: boolean
  },
  createdAt: timestamp
}

/products/{productId}
{
  name: string,
  price: number,
  sku: string,
  merchantId: string,
  shopifyProductId: string,
  images: [urls],
  stock: number
}

/orders/{orderId}
{
  orderId: "ORD-XXXXXXXX",
  merchantId: string,
  customer: { name, email, phone, address },
  items: [{ productId, name, price, quantity }],
  total: number,
  paymentMethod: "payid",
  paymentRef: "REF-2024-XXXXXX",
  paymentStatus: "pending" | "PAID" | "DECLINED",
  orderStatus: "pending" | "processing" | "completed",
  createdAt: timestamp
}

/transactions/{transactionId}
{
  transactionId: string,  // From Global Payments
  reference: "REF-2024-XXXXXX",  // Our reference
  orderId: "ORD-XXXXXXXX",
  merchantId: string,
  amount: number,  // IN CENTS
  currencyCode: "AUD",
  status: "approved" | "declined" | "pending",
  verified: boolean,
  webhookId: string,
  globalPaymentsData: { ... },  // Full webhook payload
  createdDateTime: timestamp,
  receivedAt: timestamp
}

/otps/{identifier}  // identifier = phone or email
{
  otp: string,  // 6-digit code
  type: "sms" | "email",
  attempts: number,  // Max 3
  createdAt: timestamp,
  expiresAt: timestamp,  // 5 minutes
  verified: boolean
}
```

---

## Environment Configuration

**Firebase Functions Config:**

```bash
# Global Payments
globalpayments.private_key="YOUR_WEBHOOK_PRIVATE_KEY"
globalpayments.api_key="YOUR_API_KEY"

# Twilio (SMS OTP)
twilio.account_sid="ACXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
twilio.auth_token="your_auth_token"
twilio.phone_number="+61XXXXXXXXX"

# SendGrid (Email OTP)
sendgrid.api_key="SG.XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
sendgrid.from_email="noreply@scanandpay.com.au"
```

---

## API Endpoints (Cloud Functions)

**Authentication:**
```
POST /sendSMSOTP
Body: { phoneNumber: "+61400000000" }
Response: { success: true, expiresIn: 300 }

POST /sendEmailOTP
Body: { email: "user@example.com" }
Response: { success: true, expiresIn: 300 }

POST /verifyOTP
Body: { identifier: "+61400000000", otp: "123456" }
Response: { success: true, message: "OTP verified" }
```

**Payment Processing:**
```
POST /globalPaymentsWebhook
Headers: { X-Signature: "hmac-sha256-signature" }
Body: { id, reference, payload: { ... } }
Response: { success: true, webhookId, verified }

POST /verifyPayment
Body: { 
  reference: "REF-2024-ABC123",
  amount: 150.00,
  payId: "merchant@example.com.au"
}
Response: {
  status: "paid" | "unpaid" | "pending",
  verified: boolean,
  transactionId: string,
  amount: number
}
```

---

## Critical Implementation Details

### 1. Amount Handling
```javascript
// ALWAYS work in CENTS internally
const cartTotal = 150.00; // dollars
const expectedAmount = cartTotal * 100; // 15000 cents

// Webhook receives cents
const webhookAmount = 15000; // from Global Payments

// Compare
if (webhookAmount === expectedAmount) {
    // Amounts match ✅
}

// Display to user (convert to dollars)
const displayAmount = webhookAmount / 100; // $150.00
```

### 2. Webhook Signature Verification
```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, privateKey) {
    const hmac = crypto.createHmac('sha256', privateKey);
    hmac.update(JSON.stringify(payload));
    const calculatedSignature = hmac.digest('hex');
    return calculatedSignature === signature;
}

// In webhook handler
const signature = req.headers['x-signature'];
const isValid = verifyWebhookSignature(req.body, signature, GP_PRIVATE_KEY);
if (!isValid) {
    return res.status(401).json({ error: 'Invalid signature' });
}
```

### 3. OTP Generation
```javascript
// Use crypto, NOT Math.random()
function generateOTP(length = 6) {
    return crypto.randomInt(100000, 999999).toString();
}

// Store with expiry
await db.collection('otps').doc(phoneNumber).set({
    otp: generatedOTP,
    type: 'sms',
    attempts: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: new Date(Date.now() + 5 * 60 * 1000), // 5 min
    verified: false
});
```

---

## Common Tasks You Might Help With

### Add New Cloud Function
```bash
# In functions/index.js
exports.newFunction = functions.https.onRequest(async (req, res) => {
    // Your code
});

# Deploy
firebase deploy --only functions:newFunction
```

### Update Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /merchants/{merchantId} {
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
    }
  }
}
```

### Test Webhook Locally
```bash
curl -X POST http://localhost:5001/PROJECT/us-central1/globalPaymentsWebhook \
  -H "Content-Type: application/json" \
  -d @test-webhook.json
```

---

## Development Workflow

1. **Local Development:**
   ```bash
   firebase emulators:start
   # Functions: http://localhost:5001
   # Firestore: http://localhost:8080
   ```

2. **Testing:**
   ```bash
   # Test specific function
   curl -X POST http://localhost:5001/.../functionName -d '{...}'
   
   # View logs
   firebase functions:log
   ```

3. **Deployment:**
   ```bash
   # Deploy all
   firebase deploy
   
   # Deploy specific
   firebase deploy --only functions:functionName
   firebase deploy --only firestore:rules
   ```

---

## Known Issues & Solutions

### Issue: Webhook not received
**Solution:**
1. Check function deployed: `firebase functions:list`
2. Verify URL in Global Payments dashboard
3. Check logs: `firebase functions:log --only globalPaymentsWebhook`
4. Test with curl

### Issue: Payment not verifying
**Solution:**
1. Check amount is in CENTS (multiply by 100)
2. Verify reference matches exactly (case-sensitive)
3. Check transaction exists in Firebase
4. Confirm webhook was received (check logs)

### Issue: OTP not sending
**Solution:**
1. Verify Twilio/SendGrid credentials
2. Check phone format: +61XXXXXXXXX (must include +61)
3. Check Firebase config: `firebase functions:config:get`
4. Review function logs for errors

---

## Project Structure

```
scanandpay-shopify/
├── functions/
│   ├── index.js (global-payments-webhook.js)
│   ├── package.json
│   └── node_modules/
├── public/
│   ├── index.html
│   ├── payid-qr-payment.html
│   └── shopify-buyer-checkout.html
├── docs/
│   ├── CLAUDE.md
│   ├── README.md
│   ├── DEPLOYMENT-CHECKLIST.md
│   └── QUICK-REFERENCE.md
├── firebase.json
├── firestore.rules
├── .firebaserc
└── .gitignore
```

---

## Your Role (Claude CLI)

You can help with:
1. **Code Implementation** - Write new features, fix bugs
2. **Cloud Functions** - Create/modify backend APIs
3. **Frontend Development** - Update HTML/JS/CSS
4. **Firebase Configuration** - Security rules, indexes
5. **Testing** - Write tests, debug issues
6. **Documentation** - Update docs, add comments
7. **Deployment** - Help with deployment scripts
8. **Troubleshooting** - Debug errors, analyze logs

When working on this project:
- **Always use crypto.getRandomValues()** for random generation (not Math.random())
- **Always work in CENTS** for amounts internally
- **Always verify webhook signatures** before processing
- **Reference CLAUDE.md** for detailed documentation
- **Follow the 5-terminal architecture** - keep concerns separated

---

## Quick Commands Reference

```bash
# View config
firebase functions:config:get

# Deploy functions
firebase deploy --only functions

# View logs
firebase functions:log

# Test locally
firebase emulators:start

# Set config
firebase functions:config:set key="value"

# List functions
firebase functions:list
```

---

## Important Links

**Documentation:**
- Complete docs: See CLAUDE.md
- Quick ref: See QUICK-REFERENCE.md
- Deployment: See DEPLOYMENT-CHECKLIST.md

**External APIs:**
- Global Payments: https://docs.gpaunz.com
- Firebase: https://firebase.google.com/docs
- Shopify Storefront API: https://shopify.dev/api/storefront
- PayID: https://payid.com.au

**Development Chat History:**
- Main implementation: https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24
- Shopify integration: https://claude.ai/chat/acdc4a46-19b9-4cd8-a42d-1e3354da2982
- Webhook setup: https://claude.ai/chat/aa565c61-6951-4f5e-978b-77d99febe32e

---

## Summary

This is a **5-terminal Shopify payment system** using **PayID** and **Global Payments Oceania**. 

The key innovation is **Terminal 4** - a dedicated API that ONLY verifies payments (doesn't process them) and returns one of 3 states: paid, unpaid, or pending.

All code uses **crypto-based random generation** (same as OTP), amounts are **always in CENTS internally**, and webhooks are **signature-verified** for security.

You have access to complete code files and documentation. Start with CLAUDE.md for full details.

**Ready to help build, debug, or deploy!** 🚀
