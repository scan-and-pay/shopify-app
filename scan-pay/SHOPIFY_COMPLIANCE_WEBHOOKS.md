# Shopify Compliance Webhooks Implementation

## Overview
This document describes the implementation of Shopify's mandatory compliance webhooks for the Scan & Pay app, required to pass automated checks in the Shopify Partner Dashboard.

## Implementation Summary

### 1. Webhook Routes Created
All webhooks are implemented in the `app/routes/` directory following the React Router pattern:

#### **webhooks.app.uninstalled.tsx** (Updated)
- **Topic**: `app/uninstalled`
- **Purpose**: Handles app uninstallation
- **Implementation**:
  - Marks shop as uninstalled in `AppInstallation` table
  - Deletes all sessions for the shop
  - Logs uninstallation event
  - Returns HTTP 200

#### **webhooks.customers.data_request.tsx** (New)
- **Topic**: `customers/data_request`
- **Purpose**: GDPR data request - merchant must provide customer data within 30 days
- **Implementation**:
  - Logs the data request with customer ID and shop domain
  - Returns HTTP 200 immediately
  - TODO: Implement actual data export to Firebase/email

#### **webhooks.customers.redact.tsx** (New)
- **Topic**: `customers/redact`
- **Purpose**: GDPR erasure request - merchant must delete customer data within 30 days
- **Implementation**:
  - Logs the redaction request with customer ID
  - Returns HTTP 200 immediately
  - TODO: Implement Firebase function call to delete customer data

#### **webhooks.shop.redact.tsx** (New)
- **Topic**: `shop/redact`
- **Purpose**: Shop data deletion - sent 48 hours after uninstall
- **Implementation**:
  - Deletes all shop sessions from local database
  - Logs the redaction request
  - Returns HTTP 200 immediately
  - TODO: Implement Firebase function call to delete all shop data

### 2. HMAC Verification
All webhooks automatically use HMAC verification through Shopify's `authenticate.webhook(request)` helper:

```typescript
const { shop, topic, payload } = await authenticate.webhook(request);
```

This helper:
- Reads the raw request body
- Computes HMAC SHA-256 using `SHOPIFY_API_SECRET`
- Compares with `X-Shopify-Hmac-SHA256` header
- Returns HTTP 401 if verification fails
- Parses the payload if verification succeeds

### 3. Webhook Registration
Webhooks are registered in `shopify.app.toml`:

```toml
[webhooks]
api_version = "2025-10"

  [[webhooks.subscriptions]]
  topics = [ "app/uninstalled" ]
  uri = "/webhooks/app/uninstalled"

  [[webhooks.subscriptions]]
  topics = [ "customers/data_request" ]
  uri = "/webhooks/customers/data_request"

  [[webhooks.subscriptions]]
  topics = [ "customers/redact" ]
  uri = "/webhooks/customers/redact"

  [[webhooks.subscriptions]]
  topics = [ "shop/redact" ]
  uri = "/webhooks/shop/redact"
```

Shopify automatically syncs these webhooks on every `npm run deploy`.

### 4. Database Changes

#### New Model: AppInstallation
Added to `prisma/schema.prisma`:

```prisma
model AppInstallation {
  id            String    @id @default(uuid())
  shop          String    @unique
  installed     Boolean   @default(true)
  installedAt   DateTime  @default(now())
  uninstalledAt DateTime?
  updatedAt     DateTime  @updatedAt
}
```

**Purpose**: Tracks installation status of shops, allowing us to:
- Know when a shop uninstalled the app
- Differentiate between active and inactive merchants
- Provide audit trail for compliance

**Migration**: `20251210023703_add_app_installation`

## Testing

### Local Testing with Shopify CLI

1. Start the dev server:
```bash
cd scan-pay
npm run dev
```

2. Trigger webhook events:
```bash
shopify app webhook trigger --topic customers/data_request
shopify app webhook trigger --topic customers/redact
shopify app webhook trigger --topic shop/redact
shopify app webhook trigger --topic app/uninstalled
```

### Verify HMAC Verification

The `authenticate.webhook(request)` helper automatically:
- ✅ Rejects requests with invalid HMAC (returns 401)
- ✅ Accepts requests with valid HMAC (processes webhook)
- ✅ Uses the API secret from `SHOPIFY_API_SECRET` env variable

To test manually:
1. Send a POST request without proper HMAC → should get 401
2. Send a POST request with proper HMAC → should get 200

### Check Automated Compliance

After deployment:
1. Go to **Shopify Partner Dashboard** → Your App
2. Navigate to **App Listing** → **Automated checks for common errors**
3. Click **Run checks**

Expected results:
- ✅ Provides mandatory compliance webhooks
- ✅ Verifies webhooks with HMAC signatures

## Deployment

### Deployment Status: ⚠️ PENDING - DEPLOY TO CORRECT ORG

**Previous deployment** was to wrong organization (194602742) - those apps should be deleted.

**Correct Organization**: 194668629
**Dashboard URL**: https://dev.shopify.com/dashboard/194668629/apps

After updating `client_id` in `shopify.app.toml`, run:
```bash
cd scan-pay
shopify app deploy --force --reset
```

### Deployed Configuration

The following webhooks are automatically registered via `shopify.app.toml`:
- `app/uninstalled` → `/webhooks/app/uninstalled`
- `app/scopes_update` → `/webhooks/app/scopes_update`

### GDPR Compliance Webhooks (Auto-Registered by Shopify)

The following webhook endpoints are **ready and waiting** for Shopify's automated testing:
- `/webhooks/customers/data_request` - GDPR data request handler
- `/webhooks/customers/redact` - Customer data deletion handler
- `/webhooks/shop/redact` - Shop data deletion handler

**Important Note**: GDPR compliance webhooks (`customers/data_request`, `customers/redact`, `shop/redact`) are **automatically tested by Shopify** when you run "Automated Checks" in the Partner Dashboard. They do not need to be pre-registered in `shopify.app.toml`.

### How to Deploy Updates

```bash
cd scan-pay
shopify app deploy --force
```

This will:
- Build the app
- Bundle extensions
- Deploy to Shopify
- Register webhooks from `shopify.app.toml`
- Create a new app version

## TODO: Future Enhancements

### 1. Firebase Integration for Data Deletion

Create Firebase Cloud Functions to handle actual data deletion:

**Function: `cleanupMerchantData`**
- Input: `{ shop: string }`
- Action: Delete all merchant data from Firestore
- Called from: `webhooks.app.uninstalled.tsx`

**Function: `deleteCustomerData`**
- Input: `{ shop: string, customerId: number }`
- Action: Delete specific customer data from Firestore
- Called from: `webhooks.customers.redact.tsx`

**Function: `deleteShopData`**
- Input: `{ shop: string, shopId: number }`
- Action: Delete all shop and customer data from Firestore
- Called from: `webhooks.shop.redact.tsx`

**Function: `exportCustomerData`**
- Input: `{ shop: string, customerId: number, email: string }`
- Action: Export customer data and email to customer
- Called from: `webhooks.customers.data_request.tsx`

### 2. Audit Logging

Add comprehensive audit logging for compliance:
- Log all webhook events to Firestore
- Track data deletion timestamps
- Store data export confirmations

### 3. Email Notifications

Send email notifications to merchants when:
- App is uninstalled
- GDPR data request received (30-day deadline)
- Customer data redaction requested (30-day deadline)

## Environment Variables

Required environment variables in `.env`:

```env
SHOPIFY_API_KEY=your_api_key
SHOPIFY_API_SECRET=your_api_secret
SHOPIFY_APP_URL=https://merchants.scanandpay.com.au
```

## Files Modified

1. **app/routes/webhooks.customers.data_request.tsx** - New file
2. **app/routes/webhooks.customers.redact.tsx** - New file
3. **app/routes/webhooks.shop.redact.tsx** - New file
4. **app/routes/webhooks.app.uninstalled.tsx** - Updated to track uninstallation
5. **prisma/schema.prisma** - Added AppInstallation model
6. **shopify.app.toml** - Added compliance webhook subscriptions, updated API version to 2025-10
7. **prisma/migrations/20251210023703_add_app_installation/** - New migration

## Compliance Status

| Requirement | Status |
|------------|--------|
| Provides mandatory compliance webhooks | ✅ Implemented |
| Verifies webhooks with HMAC signatures | ✅ Implemented |
| Responds with HTTP 200 within 5 seconds | ✅ Implemented |
| Handles GDPR data requests | ⚠️ Logging only (needs full implementation) |
| Deletes customer data on redact | ⚠️ Logging only (needs full implementation) |
| Deletes shop data on redact | ⚠️ Partial (local DB only, needs Firebase) |

## Notes

- All webhooks use the `authenticate.webhook()` helper which handles HMAC verification automatically
- Webhooks are idempotent - they can be called multiple times safely
- The app uses SQLite for local development, but supports PostgreSQL/MySQL for production
- API version is set to `2025-10` as required by Shopify
- Webhooks are app-specific (not shop-specific), meaning they're automatically registered for all shops that install the app
