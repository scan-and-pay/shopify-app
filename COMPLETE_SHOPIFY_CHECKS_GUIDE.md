# Complete Guide: Pass Shopify's Embedded App Checks

## 🎯 Goal
Pass these two automated checks:
1. ✅ "Using the latest App Bridge script loaded from Shopify's CDN"
2. ✅ "Using session tokens for user authentication"

---

## 📦 What You Have

### Files Created:
1. `shopify-app/flutter-app/lib/web/shopify_app_bridge.html` - App Bridge CDN initialization
2. `SHOPIFY_SESSION_TOKEN_EXAMPLE.tsx` - React component with session token usage
3. `shopify-app/flutter-app/functions/shopify_session_token.js` - Firebase verification
4. `shopify-app/flutter-app/functions/index.js` - Updated with new exports

### Dependencies Installed:
- ✅ `jsonwebtoken` - JWT verification
- ✅ `jwks-rsa` - Shopify public key fetching

---

## 🚀 Step-by-Step Implementation

### Step 1: Deploy Firebase Functions

```bash
# 1. Re-authenticate with Firebase (credentials expired)
firebase login --reauth

# 2. Deploy the new session token functions
cd C:\dev\shopify-app\flutter-app\functions
firebase deploy --only functions:getMerchantData,functions:generatePayIDQRWithAuth --project scan-and-pay-guihzm
```

**Expected URLs after deployment**:
- `https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/getMerchantData`
- `https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/generatePayIDQRWithAuth`

---

### Step 2: Update Your React/Flutter Web App

#### Option A: Pure HTML/JS (Simplest)

Add to your `index.html` or main HTML file:

```html
<!DOCTYPE html>
<html>
<head>
  <!-- CRITICAL: Load App Bridge from Shopify CDN -->
  <script src="https://cdn.shopify.com/shopifycloud/app-bridge.js"></script>
</head>
<body>
  <div id="app"></div>

  <script>
    // Get URL parameters from Shopify
    const params = new URLSearchParams(window.location.search);
    const apiKey = 'c8e9eb698f57cdc0a5d62d83c9137436'; // Your Shopify API key
    const host = params.get('host');

    // Initialize App Bridge
    const app = window.shopify.createApp({
      apiKey: apiKey,
      host: host,
    });

    console.log('✅ App Bridge loaded from CDN');

    // Function to call Firebase with session token
    async function callFirebaseAPI() {
      try {
        // Get session token
        const token = await app.idToken();
        console.log('✅ Got session token');

        // Call Firebase function
        const response = await fetch(
          'https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/getMerchantData',
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`, // Session token!
            },
            body: JSON.stringify({ action: 'test' }),
          }
        );

        const data = await response.json();
        console.log('✅ Firebase response:', data);
        return data;
      } catch (error) {
        console.error('❌ Error:', error);
      }
    }

    // Expose globally for testing
    window.callFirebaseAPI = callFirebaseAPI;

    // Auto-call on load to trigger Shopify's checks
    window.addEventListener('load', () => {
      setTimeout(callFirebaseAPI, 2000); // Call after 2 seconds
    });
  </script>
</body>
</html>
```

#### Option B: React Component

Use the example in `SHOPIFY_SESSION_TOKEN_EXAMPLE.tsx`:

```tsx
import { useAppBridge } from '@shopify/app-bridge-react';

function Dashboard() {
  const app = useAppBridge();

  async function fetchData() {
    const token = await app.idToken();

    const response = await fetch(
      'https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/getMerchantData',
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    return response.json();
  }

  return (
    <button onClick={fetchData}>
      Fetch Merchant Data
    </button>
  );
}
```

---

### Step 3: Configure Your Embedded App URL

In your `shopify.app.toml`:

```toml
application_url = "https://merchants.scanandpay.com.au/"
embedded = true

[build]
automatically_update_urls_on_dev = true
```

Make sure `https://merchants.scanandpay.com.au/` serves your HTML with App Bridge!

---

### Step 4: Test the Implementation

#### A. Start Dev Server (for testing)

```bash
cd C:\dev\shopify-app\scan-pay
npm run dev
```

This will give you a preview URL like:
`https://xxx-yyy-zzz.trycloudflare.com`

#### B. Install App on Dev Store

1. Open the preview URL in your browser
2. It will redirect to install on `scanpay-2.myshopify.com`
3. Click "Install"

#### C. Trigger the Checks

Once the app is installed and open in Shopify admin:

1. **App Bridge Check**:
   - The page loads → Shopify sees `<script src="https://cdn.shopify.com/shopifycloud/app-bridge.js">`
   - ✅ Check passes

2. **Session Token Check**:
   - Click buttons in your app that call Firebase functions
   - Each API call sends `Authorization: Bearer <session-token>`
   - Firebase verifies the token using Shopify's JWKS
   - ✅ Check passes

**CRITICAL ACTIONS** to trigger the checks:
- ✅ Open the app in Shopify admin (loads App Bridge)
- ✅ Click "Generate a product" or any button that calls backend
- ✅ Make at least 3-5 API calls with session tokens
- ✅ Navigate between pages in the app

---

### Step 5: Verify in Browser Console

Open browser DevTools (F12) and check:

```javascript
// 1. Verify App Bridge is loaded
console.log(window.shopify); // Should show App Bridge object

// 2. Get session token manually
window.shopifyApp.idToken().then(token => {
  console.log('Session token:', token);
  console.log('Token length:', token.length);
});

// 3. Call Firebase function
window.callFirebaseAPI();
```

**Expected console output**:
```
✅ App Bridge loaded from CDN
✅ Got session token
Session token length: 500+ characters
✅ Firebase response: { success: true, ... }
```

---

### Step 6: Wait for Shopify Auto-Check

- Checks run **every 2 hours**
- After using your app with session tokens, wait 1-4 hours
- Check Partner Dashboard: Both checks should turn ✅ green

---

## 🔍 Debugging

### Check 1 Fails: "App Bridge not from CDN"

**Verify**:
```bash
curl https://merchants.scanandpay.com.au/ | grep "cdn.shopify.com/shopifycloud/app-bridge"
```

Should return: `<script src="https://cdn.shopify.com/shopifycloud/app-bridge.js">`

### Check 2 Fails: "Not using session tokens"

**Verify**:
1. Open browser DevTools → Network tab
2. Click a button that calls Firebase
3. Find the Firebase function request
4. Check Headers → Should see:
   ```
   Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtp...
   ```

**Test Firebase function directly**:
```bash
# Get a session token from browser console first
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6..."

# Test the function
curl -X POST https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/getMerchantData \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"test":true}'
```

Expected response:
```json
{
  "success": true,
  "shop": "scanpay-2.myshopify.com",
  "authenticatedUser": "..."
}
```

---

## ✅ Success Criteria

Both checks will pass when Shopify observes:

1. **App Bridge CDN**: HTTP response contains `https://cdn.shopify.com/shopifycloud/app-bridge.js`
2. **Session Tokens**: Backend API requests include valid JWT tokens in `Authorization` header

---

## 📝 Summary Checklist

- [ ] Firebase functions deployed (`getMerchantData`, `generatePayIDQRWithAuth`)
- [ ] HTML includes `<script src="https://cdn.shopify.com/shopifycloud/app-bridge.js">`
- [ ] App initializes App Bridge: `window.shopify.createApp({ apiKey, host })`
- [ ] Frontend calls `app.idToken()` to get session tokens
- [ ] Backend receives and verifies session tokens using Shopify JWKS
- [ ] App installed on dev store (`scanpay-2.myshopify.com`)
- [ ] Triggered 5+ API calls with session tokens
- [ ] Waited 2-4 hours for Shopify's auto-check

---

## 🎯 Next Steps

1. Run `firebase login --reauth`
2. Deploy Firebase functions
3. Update your frontend HTML to load App Bridge from CDN
4. Install app on dev store
5. Use the app actively (click buttons, make API calls)
6. Wait for auto-checks to run
7. Check Partner Dashboard for green checkmarks ✅

**Need help with any step? Let me know!**
