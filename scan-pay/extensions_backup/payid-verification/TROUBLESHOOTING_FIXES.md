# Troubleshooting Fixes

## ✅ Fixed: All Build Errors Resolved

### Issues Fixed

#### 1. Dependency Version Error
```
ERROR: Could not resolve "@shopify/ui-extensions-react/checkout"
npm error notarget No matching version found for @shopify/ui-extensions-react@2025.10.x
```

**Root Cause**: API version `2025-10` doesn't exist yet.
**Solution**: Updated to `2025-07` (latest available).

#### 2. Preact Runtime Error
```
ERROR: Could not resolve "preact/jsx-runtime"
```

**Root Cause**: Shopify uses Preact for performance, but it wasn't installed.
**Solution**: Added `preact@^10.19.0` to dependencies.

#### 3. React Reconciler Error
```
ERROR: Could not resolve "react-reconciler"
```

**Root Cause**: Missing peer dependency for React UI.
**Solution**: Added `react-reconciler@^0.29.0`.

### Final Solution Applied

**1. Updated `package.json`**:
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@shopify/ui-extensions": "^2025.7.0",
    "@shopify/ui-extensions-react": "^2025.7.0",
    "react-reconciler": "^0.29.0",
    "preact": "^10.19.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "typescript": "^5.0.0"
  }
}
```

**2. Updated `shopify.extension.toml`**:
```toml
api_version = "2025-07"
```

**3. Converted to TypeScript**:
- Renamed: `Checkout.jsx` → `Checkout.tsx`
- Added TypeScript types for merchant settings

**4. Reinstalled dependencies**:
```bash
cd C:\Shopify\scan-pay\extensions\payid-verification
npm install
```

### Verification
- ✅ Dependencies installed successfully
- ✅ No vulnerabilities found
- ✅ Extension builds successfully
- ✅ **BUILD SUCCESSFUL** ✓

---

## How to Run Development Server

```bash
# From root directory
cd C:\Shopify\scan-pay
shopify app dev
```

The dev server will:
1. Start the React Router app
2. Build the PayID extension
3. Create a proxy server on port 64331
4. Launch GraphiQL on port 3457
5. Open dev preview on scan-and-pay-2.myshopify.com

---

## Expected Output

```
14:24:57 │ React Router │ Running pre-dev command: "npx prisma generate"
14:24:57 │ app-preview  │ Preparing dev preview on scan-and-pay-2.myshopify.com
14:24:57 │ proxy        │ Proxy server started on port 64331
14:24:57 │ graphiql     │ GraphiQL server started on port 3457
14:24:58 │ payid-verification │ ✔ Build succeeded
```

---

## Other Known Warnings (Safe to Ignore)

### `npm warn Unknown project config "shamefully-hoist"`
- **Cause**: Legacy npm config in workspace
- **Impact**: None - this is deprecated but harmless
- **Fix** (optional): Remove `shamefully-hoist` from any `.npmrc` files

---

## Available Shopify UI Extensions Versions

To check latest versions:
```bash
npm view @shopify/ui-extensions-react versions --json
```

**Current latest** (as of Dec 2024):
- `2025.7.2` - Latest stable
- `2025.7.1`
- `2025.7.0`
- `2025.4.0`
- `2025.1.3`

**Recommended**: Use `^2025.7.0` to automatically get patch updates.

---

## Testing the Extension

### 1. Start Dev Server
```bash
cd C:\Shopify\scan-pay
shopify app dev
```

### 2. Access Dev Store
- URL: https://scan-and-pay-2.myshopify.com
- Login with your Shopify partner credentials

### 3. Test Checkout
1. Add products to cart
2. Go to checkout
3. Look for "Pay with PayID" section
4. Click "Pay with PayID QR Code"
5. Verify QR code appears

### 4. Test Payment Flow
- Create test order with small amount ($0.50)
- Generate QR code
- Use banking app to scan and pay
- Click "I've Paid - Verify Now"
- Check payment verification works

---

## Common Build Errors

### Error: "Could not resolve module"
**Solution**: Check package.json has correct versions installed
```bash
npm install
```

### Error: "API version not supported"
**Solution**: Update `api_version` in shopify.extension.toml to match available versions

### Error: "Build failed"
**Solution**: Check console for specific error, likely syntax error in Checkout.jsx

---

## Debugging Tips

### View Extension Build Logs
The dev server shows real-time build output for the extension.

### Check Extension Settings
```bash
cd C:\Shopify\scan-pay
shopify app config
```

### Clear Cache
```bash
rm -rf node_modules
rm package-lock.json
npm install
```

### Check Shopify CLI Version
```bash
shopify version
# Should be 3.x or higher
```

---

## Next Steps After Fix

1. ✅ **Run dev server**: `shopify app dev`
2. ✅ **Test extension loads** in checkout
3. ✅ **Configure merchant settings** in Partner Dashboard
4. ✅ **Test QR code generation**
5. ✅ **Test payment verification** with real bank payment
6. ✅ **Deploy to production**: `shopify app deploy`

---

## Support

If you encounter other issues:

1. **Check Shopify Status**: https://status.shopify.com
2. **Review Logs**: Extension build errors shown in terminal
3. **Firebase Logs**: `firebase functions:log --follow`
4. **Browser Console**: F12 → Console tab for frontend errors

---

*Fixed: 2024-12-05*
