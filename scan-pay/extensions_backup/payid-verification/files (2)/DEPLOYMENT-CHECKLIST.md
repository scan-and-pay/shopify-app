# 🚀 Deployment Checklist

Use this checklist to deploy the Scan & Pay system step by step.

## Prerequisites Setup

### 1. Accounts & Services

- [ ] Firebase account created at https://console.firebase.google.com
- [ ] Global Payments Oceania account with API access
- [ ] Twilio account for SMS OTP (https://www.twilio.com)
- [ ] SendGrid account for Email OTP (https://sendgrid.com)
- [ ] Shopify store (for production deployment)
- [ ] Domain name (optional but recommended)

### 2. Development Tools

- [ ] Node.js installed (v18 or higher)
- [ ] Firebase CLI installed: `npm install -g firebase-tools`
- [ ] Git installed
- [ ] Code editor (VS Code recommended)

---

## Firebase Setup

### 3. Create Firebase Project

- [ ] Go to https://console.firebase.google.com
- [ ] Click "Add Project"
- [ ] Enter project name: `scanandpay-prod`
- [ ] Disable Google Analytics (or enable if needed)
- [ ] Create project

### 4. Enable Firebase Services

- [ ] **Authentication**:
  - Enable Phone authentication
  - Enable Email/Password authentication
  - Add authorized domains
  
- [ ] **Firestore Database**:
  - Create database in production mode
  - Set region to closest to Australia (e.g., `australia-southeast1`)
  
- [ ] **Cloud Functions**:
  - Enable Cloud Functions
  - Upgrade to Blaze plan (pay-as-you-go)
  
- [ ] **Hosting** (optional):
  - Enable if deploying frontend to Firebase

### 5. Firebase CLI Authentication

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Initialize project
cd your-project-directory
firebase init

# Select:
# ✅ Functions
# ✅ Firestore
# ✅ Hosting (if needed)

# Choose existing project: scanandpay-prod
```

---

## Global Payments Configuration

### 6. Global Payments API Access

- [ ] Login to https://docs.gpaunz.com
- [ ] Navigate to API Credentials
- [ ] Note your:
  - API Key
  - API Secret
  - Merchant ID
  
- [ ] Test in Sandbox first:
  - [ ] Make test PayID payment
  - [ ] Verify webhook received
  - [ ] Confirm transaction appears

### 7. Configure Webhook

- [ ] Go to Webhooks section in GP dashboard
- [ ] Click "Create Webhook Subscription"
- [ ] Enter details:
  - URL: `https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook`
  - Events: Select "transactions"
  - Status: Active
  
- [ ] Save and note your **Webhook Private Key**
- [ ] Test webhook with sample payload

---

## Third-Party Services

### 8. Twilio Setup (SMS OTP)

- [ ] Sign up at https://www.twilio.com
- [ ] Get trial account or purchase phone number
- [ ] Note credentials:
  - Account SID
  - Auth Token
  - Phone Number (format: +61XXXXXXXXX)
  
- [ ] Add test phone number in trial mode

### 9. SendGrid Setup (Email OTP)

- [ ] Sign up at https://sendgrid.com
- [ ] Verify sender email address
- [ ] Create API Key with full access
- [ ] Note:
  - API Key
  - Verified sender email
  
- [ ] Test sending email

---

## Code Deployment

### 10. Prepare Functions

```bash
cd functions

# Install dependencies
npm install firebase-functions firebase-admin

# Copy webhook handler
cp /path/to/global-payments-webhook.js index.js

# Review package.json
cat package.json
```

package.json should include:
```json
{
  "dependencies": {
    "firebase-admin": "^11.0.0",
    "firebase-functions": "^4.0.0"
  }
}
```

### 11. Set Environment Variables

```bash
# Global Payments
firebase functions:config:set \
  globalpayments.private_key="YOUR_GP_PRIVATE_KEY" \
  globalpayments.api_key="YOUR_GP_API_KEY"

# Twilio
firebase functions:config:set \
  twilio.account_sid="YOUR_TWILIO_SID" \
  twilio.auth_token="YOUR_TWILIO_TOKEN" \
  twilio.phone_number="+61XXXXXXXXX"

# SendGrid
firebase functions:config:set \
  sendgrid.api_key="YOUR_SENDGRID_KEY" \
  sendgrid.from_email="noreply@scanandpay.com.au"

# Verify all config
firebase functions:config:get
```

### 12. Deploy Firestore Rules

Create `firestore.rules`:
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /merchants/{merchantId} {
      allow read, write: if request.auth != null 
                         && request.auth.uid == resource.data.userId;
    }
    
    match /products/{productId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    
    match /orders/{orderId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
    }
    
    match /transactions/{transactionId} {
      allow read: if request.auth != null;
      allow write: if false; // Only Cloud Functions
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

### 13. Deploy Cloud Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Or deploy specific function
firebase deploy --only functions:globalPaymentsWebhook
firebase deploy --only functions:verifyPayment

# Check deployment
firebase functions:list
```

### 14. Get Function URLs

```bash
# Get webhook URL
firebase functions:config:get

# URLs will be:
# https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook
# https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/verifyPayment
```

- [ ] Copy webhook URL
- [ ] Update Global Payments dashboard with this URL
- [ ] Copy verify payment URL for frontend

---

## Frontend Deployment

### 15. Update Frontend Config

Edit `payid-qr-payment.html` and `shopify-buyer-checkout.html`:

```javascript
// Update Firebase config
const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID"
};

// Update verification API URL
const VERIFY_API_URL = 'https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/verifyPayment';
```

### 16. Deploy to Firebase Hosting (Optional)

```bash
# Build frontend
npm run build

# Deploy
firebase deploy --only hosting

# Or upload to your own hosting
```

---

## Testing

### 17. Test Webhook Reception

```bash
# Create test webhook payload
cat > test-webhook.json << 'EOF'
{
  "id": "test-webhook-123",
  "reference": "REF-2024-TEST001",
  "created": "2025-01-01T00:00:00Z",
  "version": "1.0.0",
  "event": "transactions",
  "payload": {
    "id": "test-txn-456",
    "createdDateTime": "2025-01-01T00:00:00Z",
    "updatedDateTime": "2025-01-01T00:00:05Z",
    "category": {
      "source": "payto",
      "method": "purchase"
    },
    "payment": {
      "amount": 15000,
      "currencyCode": "AUD"
    },
    "result": {
      "status": "approved"
    }
  }
}
EOF

# Send test webhook
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/globalPaymentsWebhook \
  -H "Content-Type: application/json" \
  -d @test-webhook.json

# Check logs
firebase functions:log --only globalPaymentsWebhook
```

Expected response:
```json
{
  "success": true,
  "message": "Webhook processed successfully",
  "verified": true
}
```

### 18. Test Payment Verification

```bash
# Test verification API
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/verifyPayment \
  -H "Content-Type: application/json" \
  -d '{
    "reference": "REF-2024-TEST001",
    "amount": 150.00,
    "payId": "test@example.com"
  }'

# Check logs
firebase functions:log --only verifyPayment
```

Expected response:
```json
{
  "status": "paid",
  "verified": true,
  "transactionId": "test-txn-456",
  "amount": 150.00
}
```

### 19. Test SMS OTP (if implemented)

```bash
# Test sending SMS
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/sendSMSOTP \
  -H "Content-Type: application/json" \
  -d '{"phoneNumber": "+61400000000"}'

# Check Twilio logs
# Check Firebase logs
firebase functions:log --only sendSMSOTP
```

### 20. Test End-to-End Flow

- [ ] Open frontend in browser
- [ ] Add items to cart
- [ ] Proceed to checkout
- [ ] Enter delivery address
- [ ] See QR code displayed
- [ ] Make test payment using GP test credentials
- [ ] Click "I've Paid"
- [ ] Verify order confirms successfully

---

## Monitoring & Maintenance

### 21. Set Up Monitoring

- [ ] Enable Firebase Analytics
- [ ] Set up Firebase Crashlytics
- [ ] Configure function timeout alerts
- [ ] Set up cost alerts in GCP

### 22. Regular Checks

- [ ] Monitor Firebase function logs daily
- [ ] Check Global Payments webhook delivery status
- [ ] Review transaction data in Firestore
- [ ] Monitor Twilio/SendGrid usage

---

## Production Readiness

### 23. Security Checklist

- [ ] Webhook signature verification enabled
- [ ] Firestore security rules deployed
- [ ] API keys stored in environment variables (not code)
- [ ] HTTPS enforced on all endpoints
- [ ] CORS properly configured
- [ ] Rate limiting implemented (if needed)

### 24. Performance Checklist

- [ ] Cloud Functions have adequate memory (256MB minimum)
- [ ] Firestore indexes created for common queries
- [ ] Frontend assets minified
- [ ] Images optimized
- [ ] CDN enabled (if using Firebase Hosting)

### 25. Compliance Checklist

- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] PCI DSS compliance reviewed (for payment data)
- [ ] GDPR compliance (if applicable)
- [ ] Cookie consent implemented (if needed)

---

## Launch

### 26. Soft Launch

- [ ] Deploy to production
- [ ] Test with real PayID account
- [ ] Process test transactions with small amounts
- [ ] Verify webhooks working
- [ ] Check all emails/SMS sending correctly

### 27. Shopify App Store Submission

- [ ] Create Shopify Partner account
- [ ] Create app listing
- [ ] Add screenshots and description
- [ ] Set pricing (if applicable)
- [ ] Submit for review
- [ ] Address any feedback from Shopify

### 28. Go Live

- [ ] Announce to merchants
- [ ] Monitor closely for first 24 hours
- [ ] Be ready to rollback if issues
- [ ] Collect user feedback
- [ ] Iterate and improve

---

## Post-Launch

### 29. Support Setup

- [ ] Create support email: support@scanandpay.com.au
- [ ] Set up ticket system (Zendesk, Freshdesk, etc.)
- [ ] Create knowledge base
- [ ] Train support team

### 30. Marketing

- [ ] Launch announcement email
- [ ] Social media posts
- [ ] Partner outreach
- [ ] Content marketing (blog posts)
- [ ] SEO optimization

---

## Quick Reference

### Important URLs

- Firebase Console: https://console.firebase.google.com
- Global Payments Docs: https://docs.gpaunz.com
- Shopify Partners: https://partners.shopify.com
- Twilio Console: https://console.twilio.com
- SendGrid Dashboard: https://app.sendgrid.com

### Key Commands

```bash
# Deploy everything
firebase deploy

# Deploy functions only
firebase deploy --only functions

# View logs
firebase functions:log

# View config
firebase functions:config:get

# Test locally
firebase emulators:start
```

---

## Troubleshooting

### Common Issues

**Webhook not received:**
- Check URL in GP dashboard
- Verify function deployed: `firebase functions:list`
- Check logs: `firebase functions:log`

**Payment not verifying:**
- Check amount in cents vs dollars
- Verify reference matches exactly
- Check Firestore for transaction

**OTP not sending:**
- Check Twilio/SendGrid credentials
- Verify phone/email format
- Review function logs

---

## Done!

Once all items are checked off, your system is ready for production.

For detailed documentation, see:
- **CLAUDE.md** - Complete system documentation
- **README.md** - Quick start guide
- Chat history links in CLAUDE.md

---

**Questions?** Review the documentation first, then check Firebase logs.

**Need help?** All code was developed collaboratively - see CLAUDE.md for chat history links.
