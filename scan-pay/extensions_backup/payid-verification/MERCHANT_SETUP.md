# PayID Checkout - Merchant Setup Guide

## Quick Start (5 Minutes)

### Step 1: Install the Extension

1. Go to your Shopify Partner Dashboard
2. Navigate to **Apps** → **Your App** → **Extensions**
3. Find **PayID Verification** extension
4. Click **Install** on your store

### Step 2: Configure Settings

After installation, you'll be prompted to configure:

#### ✅ Required Settings

**Merchant PayID**
- Enter your PayID (email or mobile number)
- Example: `payments@mystore.com.au` or `0412345678`
- ⚠️ This must be a valid PayID registered with your bank

**Merchant Name**
- Your business name as it should appear to customers
- Example: `My Store Pty Ltd`
- This shows in the customer's banking app when they pay

#### ⚙️ Optional Settings

**Firebase Project ID**
- Default: `scan-and-pay-guihzm` (recommended)
- Only change if you're using a custom Firebase backend

**Enable Manual Entry**
- Default: Enabled
- Allows customers to manually enter payment details if QR scan fails

### Step 3: Test the Checkout

1. Create a test order in your Shopify store
2. Proceed to checkout
3. Look for **"Pay with PayID"** section
4. Click **"Pay with PayID QR Code"**
5. Test with a small amount (e.g., $0.50)

---

## What Your Customers Will See

### 1. Payment Button
```
┌────────────────────────────────────┐
│  Pay with PayID                    │
│  Scan QR code and pay instantly    │
│  with your bank app                │
│                                    │
│  Total Amount: $125.50 AUD         │
│                                    │
│  ┌──────────────────────────────┐ │
│  │ Pay with PayID QR Code       │ │
│  └──────────────────────────────┘ │
│                                    │
│  Secure payment powered by         │
│  Global Payments Oceania           │
└────────────────────────────────────┘
```

### 2. QR Code Display
```
┌────────────────────────────────────┐
│  PayID Payment                     │
│                                    │
│  Amount: $125.50 AUD               │
│  ─────────────────────────────     │
│  PayID: payments@mystore.com.au    │
│  ─────────────────────────────     │
│  Reference: REF-2024-ABC123XYZ     │
│                                    │
│  Scan QR Code:                     │
│  ┌──────────────────────────────┐ │
│  │                              │ │
│  │    █████████████████████     │ │
│  │    ███ ▄▄▄▄▄ █▀█ ▄▄▄▄▄ ███   │ │
│  │    ███ █   █ ██▀ █   █ ███   │ │
│  │    ███ █▄▄▄█ █▀▀ █▄▄▄█ ███   │ │
│  │    █████████████████████     │ │
│  │                              │ │
│  └──────────────────────────────┘ │
│                                    │
│  How to Pay:                       │
│  1. Open your banking app          │
│  2. Select PayID or Pay Anyone     │
│  3. Scan the QR code               │
│  4. Confirm payment in your bank   │
│  5. Click "I've Paid" button       │
│                                    │
│  ┌──────────────────────────────┐ │
│  │ I've Paid - Verify Now       │ │
│  └──────────────────────────────┘ │
└────────────────────────────────────┘
```

### 3. Payment Confirmed
```
┌────────────────────────────────────┐
│  ✓ Payment Confirmed!              │
│  Your order is being processed.    │
│                                    │
│  You can now complete your order.  │
└────────────────────────────────────┘
```

---

## Supported Banks

PayID is supported by all major Australian banks:

- ✅ Commonwealth Bank
- ✅ Westpac
- ✅ ANZ
- ✅ NAB
- ✅ Bendigo Bank
- ✅ Suncorp
- ✅ Bank of Queensland
- ✅ ING
- ✅ Macquarie Bank
- ✅ And 100+ other financial institutions

**Customer Requirements**:
- Australian bank account
- Banking app with PayID capability
- PayID registered (email or mobile)

---

## Payment Flow Timeline

```
0:00 - Customer clicks "Pay with PayID"
0:01 - QR code generated and displayed
0:15 - Customer scans QR code with banking app
0:30 - Customer confirms payment in bank
0:35 - Bank processes payment via NPP (instant)
0:36 - Global Payments receives payment notification
0:37 - Webhook sent to backend
0:38 - Extension verifies payment ✓
0:39 - Checkout proceeds to completion
```

**Total Time**: ~40 seconds (typical)

---

## Pricing

### Transaction Fees

**Global Payments Oceania**:
- Processing fee: 0.5% + $0.10 per transaction
- Example: $100 order = $0.60 fee

**No Additional Fees**:
- ✅ No monthly fees
- ✅ No setup fees
- ✅ No hidden charges
- ✅ PayID is free for customers

---

## FAQ

### Q: What is PayID?
**A**: PayID is a fast, secure payment system created by NPP Australia. It allows customers to pay using just an email or mobile number, with instant settlement.

### Q: How long does payment verification take?
**A**: Typically 5-10 seconds. The extension polls for payment confirmation every 3 seconds, up to 2 minutes maximum.

### Q: What happens if a customer pays the wrong amount?
**A**: The payment will not be verified. The extension matches the exact amount. The customer will need to contact their bank for a refund.

### Q: Can customers pay with credit card via PayID?
**A**: No. PayID only supports direct bank account transfers. It's a bank account to bank account payment method.

### Q: What if the QR code expires?
**A**: QR codes expire after 5 minutes for security. The customer can simply click the payment button again to generate a new QR code.

### Q: Do I need a special PayID account?
**A**: No. Any Australian bank account with PayID enabled can receive payments. Register your PayID through your bank's app or online banking.

### Q: What if a payment fails to verify?
**A**: The extension will show an error message. Check your Firebase console logs and Firestore `/transactions` collection. If the customer completed payment, you can manually verify via your banking records.

### Q: Can I use multiple PayIDs?
**A**: Currently, only one PayID per store is supported. Contact support if you need multi-PayID support for different product lines.

### Q: Is this PCI compliant?
**A**: Yes. Since payments go directly from customer bank to merchant bank via NPP, no card data touches your Shopify store. PayID is inherently PCI compliant.

### Q: What about refunds?
**A**: Refunds must be processed manually via your bank's PayID system. Future versions will support automated refunds via the Global Payments API.

---

## Troubleshooting

### Issue: "Failed to generate QR code"

**Cause**: Invalid PayID format or Firebase connection error

**Solution**:
1. Verify your PayID is correct in extension settings
2. Test PayID format: `payments@example.com.au` or `0412345678`
3. Check Firebase console for error logs

### Issue: Payment verified but checkout won't proceed

**Cause**: Checkout attributes not updating

**Solution**:
1. Check browser console for JavaScript errors
2. Verify extension has required permissions
3. Test with a different browser

### Issue: Customer paid but verification timeout

**Cause**: Webhook delay or network issue

**Solution**:
1. Wait 5 minutes for webhook retries
2. Check Firestore `/transactions` collection
3. Manually verify payment in your bank account
4. Contact support with reference number

---

## Getting Help

### Support Channels

📧 **Email**: merchant-support@scanandpay.com.au
📱 **Phone**: 1800 SCAN PAY (Australia)
💬 **Chat**: Available in Partner Dashboard
📚 **Docs**: https://docs.scanandpay.com.au

### Response Times

- Critical (payment issues): < 1 hour
- High (checkout errors): < 4 hours
- Normal (general questions): < 24 hours

### Include in Support Requests

1. Store URL
2. Order number (if applicable)
3. Payment reference number
4. Screenshot of error message
5. Browser console logs (F12 → Console)

---

## Advanced Configuration

### Custom Firebase Backend

If using your own Firebase project:

1. Deploy the backend code to your Firebase project
2. Update extension settings:
   - Firebase Project ID: `your-project-id`
3. Configure Google Cloud Secret Manager with required secrets
4. Update Firestore security rules
5. Set up Global Payments webhook URL

### Multi-Currency Support

Currently supports **AUD only**. For multi-currency:
- Contact Global Payments for international accounts
- Update backend to support currency conversion
- Modify QR code generation to include currency code

### Webhook Configuration

**Webhook URL**: `https://australia-southeast1-scan-and-pay-guihzm.cloudfunctions.net/globalPaymentsWebhook`

**Required Headers**:
```
Content-Type: application/json
X-GP-Signature: <HMAC SHA-256 signature>
```

**Webhook Events**:
- `payment.succeeded`
- `payment.failed`
- `payment.pending`

---

## Best Practices

### 1. Test Before Launch
- Always test with small amounts ($0.01 - $1.00)
- Test from different devices and browsers
- Verify webhooks are received in Firestore

### 2. Monitor Transactions
- Check Firestore daily for failed transactions
- Set up Firebase alerts for function errors
- Review payment reconciliation weekly

### 3. Customer Communication
- Add PayID instructions to checkout page
- Email customers payment confirmation
- Provide clear support contact information

### 4. Optimize Checkout
- Place extension above other payment methods
- Use clear, simple language
- Include trust badges (bank logos, security)

### 5. Security
- Never share Firebase API keys publicly
- Rotate webhook secrets quarterly
- Monitor for unusual payment patterns

---

## Next Steps

✅ Extension installed and configured
✅ Test order completed
✅ Webhook receiving payments

**Now you're ready to go live!**

1. Remove test mode restrictions (if any)
2. Announce PayID payments to customers
3. Monitor first few transactions closely
4. Collect customer feedback

**Welcome to instant bank payments with PayID!** 🎉

---

*Last updated: 2024-12-05*
*Version: 1.0.0*
