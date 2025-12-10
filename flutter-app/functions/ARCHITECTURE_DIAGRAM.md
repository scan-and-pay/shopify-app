# Firebase Functions Architecture with Secret Manager

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         CLIENTS (No Changes Required)                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────────────┐              ┌───────────────────────┐        │
│  │  Flutter Android App │              │  Shopify Web Dashboard │        │
│  │   (Mobile Kiosk)     │              │   (Cloud Run)          │        │
│  └──────────┬───────────┘              └───────────┬───────────┘        │
│             │                                       │                     │
│             │  Firebase SDK                         │  Firebase SDK      │
│             │  .httpsCallable('functionName')       │  httpsCallable()   │
│             │                                       │                     │
└─────────────┼───────────────────────────────────────┼─────────────────────┘
              │                                       │
              ▼                                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    FIREBASE CLOUD FUNCTIONS                              │
│                    Region: australia-southeast1                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  CALLABLE FUNCTIONS (15)                                         │   │
│  │  ─────────────────────────────────────────────────────────────   │   │
│  │                                                                   │   │
│  │  Authentication:                                                 │   │
│  │  • sendOtp ──────────────────────► Uses MAILGUN_API_KEY        │   │
│  │  • verifyOtp ─────────────────────► Creates custom auth token   │   │
│  │                                                                   │   │
│  │  PayID QR:                                                       │   │
│  │  • generatePayIDQR ───────────────► Creates payment intent      │   │
│  │  • checkPayIDStatus ──────────────► Queries Firestore          │   │
│  │                                                                   │   │
│  │  Global Payments (8 functions):                                 │   │
│  │  • createGlobalPaymentsCustomer ──► Uses GLOBALPAYMENTS_*      │   │
│  │  • createPayToAgreement ──────────► Uses GLOBALPAYMENTS_*      │   │
│  │  • createPayIdInstrument ─────────► Uses GLOBALPAYMENTS_*      │   │
│  │  • processGlobalPayment ──────────► Uses GLOBALPAYMENTS_*      │   │
│  │  • getGlobalPaymentsCustomer ─────► Uses GLOBALPAYMENTS_*      │   │
│  │  • getGlobalPaymentInstrument ────► Uses GLOBALPAYMENTS_*      │   │
│  │  • cancelGlobalPaymentAgreement ──► Uses GLOBALPAYMENTS_*      │   │
│  │  • checkGlobalPaymentsHealth ─────► Uses GLOBALPAYMENTS_*      │   │
│  │                                                                   │   │
│  │  User Management:                                                │   │
│  │  • deleteUserAccount ─────────────► Deletes from Auth & DB     │   │
│  │                                                                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  HTTPS WEBHOOK FUNCTIONS (4)                                     │   │
│  │  ─────────────────────────────────────────────────────────────   │   │
│  │                                                                   │   │
│  │  Shopify GDPR & Lifecycle:                                       │   │
│  │  • appUninstalled ────────────────► Uses SHOPIFY_API_SECRET     │   │
│  │  • customersDataRequest ──────────► Uses SHOPIFY_API_SECRET     │   │
│  │  • customersRedact ───────────────► Uses SHOPIFY_API_SECRET     │   │
│  │  • shopRedact ────────────────────► Uses SHOPIFY_API_SECRET     │   │
│  │                                                                   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                           │
└─────────────┬───────────────────────────────────┬───────────────────────┘
              │                                   │
              ▼                                   ▼
┌──────────────────────────┐        ┌────────────────────────────┐
│  GOOGLE SECRET MANAGER   │        │  FIREBASE SERVICES         │
├──────────────────────────┤        ├────────────────────────────┤
│                          │        │                            │
│  Secrets (10):           │        │  • Firestore (Database)    │
│  • MAILGUN_API_KEY       │        │  • Authentication          │
│  • MAILGUN_DOMAIN        │        │  • Cloud Functions         │
│  • GLOBALPAYMENTS_*      │        │  • App Check               │
│  • SHOPIFY_API_SECRET    │        │                            │
│  • ENCRYPTION_KEY        │        └────────────────────────────┘
│  • BASIQ_API_KEY         │
│  • FIREBASE_*            │
│                          │
└──────────────────────────┘
```

---

## 🔐 Secret Flow

```
Function Call
     │
     ▼
┌─────────────────────────────────────────┐
│  Function Initialization                 │
│  ───────────────────────────────────     │
│  1. Firebase receives request            │
│  2. Checks function configuration:       │
│     .region('australia-southeast1')      │
│     .runWith({ secrets: [...] })         │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│  Secret Manager Access                   │
│  ───────────────────────────────────     │
│  1. Function requests secrets            │
│  2. Secret Manager verifies IAM role     │
│  3. Secrets injected as env variables    │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│  Function Execution                      │
│  ───────────────────────────────────     │
│  1. Code calls SECRET.value()            │
│  2. Returns secret from env              │
│  3. Function uses secret for API calls   │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│  External API Call                       │
│  ───────────────────────────────────     │
│  • Mailgun (email sending)               │
│  • Global Payments (payment processing)  │
│  • Shopify (HMAC verification)           │
└─────────────────────────────────────────┘
```

---

## 📦 Module Dependencies

```
index.js (Main Entry Point)
│
├─► send_otp_email.js
│   ├─ defineSecret('MAILGUN_API_KEY')
│   ├─ defineSecret('MAILGUN_DOMAIN')
│   └─ Exports: sendOtp (callable)
│
├─► verify_otp_email.js
│   └─ Exports: verifyOtp (callable)
│
├─► payid_qr.js
│   ├─ Exports: generatePayIDQR (callable)
│   └─ Exports: checkPayIDStatus (callable)
│
├─► global_payments_api.js
│   ├─ defineSecret('GLOBALPAYMENTS_MASTER_KEY')
│   ├─ defineSecret('GLOBALPAYMENTS_BASE_URL')
│   ├─ Exports: createGlobalPaymentsCustomer (callable)
│   ├─ Exports: createPayToAgreement (callable)
│   ├─ Exports: createPayIdInstrument (callable)
│   ├─ Exports: processGlobalPayment (callable)
│   ├─ Exports: getGlobalPaymentsCustomer (callable)
│   ├─ Exports: getGlobalPaymentInstrument (callable)
│   ├─ Exports: cancelGlobalPaymentAgreement (callable)
│   └─ Exports: checkGlobalPaymentsHealth (callable)
│
├─► delete_user_account.js
│   └─ Exports: deleteUserAccount (callable)
│
└─► shopify_webhooks.js
    ├─ defineSecret('SHOPIFY_API_SECRET')
    ├─ Exports: appUninstalled (https)
    ├─ Exports: customersDataRequest (https)
    ├─ Exports: customersRedact (https)
    └─ Exports: shopRedact (https)
```

---

## 🔄 Function Call Flow

### Example: OTP Email Send

```
1. CLIENT (Flutter/Web)
   │
   │  httpsCallable('sendOtp').call({ email: 'user@example.com' })
   │
   ▼
2. FIREBASE FUNCTIONS (australia-southeast1)
   │
   │  sendOtp function triggered
   │  .region('australia-southeast1')
   │  .runWith({ secrets: [MAILGUN_API_KEY, MAILGUN_DOMAIN] })
   │
   ▼
3. SECRET MANAGER
   │
   │  Injects MAILGUN_API_KEY and MAILGUN_DOMAIN
   │
   ▼
4. FUNCTION EXECUTION
   │
   │  const apiKey = MAILGUN_API_KEY.value();
   │  const domain = MAILGUN_DOMAIN.value();
   │
   ▼
5. FIRESTORE
   │
   │  Store OTP with expiry (60 seconds)
   │
   ▼
6. MAILGUN API
   │
   │  POST https://api.mailgun.net/v3/{domain}/messages
   │  Authorization: Basic {apiKey}
   │
   ▼
7. RESPONSE TO CLIENT
   │
   │  { success: true, message: 'OTP sent to email' }
   │
   ▼
8. CLIENT
   │
   │  Display: "Verification code sent!"
```

---

## 🌍 Regional Deployment

```
┌────────────────────────────────────────┐
│  Google Cloud Platform                  │
│  ──────────────────────────────────     │
│                                         │
│  ┌────────────────────────────────┐    │
│  │  australia-southeast1          │    │
│  │  (Sydney, Australia)           │    │
│  │  ──────────────────────────    │    │
│  │                                │    │
│  │  • All 17 Cloud Functions      │    │
│  │  • Secret Manager              │    │
│  │  • Firestore                   │    │
│  │  • Cloud Run (Web Dashboard)   │    │
│  │                                │    │
│  │  Latency to AU clients: ~10ms  │    │
│  │                                │    │
│  └────────────────────────────────┘    │
│                                         │
└────────────────────────────────────────┘
```

**Why australia-southeast1?**
- Lowest latency for Australian users
- Data residency compliance
- Global Payments API is AU-based
- PayID is Australian payment system

---

## 🔐 IAM & Permissions

```
Service Account: {PROJECT_ID}@appspot.gserviceaccount.com
│
├─ roles/cloudfunctions.invoker
│  └─ Allows Cloud Functions to be invoked
│
├─ roles/secretmanager.secretAccessor
│  └─ Allows reading secrets from Secret Manager
│
├─ roles/datastore.user
│  └─ Allows read/write to Firestore
│
└─ roles/firebase.admin
   └─ Allows Firebase Admin SDK operations
```

---

## 📊 Data Flow

```
┌──────────────┐
│   Flutter    │
│   Android    │
└──────┬───────┘
       │
       │ 1. Generate QR
       ▼
┌──────────────────┐       2. Store Intent      ┌───────────────┐
│  generatePayIDQR │─────────────────────────────►│   Firestore   │
│   (Function)     │                              │   /payments   │
└──────┬───────────┘                              └───────┬───────┘
       │                                                  │
       │ 3. Return QR Data                               │
       ▼                                                  │
┌──────────────┐                                         │
│   Flutter    │                                         │
│   Displays   │                                         │
│   QR Code    │                                         │
└──────────────┘                                         │
                                                         │
       ┌─────────────────────────────────────────────────┘
       │ 4. Customer scans QR
       │    and pays via bank app
       │
       ▼
┌──────────────────┐       5. Payment webhook    ┌───────────────┐
│  Global Payments │─────────────────────────────►│  processGlobal│
│     (External)   │                              │    Payment    │
└──────────────────┘                              └───────┬───────┘
                                                          │
                                                          │ 6. Update status
                                                          ▼
                                                  ┌───────────────┐
                                                  │   Firestore   │
                                                  │   status: paid│
                                                  └───────┬───────┘
                                                          │
       ┌──────────────────────────────────────────────────┘
       │ 7. Flutter polls for status
       ▼
┌──────────────────┐
│  checkPayIDStatus│
│   (Function)     │
└──────┬───────────┘
       │
       │ 8. Return: { status: 'paid' }
       ▼
┌──────────────┐
│   Flutter    │
│   Shows      │
│   Success ✓  │
└──────────────┘
```

---

## 🔧 Configuration Pattern

### ✅ Correct Pattern (After Migration)

```javascript
// In module file (e.g., send_otp_email.js)
const { defineSecret } = require('firebase-functions/params');
const functions = require('firebase-functions');

// Define secrets at module level
const MAILGUN_API_KEY = defineSecret('MAILGUN_API_KEY');
const MAILGUN_DOMAIN = defineSecret('MAILGUN_DOMAIN');

// Export function with region and secrets declared
exports.sendOtp = functions
  .region('australia-southeast1')  // ✅ Region specified
  .runWith({
    timeoutSeconds: 60,
    memory: '256MB',
    secrets: [MAILGUN_API_KEY, MAILGUN_DOMAIN]  // ✅ Secrets declared
  })
  .https.onCall(async (data, context) => {
    // Access secrets inside function
    const apiKey = MAILGUN_API_KEY.value();  // ✅ Correct
    const domain = MAILGUN_DOMAIN.value();   // ✅ Correct

    // Use secrets...
  });
```

### ❌ Incorrect Pattern (Before Migration)

```javascript
// Missing region specification
exports.appUninstalled = functions
  .runWith({ secrets: [SHOPIFY_API_SECRET] })  // ❌ No region!
  .https.onRequest(async (req, res) => {
    // This causes INTERNAL error
  });
```

---

**Last Updated:** 2024-12-11
**Architecture Version:** 2.0 (Secret Manager)
