# Local Testing Guide

## Important: Secret Manager Limitations in Local Emulator

⚠️ **Firebase Emulator does NOT support `defineSecret()` from Secret Manager.**

When running locally with `firebase emulators:start`, you have two options:

## Option 1: Use Environment Variables (Recommended)

The `defineSecret()` function automatically falls back to environment variables when running locally.

### Step 1: Create .env.local file

```bash
cp .env.local.example .env.local
```

### Step 2: Edit .env.local with your actual values

```env
MAILGUN_API_KEY=your_actual_key
MAILGUN_DOMAIN=your_actual_domain
GLOBALPAYMENTS_MASTER_KEY=your_actual_key
GLOBALPAYMENTS_BASE_URL=https://sandbox.api.gpaunz.com
SHOPIFY_API_SECRET=your_actual_secret
BASIQ_API_KEY=your_actual_key
```

### Step 3: Load environment variables and start emulator

**On Windows (PowerShell):**
```powershell
# Load .env.local
Get-Content .env.local | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)$') {
        $name = $matches[1].Trim()
        $value = $matches[2].Trim()
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

# Start emulator
firebase emulators:start
```

**On Windows (Command Prompt):**
```cmd
# Load .env.local manually or use cross-env
npm install --save-dev cross-env

# Then in package.json add:
"scripts": {
  "serve": "cross-env-shell \"firebase emulators:start\""
}

# Run with:
npm run serve
```

**On Mac/Linux:**
```bash
export $(cat .env.local | xargs) && firebase emulators:start
```

## Option 2: Use functions.config() for Local Testing (Temporary)

If you want to test locally without environment variables, you can temporarily use the old `functions.config()` approach:

### Step 1: Set local config

```bash
firebase functions:config:set \
  mailgun.key="your_key" \
  mailgun.domain="your_domain" \
  globalpayments.master_key="your_key" \
  globalpayments.base_url="https://sandbox.api.gpaunz.com" \
  shopify.api_secret="your_secret"
```

### Step 2: Download config for local use

```bash
firebase functions:config:get > .runtimeconfig.json
```

### Step 3: Start emulator

```bash
firebase emulators:start
```

The emulator will automatically read `.runtimeconfig.json`.

## Option 3: Deploy to Firebase and Test (Most Reliable)

The most reliable way to test with Secret Manager is to deploy to Firebase:

```bash
# Deploy only functions
firebase deploy --only functions

# Test using deployed functions
# Your Flutter app can connect to deployed functions
```

## Recommended Testing Workflow

1. **Local Development** (use Option 1 with .env.local)
   - Fast iteration
   - Test business logic
   - Test function structure

2. **Staging Deployment** (deploy to Firebase)
   - Test with real Secret Manager
   - Test with real external APIs
   - Verify IAM permissions

3. **Production Deployment**
   - Full testing complete
   - All secrets verified
   - Monitoring enabled

## Testing Individual Functions Locally

### Test Email OTP

```bash
# Start emulator
firebase emulators:start

# In another terminal, test the function
curl -X POST http://localhost:5001/YOUR-PROJECT-ID/australia-southeast1/sendOtp \
  -H "Content-Type: application/json" \
  -d '{"data": {"email": "test@example.com"}}'
```

### Test Global Payments Health Check

```bash
curl -X POST http://localhost:5001/YOUR-PROJECT-ID/australia-southeast1/checkGlobalPaymentsHealth \
  -H "Content-Type: application/json" \
  -d '{"data": {}}'
```

## Known Issues with Local Emulator

1. **defineSecret() not supported** - Use environment variables
2. **Firebase App Check** - Disabled in emulator by default
3. **Authentication** - Use emulator auth, not production
4. **Firestore** - Use emulator data, not production

## Production Testing Checklist

Before deploying to production:

- [ ] All secrets exist in Secret Manager
- [ ] Service account has permissions
- [ ] Functions deploy successfully
- [ ] Email OTP works end-to-end
- [ ] Payment flows work
- [ ] Webhooks receive and verify correctly
- [ ] Flutter app can call all functions
- [ ] Logs show no secret access errors

## Quick Start for Local Testing

```bash
# 1. Install dependencies
npm install

# 2. Create .env.local from example
cp .env.local.example .env.local

# 3. Edit .env.local with your values
# (Use your code editor)

# 4. Start emulator (see Option 1 above for loading .env)

# 5. Test functions
# Use curl or your Flutter app pointing to localhost:5001
```

---

**Note**: For the most accurate testing, deploy to Firebase and test with real Secret Manager integration.
