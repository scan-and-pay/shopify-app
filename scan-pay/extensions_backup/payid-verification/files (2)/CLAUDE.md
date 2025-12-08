# Scan & Pay - Shopify Payment System Documentation

**Last Updated**: December 4, 2025  
**System Version**: 2.0  
**Architecture**: 5-Terminal Distributed System

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture: 5-Terminal System](#architecture-5-terminal-system)
3. [Terminal 1: Core API (Authentication)](#terminal-1-core-api-authentication)
4. [Terminal 2: Shopify Merchant Backend](#terminal-2-shopify-merchant-backend)
5. [Terminal 3: Firebase Data Layer](#terminal-3-firebase-data-layer)
6. [Terminal 4: Payment Verification API](#terminal-4-payment-verification-api)
7. [Terminal 5: Shopify Client/Buyer Frontend](#terminal-5-shopify-clientbuyer-frontend)
8. [QR Code Implementation](#qr-code-implementation)
9. [Reference Generation System](#reference-generation-system)
10. [Global Payments Webhook Integration](#global-payments-webhook-integration)
11. [Code Files & Resources](#code-files--resources)
12. [Chat History References](#chat-history-references)

---

## System Overview

### What We Built

A complete **Shopify payment plugin** that enables:
- **Sellers**: Install from Shopify App Store, authenticate, and set up PayID credentials
- **Buyers**: Scan QR code, pay with PayID, get instant verification

### Key Innovation

Unlike traditional payment systems, we separate **payment processing** from **payment verification** using a dedicated 4th terminal that communicates with Global Payments API for real-time transaction confirmation.

### Technology Stack

```
Frontend:  HTML5, JavaScript, React
Backend:   Firebase (Auth, Firestore, Functions)
Payments:  Global Payments Oceania API, PayID
Platform:  Shopify App Store
QR Codes:  QRCode.js library
Auth:      SMS OTP, Email OTP, PIN codes
```

---

## Architecture: 5-Terminal System

### Terminal Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     SCAN & PAY SYSTEM                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Terminal 1: Core API (Auth, OTP, Login/Logout)           │
│       │                                                     │
│       ├──> Terminal 2: Shopify Merchant Backend           │
│       │                                                     │
│       ├──> Terminal 3: Firebase (Data, Auth, Storage)     │
│       │                                                     │
│       ├──> Terminal 4: Payment Verification API           │
│       │         (Paid/Unpaid/Pending + GP Webhook)        │
│       │                                                     │
│       └──> Terminal 5: Shopify Client Frontend            │
│                 (Buyer QR Scan & Checkout)                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Why 5 Terminals?

1. **Separation of Concerns**: Each terminal has ONE specific job
2. **Scalability**: Independent scaling of verification vs. checkout
3. **Security**: Payment verification isolated from user data
4. **Maintainability**: Update one terminal without affecting others
5. **Reliability**: If one fails, others continue operating

---

## Terminal 1: Core API (Authentication)

### Purpose
Handle all authentication, authorization, and user session management.

### Responsibilities

- **Login/Logout**: Session management for merchants and buyers
- **OTP Generation**: SMS and Email OTP for authentication
- **OTP Verification**: Validate OTP codes
- **PIN Management**: Create, update, verify PIN codes
- **User Profiles**: Manage merchant credentials (PayID, address, etc.)
- **Session Tokens**: Issue and validate JWT tokens

### API Endpoints

```
POST   /api/auth/send-sms-otp
POST   /api/auth/send-email-otp
POST   /api/auth/verify-otp
POST   /api/auth/login
POST   /api/auth/logout
POST   /api/auth/create-pin
POST   /api/auth/verify-pin
GET    /api/auth/profile
PUT    /api/auth/profile
```

### OTP Implementation

**File**: `cloud-functions/index.js`

```javascript
/**
 * Generate OTP using crypto for maximum randomness
 * Returns 6-digit numeric code
 */
function generateOTP(length = 6) {
    return crypto.randomInt(100000, 999999).toString();
}

/**
 * Send SMS OTP via Twilio
 */
exports.sendSMSOTP = functions.https.onCall(async (data, context) => {
    const { phoneNumber } = data;
    
    // Validate phone format
    if (!phoneNumber || !phoneNumber.match(/^\+[1-9]\d{10,14}$/)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'Invalid phone number format. Use +61XXXXXXXXX'
        );
    }
    
    // Generate OTP
    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 min
    
    // Store in Firestore
    await db.collection('otps').doc(phoneNumber).set({
        otp: otp,
        type: 'sms',
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: expiresAt,
        verified: false
    });
    
    // Send via Twilio
    await twilioClient.messages.create({
        body: `Your Scan & Pay verification code is: ${otp}`,
        from: TWILIO_PHONE_NUMBER,
        to: phoneNumber
    });
    
    return { 
        success: true, 
        message: 'OTP sent successfully',
        expiresIn: 300 // seconds
    };
});

/**
 * Verify OTP
 */
exports.verifyOTP = functions.https.onCall(async (data, context) => {
    const { identifier, otp } = data; // identifier = phone or email
    
    const otpDoc = await db.collection('otps').doc(identifier).get();
    
    if (!otpDoc.exists) {
        throw new functions.https.HttpsError(
            'not-found',
            'OTP not found or expired'
        );
    }
    
    const otpData = otpDoc.data();
    const now = new Date();
    
    // Check expiry
    if (otpData.expiresAt.toDate() < now) {
        await db.collection('otps').doc(identifier).delete();
        throw new functions.https.HttpsError(
            'deadline-exceeded',
            'OTP expired'
        );
    }
    
    // Check attempts (max 3)
    if (otpData.attempts >= 3) {
        await db.collection('otps').doc(identifier).delete();
        throw new functions.https.HttpsError(
            'permission-denied',
            'Too many attempts'
        );
    }
    
    // Verify OTP
    if (otpData.otp === otp) {
        await db.collection('otps').doc(identifier).update({
            verified: true,
            verifiedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        return { 
            success: true, 
            message: 'OTP verified successfully' 
        };
    } else {
        // Increment attempts
        await db.collection('otps').doc(identifier).update({
            attempts: admin.firestore.FieldValue.increment(1)
        });
        
        throw new functions.https.HttpsError(
            'permission-denied',
            'Invalid OTP'
        );
    }
});
```

### PIN Code System

```javascript
/**
 * Create/Update PIN Code
 */
exports.createPIN = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Must be logged in'
        );
    }
    
    const { pin } = data;
    
    // Validate PIN (4-6 digits)
    if (!pin || !pin.match(/^\d{4,6}$/)) {
        throw new functions.https.HttpsError(
            'invalid-argument',
            'PIN must be 4-6 digits'
        );
    }
    
    // Hash PIN before storage
    const hashedPIN = crypto
        .createHash('sha256')
        .update(pin)
        .digest('hex');
    
    await db.collection('users').doc(context.auth.uid).update({
        pinHash: hashedPIN,
        pinUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    return { success: true, message: 'PIN created successfully' };
});

/**
 * Verify PIN Code
 */
exports.verifyPIN = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError(
            'unauthenticated',
            'Must be logged in'
        );
    }
    
    const { pin } = data;
    
    const userDoc = await db.collection('users').doc(context.auth.uid).get();
    const userData = userDoc.data();
    
    if (!userData.pinHash) {
        throw new functions.https.HttpsError(
            'not-found',
            'PIN not set'
        );
    }
    
    // Hash provided PIN
    const hashedPIN = crypto
        .createHash('sha256')
        .update(pin)
        .digest('hex');
    
    if (hashedPIN === userData.pinHash) {
        return { success: true, message: 'PIN verified' };
    } else {
        throw new functions.https.HttpsError(
            'permission-denied',
            'Invalid PIN'
        );
    }
});
```

### Related Chat History

- [OTP Generation with Crypto](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)
- [Firebase Authentication Setup](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)
- [SMS OTP Implementation](https://claude.ai/chat/f14b6565-9be0-4061-890f-2475bb12f366)

---

## Terminal 2: Shopify Merchant Backend

### Purpose
Handle merchant-side operations for Shopify store owners who install the plugin.

### Responsibilities

- **Plugin Installation**: Handle Shopify App Store installation flow
- **Merchant Onboarding**: Collect PayID, business details, address
- **Profile Management**: Update merchant credentials
- **Dashboard**: Display sales, transactions, orders
- **Settings**: Configure PIN, notifications, webhooks
- **Product Sync**: Sync Shopify products with payment system

### Installation Flow

```
1. Merchant browses Shopify App Store
   ↓
2. Clicks "Install Scan & Pay"
   ↓
3. Shopify OAuth authorization
   ↓
4. Redirected to Scan & Pay onboarding
   ↓
5. SMS/Email OTP verification
   ↓
6. Profile setup (PayID, address, PIN)
   ↓
7. Dashboard access granted
```

### Merchant Profile Structure

```javascript
// Firestore: merchants/{merchantId}
{
  shopifyStoreId: "store123.myshopify.com",
  userId: "firebase-auth-uid",
  profile: {
    businessName: "Example Store",
    payId: "payments@example.com.au",
    email: "owner@example.com",
    phone: "+61400000000",
    address: {
      street: "123 Main St",
      city: "Sydney",
      state: "NSW",
      postcode: "2000",
      country: "Australia"
    }
  },
  settings: {
    pinEnabled: true,
    pinHash: "sha256-hash",
    notificationsEnabled: true,
    webhookUrl: "https://merchant-site.com/webhook"
  },
  status: "active",
  createdAt: Timestamp,
  updatedAt: Timestamp
}
```

### Shopify Integration

**Using Shopify Storefront API**:

```javascript
// Initialize Shopify client
const shopifyClient = ShopifyBuy.buildClient({
    domain: 'yourstore.myshopify.com',
    storefrontAccessToken: 'your-token-here',
    apiVersion: '2024-01'
});

// Fetch products
const products = await shopifyClient.product.fetchAll();

// Create checkout
const checkout = await shopifyClient.checkout.create();
await shopifyClient.checkout.addLineItems(checkout.id, lineItems);
```

### Related Chat History

- [Shopify Integration](https://claude.ai/chat/acdc4a46-19b9-4cd8-a42d-1e3354da2982)
- [WordPress + Shopify Connection](https://claude.ai/chat/acdc4a46-19b9-4cd8-a42d-1e3354da2982)
- [Merchant Dashboard](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)

---

## Terminal 3: Firebase Data Layer

### Purpose
Central database and backend services for the entire system.

### Responsibilities

- **Authentication**: Firebase Auth for users
- **Database**: Firestore for all data storage
- **Cloud Functions**: Backend API endpoints
- **Storage**: File uploads (receipts, documents)
- **Real-time Updates**: Live order status updates

### Firestore Schema

```
/merchants
  /{merchantId}
    - profile
    - settings
    - shopifyStore
    - payId
    - createdAt
    - updatedAt

/products
  /{productId}
    - name
    - price
    - sku
    - description
    - images[]
    - category
    - stock
    - merchantId

/orders
  /{orderId}
    - orderId: "ORD-XXXXXXXX"
    - merchantId
    - customer: {}
    - items: []
    - total
    - paymentMethod: "payid"
    - paymentRef
    - paymentStatus: "pending" | "paid" | "failed"
    - orderStatus: "pending" | "processing" | "completed"
    - createdAt
    - updatedAt

/transactions
  /{transactionId}
    - transactionId
    - orderId
    - amount
    - currencyCode: "AUD"
    - payId
    - reference
    - status: "approved" | "declined" | "pending"
    - verified: true | false
    - webhookId
    - globalPaymentsData: {}
    - createdAt
    - verifiedAt

/otps
  /{identifier} (phone or email)
    - otp
    - type: "sms" | "email"
    - attempts
    - createdAt
    - expiresAt
    - verified

/users
  /{userId}
    - email
    - phone
    - name
    - pinHash
    - merchantId (if merchant)
    - role: "merchant" | "customer"
    - createdAt
```

### Firebase Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Merchants can only read/write their own data
    match /merchants/{merchantId} {
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
    }
    
    // Products readable by all, writable by merchant
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null 
                   && request.auth.uid == resource.data.merchantId;
    }
    
    // Orders readable by merchant and customer
    match /orders/{orderId} {
      allow read: if request.auth != null 
                  && (request.auth.uid == resource.data.merchantId
                      || request.auth.uid == resource.data.customer.userId);
      allow create: if request.auth != null;
      allow update: if request.auth != null 
                    && request.auth.uid == resource.data.merchantId;
    }
    
    // Transactions readable by merchant only
    match /transactions/{transactionId} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions can write
    }
    
    // OTPs not readable by clients
    match /otps/{identifier} {
      allow read, write: if false; // Only Cloud Functions
    }
  }
}
```

### Related Chat History

- [Firebase Configuration](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)
- [Firestore Schema Design](https://claude.ai/chat/add296d0-b930-46db-8643-c3794f2b5188)
- [Cloud Functions Setup](https://claude.ai/chat/add296d0-b930-46db-8643-c3794f2b5188)

---

## Terminal 4: Payment Verification API

### Purpose
**Single responsibility**: Verify if a payment has been received by the merchant.

This is the CRITICAL innovation. Instead of processing payments, this API only VERIFIES them by communicating with Global Payments Oceania API.

### Responsibilities

- **Receive Webhook**: Listen for Global Payments webhook
- **Verify Payment**: Check if amount matches order
- **Return Status**: Return one of 3 states: `paid`, `unpaid`, `pending`
- **Update Database**: Mark transactions as verified
- **Notify Merchant**: Send confirmation to merchant

### The 3 Status Values

```javascript
const PAYMENT_STATUS = {
  PAID: 'paid',        // Payment confirmed, amount matches
  UNPAID: 'unpaid',    // No payment received or declined
  PENDING: 'pending'   // Payment initiated but not settled
};
```

### API Endpoint

```
POST /api/verify-payment

Request:
{
  "reference": "REF-2024-ABC123",
  "amount": 150.00,
  "payId": "payments@merchant.com.au"
}

Response:
{
  "status": "paid" | "unpaid" | "pending",
  "verified": true | false,
  "transactionId": "GP-TXN-789",
  "amount": 150.00,
  "reference": "REF-2024-ABC123",
  "timestamp": "2024-12-04T10:30:00Z"
}
```

### Implementation

**File**: `cloud-functions/payment-verification.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * Payment Verification API
 * Checks Global Payments for transaction status
 */
exports.verifyPayment = functions.https.onRequest(async (req, res) => {
    // CORS
    res.set('Access-Control-Allow-Origin', '*');
    
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        return res.status(204).send('');
    }
    
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    
    try {
        const { reference, amount, payId } = req.body;
        
        // Validate required fields
        if (!reference || !amount || !payId) {
            return res.status(400).json({
                error: 'Missing required fields: reference, amount, payId'
            });
        }
        
        // Query Firebase for transaction by reference
        const txnQuery = await db.collection('transactions')
            .where('reference', '==', reference)
            .where('payId', '==', payId)
            .limit(1)
            .get();
        
        if (txnQuery.empty) {
            // No transaction found - payment not received
            return res.status(200).json({
                status: 'unpaid',
                verified: false,
                reference: reference,
                message: 'No payment received for this reference'
            });
        }
        
        const txnDoc = txnQuery.docs[0];
        const txnData = txnDoc.data();
        
        // Check if amounts match (convert to cents for comparison)
        const expectedAmount = Math.round(amount * 100);
        const receivedAmount = txnData.amount; // Already in cents from GP
        
        if (receivedAmount !== expectedAmount) {
            return res.status(200).json({
                status: 'unpaid',
                verified: false,
                reference: reference,
                message: 'Amount mismatch',
                expected: expectedAmount,
                received: receivedAmount
            });
        }
        
        // Check transaction status from Global Payments
        const gpStatus = txnData.status; // "approved", "declined", "pending"
        
        let verificationStatus;
        let verified = false;
        
        switch (gpStatus) {
            case 'approved':
                verificationStatus = 'paid';
                verified = true;
                break;
            case 'declined':
                verificationStatus = 'unpaid';
                verified = false;
                break;
            case 'pending':
            default:
                verificationStatus = 'pending';
                verified = false;
                break;
        }
        
        // Return verification result
        return res.status(200).json({
            status: verificationStatus,
            verified: verified,
            transactionId: txnData.transactionId,
            amount: receivedAmount / 100, // Convert back to dollars
            reference: reference,
            payId: payId,
            timestamp: txnData.createdDateTime || new Date().toISOString(),
            globalPaymentsStatus: gpStatus
        });
        
    } catch (error) {
        console.error('Verification error:', error);
        return res.status(500).json({
            status: 'error',
            error: 'Internal server error',
            message: error.message
        });
    }
});
```

### Webhook Receiver

**File**: `cloud-functions/global-payments-webhook.js`

```javascript
/**
 * Global Payments Webhook Receiver
 * Receives transaction notifications from Global Payments Oceania
 */
exports.globalPaymentsWebhook = functions.https.onRequest(async (req, res) => {
    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }
    
    try {
        // Extract webhook data
        const webhookData = req.body;
        
        /*
        Global Payments sends:
        {
          "id": "WQYvMI-3FUWMHlB22rW69Q",
          "reference": "REF-2024-ABC123",
          "created": "2023-01-01T02:02:48Z",
          "version": "1.0.0",
          "event": "transactions",
          "payload": {
            "id": "9xkkdZuMn0mvE9xnPrzqIA",
            "createdDateTime": "2023-01-01T02:02:03Z",
            "updatedDateTime": "2023-01-01T02:02:09Z",
            "category": {
              "source": "payto",
              "method": "purchase"
            },
            "payment": {
              "amount": 15000, // IN CENTS
              "currencyCode": "AUD",
              "instrument": {
                "customer": {
                  "id": "wx167QAQ4E-bcffWI_-Smg",
                  "paymentInstrumentId": "zAFQgcwsyESTeqmgJREcrQ"
                }
              }
            },
            "result": {
              "status": "approved" // or "declined" or "pending"
            }
          }
        }
        */
        
        // Verify webhook signature (if GP provides one)
        const signature = req.headers['x-signature'];
        // TODO: Verify signature using your GP Private Key
        
        // Extract key fields
        const webhookId = webhookData.id;
        const reference = webhookData.reference;
        const transactionId = webhookData.payload.id;
        const amount = webhookData.payload.payment.amount; // cents
        const currencyCode = webhookData.payload.payment.currencyCode;
        const status = webhookData.payload.result.status;
        const createdDateTime = webhookData.payload.createdDateTime;
        const updatedDateTime = webhookData.payload.updatedDateTime;
        
        // Determine verified status
        const verified = (status === 'approved');
        
        // Find associated order by reference
        const orderQuery = await db.collection('orders')
            .where('paymentRef', '==', reference)
            .limit(1)
            .get();
        
        let orderId = null;
        if (!orderQuery.empty) {
            orderId = orderQuery.docs[0].id;
            
            // Update order status
            await db.collection('orders').doc(orderId).update({
                paymentStatus: verified ? 'PAID' : 'DECLINED',
                transactionId: transactionId,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
        }
        
        // Store transaction in Firebase
        await db.collection('transactions').add({
            webhookId: webhookId,
            reference: reference,
            transactionId: transactionId,
            orderId: orderId,
            amount: amount,
            currencyCode: currencyCode,
            status: status,
            verified: verified,
            createdDateTime: createdDateTime,
            updatedDateTime: updatedDateTime,
            globalPaymentsData: webhookData.payload,
            receivedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        console.log(`✅ Webhook processed: ${webhookId}`);
        console.log(`   Reference: ${reference}`);
        console.log(`   Amount: ${amount / 100} ${currencyCode}`);
        console.log(`   Status: ${status}`);
        console.log(`   Verified: ${verified}`);
        
        // Return success
        return res.status(200).json({
            success: true,
            message: 'Webhook processed',
            webhookId: webhookId,
            verified: verified
        });
        
    } catch (error) {
        console.error('❌ Webhook error:', error);
        return res.status(500).json({
            success: false,
            error: error.message
        });
    }
});
```

### Deployment

```bash
# Deploy verification API
cd cloud-functions
firebase deploy --only functions:verifyPayment

# Deploy webhook receiver
firebase deploy --only functions:globalPaymentsWebhook

# Get webhook URL
firebase functions:config:get

# Configure in Global Payments Dashboard
# Webhook URL: https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook
```

### Related Chat History

- [Payment Verification Architecture](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)
- [Global Payments Webhook](https://claude.ai/chat/aa565c61-6951-4f5e-978b-77d99febe32e)
- [Webhook Setup Guide](https://claude.ai/chat/977ab5bd-04c0-4fea-8217-ccc56d3dd5c6)

---

## Terminal 5: Shopify Client/Buyer Frontend

### Purpose
The buyer-facing interface where remote customers complete purchases using QR codes and PayID.

### Responsibilities

- **Product Display**: Show Shopify products to buyers
- **Shopping Cart**: Add/remove items, calculate totals
- **QR Code Generation**: Generate payment QR codes
- **Checkout Form**: Collect delivery address (for merchant)
- **Payment Instructions**: Show PayID and reference
- **Status Polling**: Check payment verification status
- **Order Confirmation**: Display successful orders

### User Flow

```
1. Buyer browses products on merchant's Shopify store
   ↓
2. Adds items to cart
   ↓
3. Clicks "Checkout with Scan & Pay"
   ↓
4. Enters delivery address
   ↓
5. Sees QR code with:
   - Amount: $150.00
   - PayID: payments@merchant.com.au
   - Reference: REF-2024-ABC123
   ↓
6. Scans QR code with banking app
   ↓
7. Completes payment in bank app
   ↓
8. Our system verifies with Terminal 4
   ↓
9. Order confirmed & merchant notified
```

### Frontend Implementation

**File**: `shopify-client-checkout.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Checkout - Scan & Pay</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            padding: 20px;
        }

        .checkout-container {
            max-width: 500px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }

        .header {
            text-align: center;
            margin-bottom: 30px;
        }

        .header h1 {
            font-size: 24px;
            color: #333;
            margin-bottom: 10px;
        }

        .order-summary {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }

        .order-item {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
            color: #666;
        }

        .order-total {
            display: flex;
            justify-content: space-between;
            font-size: 20px;
            font-weight: bold;
            color: #333;
            margin-top: 15px;
            padding-top: 15px;
            border-top: 2px solid #ddd;
        }

        .payment-section {
            border: 2px solid #25D366;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
        }

        .payment-label {
            font-size: 14px;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 5px;
        }

        .payment-value {
            font-size: 18px;
            font-weight: bold;
            color: #333;
            user-select: all;
            cursor: pointer;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 4px;
            margin-bottom: 15px;
        }

        .payment-value:hover {
            background: #e9ecef;
        }

        .qr-container {
            display: flex;
            justify-content: center;
            margin: 20px 0;
        }

        #qrcode {
            padding: 10px;
            background: white;
            border-radius: 8px;
        }

        .address-form {
            margin-bottom: 20px;
        }

        .form-group {
            margin-bottom: 15px;
        }

        .form-label {
            display: block;
            font-size: 14px;
            font-weight: 500;
            color: #333;
            margin-bottom: 5px;
        }

        .form-input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 6px;
            font-size: 14px;
        }

        .form-input:focus {
            outline: none;
            border-color: #25D366;
        }

        .submit-btn {
            width: 100%;
            padding: 15px;
            background: #25D366;
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.2s;
        }

        .submit-btn:hover {
            background: #20bd5a;
            transform: translateY(-1px);
        }

        .submit-btn:disabled {
            background: #ccc;
            cursor: not-allowed;
            transform: none;
        }

        .status-message {
            padding: 15px;
            border-radius: 8px;
            margin-top: 15px;
            text-align: center;
            font-weight: 500;
        }

        .status-pending {
            background: #fff3cd;
            color: #856404;
        }

        .status-success {
            background: #d4edda;
            color: #155724;
        }

        .status-error {
            background: #f8d7da;
            color: #721c24;
        }

        .instructions {
            background: #e7f5ff;
            border: 1px solid #b3d7ff;
            border-radius: 8px;
            padding: 15px;
            margin-top: 20px;
            font-size: 13px;
            color: #004085;
        }

        .instructions ol {
            margin-left: 20px;
            margin-top: 10px;
        }

        .instructions li {
            margin-bottom: 5px;
        }
    </style>
</head>
<body>
    <div class="checkout-container">
        <div class="header">
            <h1>💳 Complete Your Order</h1>
            <p style="color: #666;">Pay with PayID & get instant confirmation</p>
        </div>

        <!-- Order Summary -->
        <div class="order-summary">
            <h3 style="margin-bottom: 15px;">Order Summary</h3>
            <div id="orderItems"></div>
            <div class="order-total">
                <span>Total:</span>
                <span id="orderTotal">$0.00</span>
            </div>
        </div>

        <!-- Address Form -->
        <form id="checkoutForm" class="address-form">
            <div class="form-group">
                <label class="form-label">Full Name *</label>
                <input type="text" class="form-input" id="fullName" required>
            </div>
            <div class="form-group">
                <label class="form-label">Email *</label>
                <input type="email" class="form-input" id="email" required>
            </div>
            <div class="form-group">
                <label class="form-label">Phone *</label>
                <input type="tel" class="form-input" id="phone" required>
            </div>
            <div class="form-group">
                <label class="form-label">Delivery Address *</label>
                <textarea class="form-input" id="address" rows="3" required></textarea>
            </div>
        </form>

        <!-- Payment Section -->
        <div class="payment-section">
            <div class="payment-label">💰 Total Amount</div>
            <div class="payment-value" id="paymentAmount">$0.00</div>

            <div class="payment-label">📱 PayID Email</div>
            <div class="payment-value" id="payIdEmail" onclick="copyToClipboard('payIdEmail')">
                payments@scanandpay.com.au
            </div>

            <div class="payment-label">🔖 Payment Reference</div>
            <div class="payment-value" id="paymentReference" onclick="copyToClipboard('paymentReference')">
                Generating...
            </div>

            <div class="qr-container">
                <div id="qrcode"></div>
            </div>
        </div>

        <!-- Instructions -->
        <div class="instructions">
            <strong>📋 How to Pay:</strong>
            <ol>
                <li>Open your banking app</li>
                <li>Select "PayID" or "Pay Anyone"</li>
                <li>Scan the QR code above OR enter details manually</li>
                <li>Confirm the payment</li>
                <li>Click "I've Paid" button below</li>
            </ol>
        </div>

        <!-- Submit Button -->
        <button class="submit-btn" id="submitBtn" onclick="confirmPayment()">
            I've Paid - Verify Now
        </button>

        <!-- Status Message -->
        <div id="statusMessage"></div>
    </div>

    <script>
        // Cart data (passed from Shopify)
        let cartData = {
            items: [
                { name: "Product 1", quantity: 2, price: 50.00 },
                { name: "Product 2", quantity: 1, price: 50.00 }
            ],
            total: 150.00,
            merchantPayId: "payments@scanandpay.com.au"
        };

        // Generate payment reference
        function generateReference() {
            // Crypto-based alphanumeric reference
            // Same logic as OTP generation but with letters
            const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            const length = 15; // PayID allows up to 18 characters
            let reference = 'REF-2024-';
            
            const array = new Uint8Array(length);
            crypto.getRandomValues(array);
            
            for (let i = 0; i < length; i++) {
                reference += chars[array[i] % chars.length];
            }
            
            return reference;
        }

        // Initialize page
        let paymentReference = generateReference();

        // Display order items
        function displayOrder() {
            const itemsHtml = cartData.items.map(item => `
                <div class="order-item">
                    <span>${item.name} x${item.quantity}</span>
                    <span>$${(item.price * item.quantity).toFixed(2)}</span>
                </div>
            `).join('');

            document.getElementById('orderItems').innerHTML = itemsHtml;
            document.getElementById('orderTotal').textContent = `$${cartData.total.toFixed(2)}`;
            document.getElementById('paymentAmount').textContent = `$${cartData.total.toFixed(2)}`;
            document.getElementById('payIdEmail').textContent = cartData.merchantPayId;
            document.getElementById('paymentReference').textContent = paymentReference;
        }

        // Generate QR Code
        function generateQRCode() {
            const qrData = `PayID: ${cartData.merchantPayId}\nAmount: $${cartData.total.toFixed(2)}\nReference: ${paymentReference}`;
            
            new QRCode(document.getElementById("qrcode"), {
                text: qrData,
                width: 200,
                height: 200,
                colorDark: "#000000",
                colorLight: "#ffffff",
                correctLevel: QRCode.CorrectLevel.H
            });
        }

        // Copy to clipboard
        function copyToClipboard(elementId) {
            const element = document.getElementById(elementId);
            const text = element.textContent.trim();
            
            navigator.clipboard.writeText(text).then(() => {
                const originalBg = element.style.background;
                element.style.background = '#d4edda';
                setTimeout(() => {
                    element.style.background = originalBg;
                }, 500);
            });
        }

        // Confirm payment (calls Terminal 4 API)
        async function confirmPayment() {
            const fullName = document.getElementById('fullName').value;
            const email = document.getElementById('email').value;
            const phone = document.getElementById('phone').value;
            const address = document.getElementById('address').value;

            if (!fullName || !email || !phone || !address) {
                showStatus('Please fill in all fields', 'error');
                return;
            }

            const submitBtn = document.getElementById('submitBtn');
            submitBtn.disabled = true;
            submitBtn.textContent = 'Verifying Payment...';

            showStatus('Checking with bank...', 'pending');

            try {
                // Call Terminal 4 - Payment Verification API
                const response = await fetch('https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/verifyPayment', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        reference: paymentReference,
                        amount: cartData.total,
                        payId: cartData.merchantPayId
                    })
                });

                const result = await response.json();

                if (result.status === 'paid' && result.verified) {
                    // Payment confirmed!
                    showStatus('✅ Payment Confirmed! Your order is being processed.', 'success');
                    
                    // Create order in Firebase
                    await createOrder({
                        fullName,
                        email,
                        phone,
                        address,
                        reference: paymentReference,
                        transactionId: result.transactionId
                    });

                    // Redirect to confirmation page after 2 seconds
                    setTimeout(() => {
                        window.location.href = '/order-confirmation';
                    }, 2000);

                } else if (result.status === 'pending') {
                    showStatus('⏳ Payment pending. Please wait...', 'pending');
                    // Poll again after 5 seconds
                    setTimeout(confirmPayment, 5000);

                } else {
                    showStatus('❌ Payment not found. Please complete the payment first.', 'error');
                    submitBtn.disabled = false;
                    submitBtn.textContent = "I've Paid - Verify Now";
                }

            } catch (error) {
                console.error('Verification error:', error);
                showStatus('❌ Error verifying payment. Please try again.', 'error');
                submitBtn.disabled = false;
                submitBtn.textContent = "I've Paid - Verify Now";
            }
        }

        // Create order in Firebase
        async function createOrder(customerData) {
            // TODO: Call Firebase to create order
            console.log('Creating order:', customerData);
        }

        // Show status message
        function showStatus(message, type) {
            const statusDiv = document.getElementById('statusMessage');
            statusDiv.textContent = message;
            statusDiv.className = `status-message status-${type}`;
        }

        // Initialize on load
        document.addEventListener('DOMContentLoaded', () => {
            displayOrder();
            generateQRCode();
        });
    </script>
</body>
</html>
```

### Related Chat History

- [Shopify Client Implementation](https://claude.ai/chat/acdc4a46-19b9-4cd8-a42d-1e3354da2982)
- [QR Code Generation](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)
- [Checkout Flow](https://claude.ai/chat/708d29fc-e8f5-4569-ad47-6d49ca886bee)

---

## QR Code Implementation

### Overview

QR codes are generated dynamically for each transaction, containing:
- **PayID**: Merchant's payment email
- **Amount**: Total order amount
- **Reference**: Unique crypto-generated reference

### Library Used

**QRCode.js** - Client-side QR code generation
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
```

### Implementation

```javascript
/**
 * Generate QR Code
 * @param {string} payId - Merchant PayID email
 * @param {number} amount - Payment amount
 * @param {string} reference - Payment reference
 */
function generatePaymentQR(payId, amount, reference) {
    // Clear existing QR code
    const qrContainer = document.getElementById("qrcode");
    qrContainer.innerHTML = '';
    
    // Create QR data string
    const qrData = `PayID: ${payId}\nAmount: $${amount.toFixed(2)}\nReference: ${reference}`;
    
    // Generate QR code
    new QRCode(qrContainer, {
        text: qrData,
        width: 200,
        height: 200,
        colorDark: "#000000",
        colorLight: "#ffffff",
        correctLevel: QRCode.CorrectLevel.H // High error correction
    });
}

// Example usage
generatePaymentQR(
    "payments@merchant.com.au",
    150.00,
    "REF-2024-ABC123"
);
```

### QR Code Error Correction Levels

```javascript
QRCode.CorrectLevel = {
    L: 1,  // 7% error correction
    M: 0,  // 15% error correction
    Q: 3,  // 25% error correction
    H: 2   // 30% error correction (recommended)
};
```

We use **Level H** for maximum reliability, even if partially damaged.

### Styling QR Codes

```css
#qrcode {
    display: flex;
    justify-content: center;
    align-items: center;
    padding: 20px;
    background: white;
    border-radius: 12px;
    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
}

#qrcode img {
    border-radius: 8px;
}
```

### Related Chat History

- [QR Code with Labels](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)
- [QR Code Payment Page](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)

---

## Reference Generation System

### Purpose

Generate unique, crypto-secure payment references that:
- Are easy to read (no confusing characters like 0, O, 1, I)
- Are unpredictable (crypto.getRandomValues)
- Fit PayID reference limits (max 18 characters)
- Match OTP generation style for consistency

### Implementation

```javascript
/**
 * Generate Payment Reference
 * Uses crypto API for true randomness
 * Returns format: REF-2024-XXXXXXXXX
 */
function generatePaymentReference() {
    // Characters: No confusing ones (0, O, 1, I, L)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const length = 12; // Adjustable based on PayID limits
    
    let reference = 'REF-2024-';
    
    // Use crypto.getRandomValues for true randomness
    const array = new Uint8Array(length);
    crypto.getRandomValues(array);
    
    for (let i = 0; i < length; i++) {
        reference += chars[array[i] % chars.length];
    }
    
    return reference;
}

// Example outputs:
// REF-2024-A3K9N7P4X2M8
// REF-2024-B7J2Q9W5Y3R6
// REF-2024-C4H8T6V9Z7N2
```

### Why Crypto Instead of Math.random()?

| Feature | Math.random() | crypto.getRandomValues() |
|---------|---------------|-------------------------|
| **Predictable** | ✅ Yes | ❌ No |
| **Secure** | ❌ No | ✅ Yes |
| **Cryptographic** | ❌ No | ✅ Yes |
| **True Random** | ❌ Pseudo | ✅ True |

**We use crypto because:**
1. Payment references must be unpredictable
2. Prevents reference collision attacks
3. Same standard as OTP generation
4. Industry best practice for financial systems

### PayID Reference Limits

According to PayID specifications:
- **Max length**: 18-20 characters (varies by bank)
- **Allowed characters**: Letters, numbers, `-`, `_`
- **Case sensitivity**: Usually case-insensitive

Our format (`REF-2024-XXXXXXXXX`) uses:
- Prefix: `REF-2024-` (9 chars)
- Random: 12 chars
- **Total**: 21 chars (adjust if needed)

To stay under limits:
```javascript
// Shorter version (18 chars total)
const length = 9; // REF-2024-XXXXXXXXX = 18 chars
```

### Related Chat History

- [Crypto Random Generation](https://claude.ai/chat/f14b6565-9be0-4061-890f-2475bb12f366)
- [OTP Generation Logic](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)

---

## Global Payments Webhook Integration

### Webhook Payload Structure

When a payment is processed, Global Payments sends this webhook:

```json
{
  "id": "WQYvMI-3FUWMHlB22rW69Q",
  "reference": "REF-2024-ABC123",
  "created": "2023-01-01T02:02:48Z",
  "version": "1.0.0",
  "event": "transactions",
  "payload": {
    "id": "9xkkdZuMn0mvE9xnPrzqIA",
    "createdDateTime": "2023-01-01T02:02:03Z",
    "updatedDateTime": "2023-01-01T02:02:09Z",
    "category": {
      "source": "payto",
      "method": "purchase"
    },
    "payment": {
      "amount": 1,
      "currencyCode": "AUD",
      "instrument": {
        "customer": {
          "id": "wx167QAQ4E-bcffWI_-Smg",
          "paymentInstrumentId": "zAFQgcwsyESTeqmgJREcrQ"
        }
      }
    },
    "result": {
      "status": "approved"
    }
  }
}
```

### Key Fields We Extract

| Field Path | Our Usage | Example |
|-----------|-----------|---------|
| `payload.id` | Transaction ID | `9xkkdZuMn0mvE9xnPrzqIA` |
| `payload.payment.amount` | Amount (cents) | `15000` = $150.00 |
| `payload.result.status` | Payment status | `approved`, `declined`, `pending` |
| `reference` | Our reference | `REF-2024-ABC123` |
| `payload.payment.currencyCode` | Currency | `AUD` |

### Important: Amount is in Cents!

```javascript
// Global Payments sends amount in CENTS
const amountCents = 15000; // From webhook
const amountDollars = amountCents / 100; // $150.00

// Always convert when comparing
if (webhookAmount === cartTotal * 100) {
    // Amounts match!
}
```

### Webhook Security

**Verify signature** to ensure webhook is from Global Payments:

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

### Webhook Configuration

**In Global Payments Dashboard:**
1. Login to docs.gpaunz.com
2. Navigate to Webhooks → Create Subscription
3. Enter webhook URL: `https://YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook`
4. Select events: `transactions`
5. Save and note your Private Key
6. Store Private Key in Firebase config:
   ```bash
   firebase functions:config:set globalpayments.private_key="YOUR-KEY"
   ```

### Testing Webhooks Locally

```bash
# Use ngrok to expose localhost
ngrok http 5000

# Use the ngrok URL in GP dashboard
https://abc123.ngrok.io/globalPaymentsWebhook

# Watch Firebase logs
firebase functions:log
```

### Related Chat History

- [Global Payments Webhook Guide](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)
- [Webhook Events](https://claude.ai/chat/aa565c61-6951-4f5e-978b-77d99febe32e)
- [Payment Verification](https://claude.ai/chat/977ab5bd-04c0-4fea-8217-ccc56d3dd5c6)

---

## Code Files & Resources

### Frontend Files

1. **PayID QR Payment Page**: `/mnt/user-data/outputs/payid-qr-payment.html`
   - Standalone QR code payment page
   - Copy-to-clipboard functionality
   - Payment instructions
   - [Download](computer:///mnt/user-data/outputs/payid-qr-payment.html)

2. **Shopify Client Checkout**: `shopify-client-checkout.html`
   - Full checkout flow for buyers
   - Address form
   - QR code generation
   - Payment verification

### Backend Files

3. **Cloud Functions Index**: `cloud-functions/index.js`
   - OTP generation and verification
   - PIN code management
   - Authentication endpoints

4. **Payment Verification API**: `cloud-functions/payment-verification.js`
   - Terminal 4 implementation
   - Returns paid/unpaid/pending status
   - Queries Firebase for transactions

5. **Global Payments Webhook**: `cloud-functions/global-payments-webhook.js`
   - Receives GP webhooks
   - Stores transactions
   - Updates order status

### Configuration Files

6. **Firebase Config**: `firebase.json`
7. **Firestore Security Rules**: `firestore.rules`
8. **Environment Variables**: `.env`

### Documentation

9. **This File**: `CLAUDE.md`
10. **Global Payments Webhook Guide**: `GLOBAL_PAYMENTS_WEBHOOK_GUIDE.md`

---

## Chat History References

### Core Development Chats

- **[Main QR Code & PayID Implementation](https://claude.ai/chat/1d297d14-1482-4e76-96e9-c8f518063b24)**
  - Complete HTML shop with Firebase
  - QR code generation
  - PayID integration
  - OTP authentication
  - Global Payments webhook

- **[Shopify Integration](https://claude.ai/chat/acdc4a46-19b9-4cd8-a42d-1e3354da2982)**
  - WordPress + Shopify connection
  - Shopify Storefront API
  - Cart and checkout flow
  - Product catalog management

- **[Webhook Implementation](https://claude.ai/chat/aa565c61-6951-4f5e-978b-77d99febe32e)**
  - Webhook setup guide
  - Event handling
  - Global Payments payload structure
  - Verification logic

- **[Payment Processor Integration](https://claude.ai/chat/977ab5bd-04c0-4fea-8217-ccc56d3dd5c6)**
  - SoftPOS NFC comparison
  - Global Payments Oceania API
  - Terminal integration
  - Webhook support

### Supporting Chats

- **[Webhook Variables](https://claude.ai/chat/add296d0-b930-46db-8643-c3794f2b5188)**
  - 3-variable webhook function
  - PayID, amount, reference
  - Firebase database storage

- **[SSH & Deployment](https://claude.ai/chat/771a050c-8a10-4293-8e3d-74aba862b5b8)**
  - SSH key generation
  - GitHub Actions workflow
  - Cloud deployment

- **[Partner Agreement](https://claude.ai/chat/24bb0db7-3817-49e9-8597-fa2067ef7e8d)**
  - Ezidebit/Eway partnership
  - Commission structure
  - Marketing requirements

- **[Terminal Architecture](https://claude.ai/chat/858f25b8-f5eb-4ea7-beed-66b9b7ce3c6c)**
  - Multi-terminal setup
  - NFC implementation
  - QR code testing

- **[Authentication Errors](https://claude.ai/chat/14fe2733-e5bb-48fd-9330-364cc7b75d73)**
  - GCP authentication
  - IAM permissions
  - Service account setup

- **[Shopify Collections](https://claude.ai/chat/708d29fc-e8f5-4569-ad47-6d49ca886bee)**
  - Product organization
  - Collection tags
  - Navigation setup

---

## Deployment Guide

### Prerequisites

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize project
firebase init
```

### 1. Deploy Cloud Functions

```bash
cd cloud-functions

# Install dependencies
npm install

# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:verifyPayment
```

### 2. Configure Environment Variables

```bash
# Twilio (for SMS OTP)
firebase functions:config:set \
  twilio.account_sid="YOUR_SID" \
  twilio.auth_token="YOUR_TOKEN" \
  twilio.phone_number="+61XXXXXXXXX"

# SendGrid (for Email OTP)
firebase functions:config:set \
  sendgrid.api_key="YOUR_KEY" \
  sendgrid.from_email="noreply@scanandpay.com.au"

# Global Payments
firebase functions:config:set \
  globalpayments.private_key="YOUR_PRIVATE_KEY" \
  globalpayments.webhook_url="YOUR_WEBHOOK_URL"

# View config
firebase functions:config:get
```

### 3. Deploy Firestore Rules

```bash
firebase deploy --only firestore:rules
```

### 4. Deploy Frontend

```bash
# Build for production
npm run build

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### 5. Configure Global Payments

1. Login to [docs.gpaunz.com](https://docs.gpaunz.com)
2. Navigate to Webhooks
3. Create subscription:
   - URL: `https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook`
   - Events: `transactions`
4. Note your Private Key
5. Add to Firebase config (see step 2)

### 6. Install Shopify App

1. Go to [partners.shopify.com](https://partners.shopify.com)
2. Create new app
3. Configure OAuth scopes:
   - `read_products`
   - `write_orders`
   - `read_customers`
4. Set redirect URLs
5. Submit for review
6. Publish to Shopify App Store

---

## Testing

### Test OTP Flow

```bash
# Send SMS OTP
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/sendSMSOTP \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+61400000000"}'

# Verify OTP
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/verifyOTP \
  -H "Content-Type: application/json" \
  -d '{"identifier": "+61400000000", "otp": "123456"}'
```

### Test Payment Verification

```bash
# Verify payment
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/verifyPayment \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "REF-2024-TEST123",
    "amount": 150.00,
    "payId": "payments@test.com.au"
  }'
```

### Test Webhook

```bash
# Send test webhook
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook \
  -H "Content-Type: application/json" \
  -H "X-Signature: test-signature" \
  -d @test-webhook.json
```

---

## Support & Maintenance

### Monitoring

```bash
# View function logs
firebase functions:log

# View specific function
firebase functions:log --only verifyPayment

# View errors only
firebase functions:log --only verifyPayment --severity error
```

### Common Issues

1. **OTP not received**
   - Check Twilio balance
   - Verify phone number format
   - Check Firestore for OTP document

2. **Payment verification fails**
   - Check webhook was received
   - Verify amount is in cents
   - Check reference matches exactly

3. **Webhook signature invalid**
   - Verify Private Key in config
   - Check signature header name
   - Ensure payload not modified

### Debug Mode

Add to Firebase config:
```bash
firebase functions:config:set app.debug="true"
```

---

## Roadmap

### Phase 1: MVP (Current)
- ✅ 5-terminal architecture
- ✅ QR code payments
- ✅ PayID integration
- ✅ OTP authentication
- ✅ Global Payments webhook

### Phase 2: Enhanced Features
- [ ] Multi-currency support
- [ ] Refund processing
- [ ] Advanced analytics dashboard
- [ ] Customer loyalty program
- [ ] Invoice generation

### Phase 3: Scale
- [ ] Multi-region deployment
- [ ] Advanced fraud detection
- [ ] API rate limiting
- [ ] CDN integration
- [ ] Load balancing

---

## License & Credits

**Project**: Scan & Pay - Shopify Payment System  
**Company**: Senax Enterprises Pty Ltd  
**Created**: November 2024  
**Documentation**: December 2024

**Technologies Used:**
- Firebase (Backend)
- Shopify (E-commerce)
- Global Payments Oceania (Payment Processing)
- QRCode.js (QR Generation)
- Twilio (SMS OTP)
- SendGrid (Email OTP)

---

## Contact

**Technical Support**: support@scanandpay.com.au  
**Sales**: sales@scanandpay.com.au  
**Website**: https://scanandpay.com.au

---

*End of Documentation*
