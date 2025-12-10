# Deployment Guide: Google Secret Manager Migration

This guide walks you through deploying your migrated Firebase Functions that now use Google Secret Manager instead of `functions.config()`.

## Pre-Deployment Checklist

### 1. Verify All Secrets Exist

Run the verification script to check that all secrets are properly configured:

```bash
cd C:\dev\shopify-app\flutter-app\functions
node verify-secrets.js
```

Expected output:
```
✅ All secrets are properly configured!
You're ready to deploy:
firebase deploy --only functions
```

If any secrets are missing, create them using the gcloud CLI.

### 2. Grant Service Account Permissions

Your Firebase Functions service account needs permission to access secrets. Run:

```bash
# Get your project ID
$PROJECT_ID = (firebase use)

# Grant Secret Manager Secret Accessor role to Firebase Functions service account
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$PROJECT_ID@appspot.gserviceaccount.com" `
  --role="roles/secretmanager.secretAccessor"
```

### 3. Verify Firebase CLI Version

Ensure you have the latest Firebase CLI:

```bash
npm install -g firebase-tools
firebase --version
```

## Deployment Steps

### Option 1: Deploy All Functions (Recommended for First Migration)

```bash
cd C:\dev\shopify-app\flutter-app\functions
firebase deploy --only functions
```

This will deploy all functions in one operation. Deployment typically takes 2-5 minutes.

### Option 2: Deploy Functions Incrementally

If you prefer a gradual rollout, deploy functions one-by-one:

```bash
# Deploy email OTP functions first
firebase deploy --only functions:sendOtp,functions:verifyOtp

# Deploy Global Payments functions
firebase deploy --only functions:createGlobalPaymentsCustomer,functions:createPayToAgreement,functions:createPayIdInstrument,functions:processGlobalPayment,functions:getGlobalPaymentsCustomer,functions:getGlobalPaymentInstrument,functions:cancelGlobalPaymentAgreement,functions:checkGlobalPaymentsHealth

# Deploy PayID QR functions
firebase deploy --only functions:generatePayIDQR,functions:checkPayIDStatus

# Deploy Shopify webhooks
firebase deploy --only functions:appUninstalled,functions:customersDataRequest,functions:customersRedact,functions:shopRedact

# Deploy user account management
firebase deploy --only functions:deleteUserAccount
```

## Post-Deployment Verification

### 1. Check Deployment Status

View your deployed functions:

```bash
firebase functions:list
```

All functions should show status: `ACTIVE`

### 2. Test Critical Endpoints

#### Test Email OTP Flow

From your Flutter app or using curl:

```bash
# Send OTP
curl -X POST https://australia-southeast1-YOUR-PROJECT.cloudfunctions.net/sendOtp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'

# Verify OTP
curl -X POST https://australia-southeast1-YOUR-PROJECT.cloudfunctions.net/verifyOtp \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","otp":"123456"}'
```

#### Test Global Payments Health Check

```bash
curl -X POST https://australia-southeast1-YOUR-PROJECT.cloudfunctions.net/checkGlobalPaymentsHealth \
  -H "Content-Type: application/json"
```

Expected response:
```json
{
  "healthy": true,
  "configured": true,
  "apiUrl": "https://sandbox.api.gpaunz.com",
  "message": "Global Payments API is configured and ready"
}
```

### 3. Monitor Logs

Watch function logs in real-time:

```bash
firebase functions:log --only sendOtp
firebase functions:log --only checkGlobalPaymentsHealth
```

Or view all logs:

```bash
firebase functions:log
```

Look for:
- ✅ No secret access errors
- ✅ Successful API calls
- ✅ Proper HMAC verification (for webhooks)

### 4. Test from Flutter App

Launch your Flutter app and test:

1. **Email OTP Login**
   - Send OTP code
   - Verify OTP code
   - Complete authentication flow

2. **Payment Flows**
   - Generate PayID QR code
   - Check payment status
   - Process payment (if applicable)

3. **Account Management**
   - User profile operations
   - Delete account flow

## Monitoring & Alerts

### View Secret Access in GCP Console

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to **Secret Manager**
3. Click on any secret (e.g., `MAILGUN_API_KEY`)
4. View **Metrics** tab to see access patterns
5. View **Audit Logs** for security events

### Set Up Alerts (Optional)

Create alerts for secret access failures:

```bash
# Alert on secret access denials
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="Secret Manager Access Denied" \
  --condition-display-name="Secret access denied" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=60s \
  --filter='resource.type="secretmanager.googleapis.com/Secret" AND protoPayload.status.code!=0'
```

## Troubleshooting

### Error: "Permission denied to access secret"

**Solution**: Grant the service account access to secrets:

```bash
$PROJECT_ID = (firebase use)
gcloud projects add-iam-policy-binding $PROJECT_ID `
  --member="serviceAccount:$PROJECT_ID@appspot.gserviceaccount.com" `
  --role="roles/secretmanager.secretAccessor"
```

### Error: "Secret not found: MAILGUN_API_KEY"

**Solution**: Verify secret exists:

```bash
gcloud secrets describe MAILGUN_API_KEY --project=YOUR_PROJECT_ID
```

If not found, create it:

```bash
echo "YOUR_MAILGUN_KEY" | gcloud secrets create MAILGUN_API_KEY --data-file=- --project=YOUR_PROJECT_ID
```

### Error: "Function timeout" or "Out of memory"

**Solution**: Secrets add minimal overhead, but if you see issues, increase resources:

```javascript
.runWith({
  timeoutSeconds: 120,  // Increase from 60
  memory: '512MB',      // Increase from 256MB
  secrets: [MAILGUN_API_KEY, MAILGUN_DOMAIN]
})
```

### Function works locally but fails in production

**Solution**: Check environment differences:

1. Verify secret names match exactly (case-sensitive)
2. Check service account permissions in production project
3. Review production Firebase Functions logs for specific errors

## Rollback Procedure

If you need to rollback to the old `functions.config()` approach:

### Step 1: Revert Code Changes

```bash
cd C:\dev\shopify-app\flutter-app
git checkout HEAD~1 functions/
```

### Step 2: Redeploy

```bash
cd functions
firebase deploy --only functions
```

### Step 3: Verify Rollback

```bash
firebase functions:list
firebase functions:log
```

The old config values are still available in Firebase (not deleted during migration).

## Clean Up Old Config (Optional)

Once you've verified the migration is successful and stable, you can remove the old `functions.config()` values:

```bash
# Remove old config (do this AFTER successful migration)
firebase functions:config:unset mailgun
firebase functions:config:unset globalpayments
firebase functions:config:unset shopify
firebase functions:config:unset basiq

# Verify removal
firebase functions:config:get
```

**⚠️ Warning**: Only do this after the migration is stable and you're confident you won't need to rollback.

## Performance Notes

- **Secret Access Latency**: First access per cold start: ~10-50ms
- **Caching**: Secrets are cached within function instances (no repeated lookups)
- **Cost**: Secret Manager has free tier (10,000 accesses/month), far exceeding typical usage

## Security Best Practices

1. ✅ **Rotate secrets regularly** (every 90 days)
2. ✅ **Use secret versions** for gradual rollout of new values
3. ✅ **Monitor secret access logs** for unusual patterns
4. ✅ **Restrict IAM permissions** to specific service accounts
5. ✅ **Enable audit logging** for all secret operations

## Next Steps

After successful deployment:

1. ✅ Monitor function logs for 24-48 hours
2. ✅ Test all critical user flows from Flutter app
3. ✅ Set up alerts for secret access failures
4. ✅ Document secret rotation procedures
5. ✅ Schedule regular security reviews

---

**🎉 Congratulations! Your Firebase Functions are now using Google Secret Manager!**

For questions or issues, check:
- Firebase Functions logs: `firebase functions:log`
- Secret Manager audit logs: GCP Console → Secret Manager → Audit Logs
- Firebase console: https://console.firebase.google.com
