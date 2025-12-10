# Organization Migration Notes

## Problem
The Scan & Pay app was accidentally deployed to the **wrong Shopify Partner organization**.

## Organizations

### ❌ Wrong Organization (TO BE CLEANED UP)
- **App Group ID**: 194602742
- **Dashboard**: https://dev.shopify.com/dashboard/194602742
- **Apps to Delete**:
  - Scan & Pay (scan-pay-5)
  - Scan & Pay (scan-pay-3)
- **Dev Store to Delete**:
  - Scan & Pay (https://scan-and-pay-2.myshopify.com)

### ✅ Correct Organization (PRODUCTION)
- **App Group ID**: 194668629
- **Dashboard**: https://dev.shopify.com/dashboard/194668629/apps
- **Client ID**: `e2af15a811bed53da75d916157c06ce4`

## Changes Made

### 1. Updated Configuration File
**File**: `shopify.app.toml`

**Changed**:
```diff
- client_id = "26905e9e615056eb5cd1a8de6f3f45be"  # Wrong org (194602742)
+ client_id = "e2af15a811bed53da75d916157c06ce4"  # Correct org (194668629)
```

### 2. Updated Documentation
- Updated `SHOPIFY_COMPLIANCE_WEBHOOKS.md` to reflect correct organization
- Added warning about previous incorrect deployment

## Next Steps

### Step 1: Manual Cleanup (Required)
You must manually delete the duplicate apps and dev store from organization 194602742:

1. **Go to Partner Dashboard**:
   https://partners.shopify.com/194602742

2. **Delete Apps**:
   - Navigate to "Apps"
   - Delete "Scan & Pay (scan-pay-5)"
   - Delete "Scan & Pay (scan-pay-3)"
   - For each: Click app → Settings → Scroll to bottom → "Delete app"

3. **Delete Dev Store**:
   - Navigate to "Stores"
   - Find "Scan & Pay" (scan-and-pay-2.myshopify.com)
   - Click "..." menu → "Transfer or delete store" → "Delete store"

### Step 2: Deploy to Correct Organization
After manual cleanup is complete, deploy to the correct organization:

```bash
cd scan-pay

# Reset app configuration (will prompt for org selection)
shopify app deploy --reset

# When prompted, select organization 194668629
# This will create a new app version in the correct organization

# Verify deployment
shopify app versions list
```

### Step 3: Verify Compliance Webhooks
After deploying to correct organization:

1. Go to: https://partners.shopify.com/194668629
2. Select: Apps → Scan & Pay
3. Navigate to: App Listing → Automated checks
4. Run compliance checks

**Expected Results**:
- ✅ Provides mandatory compliance webhooks
- ✅ Verifies webhooks with HMAC signatures

## Files Updated

1. ✅ `shopify.app.toml` - Updated client_id to correct organization
2. ✅ `SHOPIFY_COMPLIANCE_WEBHOOKS.md` - Updated deployment status
3. ✅ `ORG_MIGRATION_NOTES.md` - Created this migration guide

## Important Notes

- **Do NOT delete anything** in organization 194668629
- The webhook implementation code is correct and doesn't need changes
- Only the configuration pointer (`client_id`) was wrong
- All compliance webhook handlers are ready for the correct organization

## Verification Checklist

- [ ] Manually deleted apps from organization 194602742
- [ ] Manually deleted dev store from organization 194602742
- [ ] Deployed to correct organization (194668629) with `--reset` flag
- [ ] Verified new app version in correct organization
- [ ] Ran automated compliance checks in Partner Dashboard
- [ ] Confirmed HMAC verification passes
- [ ] Confirmed compliance webhooks pass

## Date
Migration prepared: December 10, 2025
