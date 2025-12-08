# PayID Verification - Quick Start

## 🚀 Get Started in 5 Minutes

### Step 1: Configure (2 minutes)

Edit `src/Checkout.jsx`:

```javascript
// Line 22 - Your Firebase URL
const FIREBASE_FUNCTION_URL = 'https://us-central1-YOUR-PROJECT.cloudfunctions.net';

// Line 24 - Merchant PayID
const MERCHANT_PAYID = 'payments@yourstore.com.au';
```

### Step 2: Install Dependencies (1 minute)

```bash
cd C:\Shopify\scan-pay
npm install
```

### Step 3: Deploy (2 minutes)

```bash
shopify app deploy
```

Select:
- Organization: **Scan & Pay**
- App: **Scan & Pay**
- Confirm: **Yes**

### Step 4: Activate

1. Go to Shopify Admin → Settings → Checkout
2. Find "payid-verification"
3. Click **Activate**

Done! ✅

## 🧪 Test It

```bash
# Start dev server
shopify app dev

# Opens test store in browser
# Add product → Checkout → See PayID option
```

## 📋 Before Production

- [ ] Update Firebase URL
- [ ] Set correct merchant PayID
- [ ] Test with real payment ($1)
- [ ] Verify order creates in Shopify
- [ ] Check mobile works

## 🆘 Need Help?

**QR not showing?** → Check `network_access = true` in `shopify.extension.toml`

**Verification fails?** → Check Firebase function deployed:
```bash
cd C:\scanandpayWeb
firebase functions:list
```

**More help?** → See `DEPLOYMENT_INSTRUCTIONS.md`

## 📚 Documentation

- **Quick Setup**: This file
- **Full Setup**: `SETUP_GUIDE.md`
- **Deployment**: `DEPLOYMENT_INSTRUCTIONS.md`
- **Implementation**: `IMPLEMENTATION_SUMMARY.md`

## 🔗 Key Files

```
C:\Shopify\scan-pay\extensions\payid-verification\
├── src/
│   └── Checkout.jsx          ← Main component (EDIT THIS)
├── shopify.extension.toml    ← Extension config
├── package.json              ← Dependencies
└── [Documentation files]

C:\scanandpayWeb\             ← Existing backend (DON'T CHANGE)
└── Firebase functions
```

## ⚡ Quick Commands

```bash
# Test locally
shopify app dev

# Deploy
shopify app deploy

# View logs
firebase functions:log

# Test API
curl -X POST https://YOUR-PROJECT.cloudfunctions.net/verifyPayment \
  -H "Content-Type: application/json" \
  -d '{"reference":"REF-2024-TEST","amount":100,"payId":"test@test.com"}'
```

## 🎯 What You Built

- ✅ PayID payment option in checkout
- ✅ QR code generation
- ✅ Real-time payment verification
- ✅ Order blocking until paid
- ✅ Firebase integration
- ✅ Global Payments webhook

## 🎉 Next Steps

1. Deploy to test store
2. Make test purchase
3. Verify payment flow works
4. Deploy to production
5. Monitor Firebase logs

**Ready to deploy!** 🚀
