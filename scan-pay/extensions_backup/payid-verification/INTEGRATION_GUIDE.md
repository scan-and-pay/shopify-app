# PayID Checkout Extension - Integration Guide

## Overview

This Shopify checkout extension integrates with the **Scan & Pay** backend platform to enable real-time PayID payments via NPP-compliant QR codes and Global Payments Oceania infrastructure.

---

## Architecture

### System Components

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────────┐
│                 │      │                  │      │                     │
│  Shopify        │─────▶│  Firebase Cloud  │─────▶│  Global Payments   │
│  Checkout UI    │      │  Functions       │      │  Oceania API        │
│  Extension      │      │  (Backend)       │      │  (PayID/PayTo)      │
│                 │      │                  │      │                     │
└─────────────────┘      └──────────────────┘      └─────────────────────┘
        │                        │                           │
        │                        │                           │
        │                        ▼                           │
        │                ┌──────────────┐                   │
        │                │              │                   │
        └───────────────▶│  Firestore   │◀──────────────────┘
                         │  Database    │
                         │              │
                         └──────────────┘
```

### Payment Flow

1. **Checkout Initialization**
   - Customer reaches Shopify checkout page
   - Extension displays "Pay with PayID" button

2. **QR Code Generation**
   - Customer clicks payment button
   - Extension calls `generatePayIDQR` Firebase Function
   - Backend generates NPP-compliant QR code with:
     - Merchant PayID
     - Payment amount (AUD)
     - Unique reference number
     - Merchant name
     - CRC16 checksum

3. **Customer Payment**
   - Customer scans QR code with banking app
   - Banking app pre-fills PayID payment details
   - Customer confirms payment in their bank

4. **Payment Verification**
   - Customer clicks "I've Paid" button
   - Extension polls `verifyPayment` endpoint (every 3 seconds)
   - Backend checks Global Payments webhook records in Firestore
   - Returns payment status: `paid`, `unpaid`, or `pending`

5. **Checkout Completion**
   - Once payment confirmed, checkout proceeds
   - Transaction details stored in checkout attributes

---

## Backend API Endpoints

### Base URL
```
Production: https://australia-southeast1-scan-and-pay-guihzm.cloudfunctions.net
Region: australia-southeast1 (Sydney)
```

### 1. Generate PayID QR Code

**Endpoint**: `POST /generatePayIDQR`

**Request Body**:
```json
{
  "payId": "merchant@example.com",
  "amount": 125.50,
  "reference": "REF-2024-ABC123",
  "merchantName": "My Store Pty Ltd"
}
```

**Response**:
```json
{
  "success": true,
  "paymentId": "pmt_abc123xyz",
  "qrCodeDataUrl": "data:image/png;base64,iVBORw0KGgoAAAANS...",
  "qrData": "NPP formatted QR payload string",
  "reference": "REF-2024-ABC123",
  "amount": 125.50,
  "payId": "merchant@example.com",
  "expiresAt": "2024-12-05T12:35:00Z"
}
```

**Features**:
- NPP/EMV compliant QR code format
- Cryptographically secure reference generation
- 5-minute payment expiry
- CRC16 checksum validation

### 2. Verify Payment

**Endpoint**: `GET /verifyPayment?reference={ref}&amount={cents}&payId={payid}`

**Query Parameters**:
- `reference`: Payment reference (e.g., "REF-2024-ABC123")
- `amount`: Amount in cents (e.g., "12550" for $125.50)
- `payId`: Merchant PayID

**Response**:
```json
{
  "status": "paid",
  "verified": true,
  "transactionId": "txn_xyz789",
  "amount": 12550,
  "reference": "REF-2024-ABC123",
  "paidAt": "2024-12-05T12:32:45Z"
}
```

**Status Values**:
- `paid`: Payment confirmed via webhook
- `unpaid`: No payment record found
- `pending`: Payment initiated but not yet settled

**Implementation**:
- Queries Firestore `/transactions` collection
- Matches on reference + amount + PayID
- Verifies webhook signature (HMAC SHA-256)
- Returns Global Payments transaction data

### 3. Check Payment Status

**Endpoint**: `GET /checkPayIDStatus?paymentId={id}`

**Query Parameters**:
- `paymentId`: Payment ID from QR generation

**Response**:
```json
{
  "status": "success",
  "payment": {
    "paymentId": "pmt_abc123xyz",
    "status": "paid",
    "amount": 125.50,
    "reference": "REF-2024-ABC123",
    "paidAt": "2024-12-05T12:32:45Z"
  }
}
```

---

## Database Schema

### Firestore Collections

#### `/payments/{paymentId}`
```javascript
{
  paymentId: "pmt_abc123xyz",
  amount: 125.50,
  reference: "REF-2024-ABC123",
  payId: "merchant@example.com",
  merchantName: "My Store Pty Ltd",
  status: "pending" | "success" | "failed" | "expired",
  qrData: "NPP QR payload",
  qrCodeDataUrl: "data:image/png;base64,...",
  createdAt: Timestamp,
  expiresAt: Timestamp,
  paidAt: Timestamp | null,
  createdBy: "userId" | null
}
```

#### `/transactions/{webhookId}`
```javascript
{
  webhookId: "wh_xyz789",
  reference: "REF-2024-ABC123",
  transactionId: "txn_xyz789",
  orderId: "order_123",
  amount: 12550, // cents
  currencyCode: "AUD",
  status: "success",
  verified: true,
  paymentStatus: "PAID" | "PENDING" | "DECLINED",
  globalPaymentsData: { /* raw webhook payload */ },
  receivedAt: Timestamp
}
```

#### `/users/{userId}`
```javascript
{
  uid: "user123",
  email: "merchant@example.com",
  payId: "merchant@example.com",
  businessName: "My Store Pty Ltd",
  abn: "12345678901",
  authMethod: "email" | "phone",
  createdAt: Timestamp
}
```

---

## Extension Configuration

### Merchant Settings

Configure these settings in the Shopify Partner Dashboard when installing the extension:

1. **Merchant PayID** (Required)
   - Your PayID (email or Australian mobile number)
   - Example: `payments@mystore.com.au` or `0412345678`
   - This is where customer payments will be sent

2. **Merchant Name** (Required)
   - Business name displayed on QR code
   - Example: `My Store Pty Ltd`
   - Shows on customer's banking app

3. **Firebase Project ID** (Optional)
   - Default: `scan-and-pay-guihzm`
   - Only change if using a custom Firebase project

4. **Enable Manual Entry** (Optional)
   - Default: `true`
   - Allows customers to manually enter PayID details if QR scan fails

### Extension Capabilities

Required permissions in `shopify.extension.toml`:
- ✅ `network_access`: Make external API calls to Firebase
- ✅ `api_access`: Query Shopify Storefront API
- ✅ `checkout_ui_extensions`: Render UI in checkout

---

## Security

### Authentication & Authorization

1. **No Firebase Auth Required**
   - Public endpoints for payment generation/verification
   - Authentication enforced at Global Payments level

2. **Webhook Signature Verification**
   - HMAC SHA-256 signature validation
   - Secret key stored in Google Cloud Secret Manager
   - Prevents webhook forgery

3. **Amount Validation**
   - Exact amount matching (down to the cent)
   - Reference number uniqueness
   - Prevents payment fraud

### Data Protection

1. **Secrets Management**
   - Google Cloud Secret Manager for API keys
   - 1-hour TTL in-memory caching
   - No secrets in codebase

2. **Firestore Security Rules**
   ```javascript
   // Default deny all
   match /{document=**} {
     allow read, write: if false;
   }

   // Users can only access their own data
   match /users/{userId} {
     allow read, write: if request.auth.uid == userId;
   }

   // Cloud Functions only
   match /transactions/{transactionId} {
     allow read, write: if false;
   }
   ```

3. **HTTPS Only**
   - All API calls over TLS 1.2+
   - Firebase enforces HTTPS automatically

---

## Error Handling

### Common Error Scenarios

#### 1. QR Code Generation Failed
```javascript
{
  "error": "Failed to generate QR code",
  "message": "Invalid PayID format"
}
```
**Resolution**: Validate PayID format (email or mobile)

#### 2. Payment Verification Timeout
- **Cause**: Payment not received within 2 minutes (40 polls × 3 seconds)
- **User Message**: "Payment verification timeout. Please contact support if you completed the payment."
- **Resolution**: Manual reconciliation via admin panel

#### 3. Amount Mismatch
```javascript
{
  "status": "unpaid",
  "message": "Amount does not match"
}
```
**Resolution**: Customer must pay exact amount shown on QR code

#### 4. Webhook Not Received
- **Cause**: Global Payments webhook delayed or failed
- **User Message**: "Payment pending. Verification may take a few minutes."
- **Resolution**: Webhook retries automatically; check `/transactions` collection

---

## Testing

### Local Development

1. **Use Firebase Emulator**
   ```bash
   cd C:\scanandpayWeb
   npm run emulator
   ```
   - Emulator URL: `http://localhost:5001/scan-and-pay-guihzm/australia-southeast1`

2. **Update Extension for Local Testing**
   ```javascript
   const FIREBASE_FUNCTION_URL = 'http://localhost:5001/scan-and-pay-guihzm/australia-southeast1';
   ```

3. **Mock Webhook Data**
   - Use `paymentService.ts` mock functions
   - Simulate payment status changes in Firestore

### Production Testing

1. **Test with Small Amount**
   - Use $0.01 or $0.10 for initial tests
   - Verify QR code scans correctly in banking app

2. **Verify Webhook Flow**
   - Complete real payment in banking app
   - Check Firestore `/transactions` collection
   - Confirm webhook signature validation

3. **Test Error Scenarios**
   - Wrong amount payment
   - Expired QR code (after 5 minutes)
   - Cancelled payment

---

## Deployment

### Deploy Extension to Shopify

```bash
cd C:\Shopify\scan-pay\extensions\payid-verification
npm run deploy
```

### Deploy Backend (if modified)

```bash
cd C:\scanandpayWeb
npm run deploy:functions
```

### Environment Setup

**Backend Environment Variables** (Google Cloud Secret Manager):
```
x-master-key=<Global Payments API Key>
GLOBAL_PAYMENTS_WEBHOOK_KEY=<Webhook Secret>
MAILGUN_API_KEY=<Mailgun API Key>
MAILGUN_DOMAIN=<Mailgun Domain>
```

**Frontend Environment Variables** (Shopify Extension Settings):
- Configured via Partner Dashboard
- No `.env` file needed in extension

---

## Monitoring & Logs

### Firebase Console Logs

```bash
# View live logs
firebase functions:log --follow

# View specific function logs
firebase functions:log --only generatePayIDQR
firebase functions:log --only verifyPayment
```

### Firestore Query Examples

**Check recent payments**:
```javascript
db.collection('payments')
  .orderBy('createdAt', 'desc')
  .limit(10)
  .get()
```

**Find payment by reference**:
```javascript
db.collection('transactions')
  .where('reference', '==', 'REF-2024-ABC123')
  .get()
```

---

## Troubleshooting

### Issue: QR Code Not Displaying

**Symptoms**: QR code image fails to load
**Causes**:
1. Network access blocked in extension
2. Firebase function timeout
3. Invalid image data URL

**Solutions**:
- Verify `network_access = true` in `shopify.extension.toml`
- Check Firebase logs for errors
- Test API endpoint directly with curl

### Issue: Payment Verification Always Returns "Unpaid"

**Symptoms**: Customer paid but verification fails
**Causes**:
1. Webhook not received from Global Payments
2. Amount mismatch (rounding errors)
3. Reference not matching

**Solutions**:
- Check `/transactions` collection in Firestore
- Verify webhook endpoint is reachable
- Ensure amount converted to cents correctly (`Math.round(amount * 100)`)

### Issue: Checkout Blocked Despite Payment

**Symptoms**: Buyer journey blocked even after payment confirmed
**Causes**:
1. `payid_status` attribute not set
2. Payment status not updating in state

**Solutions**:
- Check checkout attributes: `order.note_attributes`
- Verify `applyAttributeChange` calls succeed
- Check browser console for errors

---

## Support

### Documentation
- Shopify Checkout Extensions: https://shopify.dev/docs/api/checkout-ui-extensions
- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- Global Payments Oceania: https://developer.globalpay.com/oceania

### Contact
- Technical Support: developer@scanandpay.com.au
- GitHub Issues: [Create Issue]
- Slack: #scan-pay-dev

---

## Changelog

### v1.0.0 (2024-12-05)
- ✅ NPP-compliant QR code generation
- ✅ Real-time payment verification via webhooks
- ✅ Merchant settings configuration
- ✅ Firestore integration for transaction records
- ✅ Global Payments Oceania API integration
- ✅ Error handling and retry logic
- ✅ Buyer journey interception for payment validation

---

## License

Proprietary - Scan & Pay Platform
© 2024 All Rights Reserved
