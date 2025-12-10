# ScanAndPay Infrastructure & Authentication Overview

This document provides a complete overview of the ScanAndPay system architecture, Firebase configuration, Cloud Run services, Shopify integration, and SMS authentication setup.
It applies to both the Android app (scanandpay) and the Shopify web app (shopify-app), which share the same Firebase backend.

## 1. Firebase / Google Cloud Project Details

| Item | Value |
|------|-------|
| Project Name | ScanAndPay |
| Project ID | scan-and-pay-guihzm |
| Project Number | 291088983781 |
| Firebase Backend | Shared across Android + Shopify web |

## 2. Application Structure

### Android App (Flutter)

- Code folder: `scanandpay`
- Uses Firebase Authentication (Phone) + Firestore
- Uses native SMS auth (no reCAPTCHA required)

### Shopify Web App (Flutter Web)

- Code folder: `shopify-app`
- Deployed using Cloud Run (Docker)
- Runs inside Shopify Admin iframe
- Uses Firebase Web Phone Auth (requires reCAPTCHA)
- Requires CSP + Authorized Domains configuration

## 3. Cloud Run Services

### Primary Shopify Web App Service

| Component | Value |
|-----------|-------|
| Service Name | shopify-app-merchants |
| Region | europe-west1 |
| Reason | Shopify requires webhook endpoints in EU regions |
| Runtime | Docker (Flutter Web + NGINX) |
| URL | https://shopify-app-merchants-<id>-ew.a.run.app/ |

### Additional Details

| Service | Region |
|---------|--------|
| merchant-dashboard (if used) | australia-southeast1 |
| Firebase Functions | australia-southeast1 |

**Note:** Cloud Run region does not affect Firebase phone auth.

## 4. Custom Domains

### Production App Domain
- https://merchants.scanandpay.com.au/

### Shopify Storefront Domains
- https://scanpay-2.myshopify.com/
- https://shop.scanandpay.com.au/

All of these must be authorized in Firebase.

## 5. Firebase Auth – Authorized Domains (Final Configuration)

Required authorized domains for Firebase Web Phone Auth:

- localhost
- scan-and-pay-guihzm.firebaseapp.com
- scan-and-pay-guihzm.web.app
- flutter-scanpay.netlify.app
- merchants.scanandpay.com.au
- shopify-app-merchants-<id>-ew.a.run.app
- admin.shopify.com
- scanpay-2.myshopify.com
- shop.scanandpay.com.au

**Notes:**
- Firebase does not support wildcards like `*.myshopify.com`
- Each Shopify domain must be added explicitly

## 6. NGINX CSP Configuration (Critical for Shopify + reCAPTCHA)

Your `nginx-webhook.conf` must include:

### Content Security Policy
```nginx
add_header Content-Security-Policy "
  frame-ancestors 'self' https://*.myshopify.com https://admin.shopify.com https://merchants.scanandpay.com.au;
  script-src 'self' 'unsafe-inline' 'unsafe-eval'
    https://www.gstatic.com https://www.google.com
    https://www.gstatic.com/recaptcha/ https://www.google.com/recaptcha/;
" always;
```

### Frame Embedding
```nginx
add_header X-Frame-Options "ALLOW-FROM https://admin.shopify.com" always;
```

**Why required?**
- Shopify loads your app inside an iframe
- reCAPTCHA must load inside that iframe
- Without these headers, Firebase phone auth fails

## 7. Firebase Functions Region Fix

All functions must be in:
```
australia-southeast1
```

If nginx routes webhooks, update:
```
us-central1 → australia-southeast1
```

This prevents webhook failures.

## 8. Cloud Run Deployment Commands

### Deploy Shopify app:
```bash
gcloud run deploy shopify-app-merchants \
  --source . \
  --region=europe-west1 \
  --platform=managed \
  --allow-unauthenticated \
  --port=8080 \
  --project=scan-and-pay-guihzm
```

### Check service status:
```bash
gcloud run services describe shopify-app-merchants \
  --region=europe-west1 \
  --format="value(status.url,status.latestReadyRevisionName)" \
  --project=scan-and-pay-guihzm
```

### Check domain mapping:
```bash
gcloud beta run domain-mappings describe merchants.scanandpay.com.au \
  --region=europe-west1 \
  --project=scan-and-pay-guihzm
```

## 9. SMS Authentication Flow (Web)

Web SMS auth uses Firebase Web SDK and requires:
- Authorized domains
- CSP headers
- reCAPTCHA container in Flutter Web's index.html
- Correct Firebase config

### Expected Network Calls

| Action | Endpoint |
|--------|----------|
| reCAPTCHA load | https://www.google.com/recaptcha/ |
| Send verification code | identitytoolkit.googleapis.com/v1/accounts:sendVerificationCode |
| Verify OTP | identitytoolkit.googleapis.com/v1/accounts:signInWithPhoneNumber |

## 10. Testing Checklist

### Direct Domain Test
1. Visit https://merchants.scanandpay.com.au
2. Open Console + Network
3. Trigger SMS OTP

**Expected:**
- reCAPTCHA loads
- No CSP or domain errors
- SMS arrives

### Shopify Embedded Test
1. Open https://admin.shopify.com/store/scanpay-2/apps/...
2. Load the app inside iframe
3. Test SMS OTP

**Expected:**
- No "Hostname match not found"
- No CSP violations
- OTP flow completes

## 11. Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| Hostname match not found | Missing authorized domain | Add domains in Firebase |
| reCAPTCHA fails to load | CSP blocking scripts | Fix nginx CSP |
| auth/unauthorized-domain | Domain not authorized | Add domain |
| iframe blocked | Missing X-Frame-Options | Update nginx headers |

## 12. Summary

The ScanAndPay infrastructure is now correctly configured:

- Firebase project: `scan-and-pay-guihzm`
- Cloud Run service: `shopify-app-merchants` (europe-west1)
- Shopify iframe allowed
- reCAPTCHA allowed
- All required domains authorized
- SMS authentication working on Android + Web

This README serves as the authoritative reference for future developers and deployments.
