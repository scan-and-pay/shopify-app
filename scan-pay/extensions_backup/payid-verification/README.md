# PayID Verification - Shopify Checkout Extension

Real-time PayID payment verification for Shopify checkout, powered by Scan & Pay backend platform.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Start development server (from root)
cd ../..
shopify app dev

# Deploy to production
shopify app deploy
```

## 📚 Documentation

- **[Integration Guide](INTEGRATION_GUIDE.md)** - Technical documentation and API specs
- **[Merchant Setup](MERCHANT_SETUP.md)** - Merchant configuration guide
- **[Integration Summary](INTEGRATION_SUMMARY.md)** - Overview and deployment
- **[Quick Reference](QUICK_REFERENCE.md)** - Quick commands and troubleshooting
- **[Troubleshooting Fixes](TROUBLESHOOTING_FIXES.md)** - Common issues and solutions

## ✅ What This Extension Does

- Displays PayID payment option in Shopify checkout
- Generates NPP-compliant QR codes via Firebase backend
- Verifies payments in real-time using Global Payments webhooks
- Blocks checkout completion until payment confirmed
- Stores transaction details in order attributes

## 🔧 Configuration

Configure in Shopify Partner Dashboard after installation:

- **Merchant PayID**: Your PayID (email or mobile number)
- **Merchant Name**: Business name shown to customers
- **Firebase Project ID**: Backend project (default: scan-and-pay-guihzm)
- **Enable Manual Entry**: Allow manual payment details entry

## 🏗️ Architecture

```
Shopify Checkout → Extension UI → Firebase Functions → Global Payments API
                                      ↓
                                  Firestore DB
```

**Backend APIs**:
- `generatePayIDQR` - NPP-compliant QR code generation
- `verifyPayment` - Real-time payment verification
- `checkPayIDStatus` - Payment status polling

**Database**: Firestore collections (`/payments`, `/transactions`, `/users`)

## 🔐 Security

- ✅ HTTPS-only communication
- ✅ HMAC SHA-256 webhook signatures
- ✅ Google Cloud Secret Manager
- ✅ Exact amount matching (to the cent)
- ✅ PCI compliant (no card data)

## 📦 Dependencies

```json
{
  "react": "^18.2.0",
  "@shopify/ui-extensions": "^2025.7.0",
  "@shopify/ui-extensions-react": "^2025.7.0"
}
```

## 🧪 Testing

1. Start dev server: `shopify app dev`
2. Open dev store: scan-and-pay-2.myshopify.com
3. Add test product to cart
4. Proceed to checkout
5. Test PayID payment with $0.50
6. Verify payment confirmation works

## 🛠️ Extension Structure

```
payid-verification/
├── src/
│   └── Checkout.jsx          # Main extension component
├── locales/
│   ├── en.default.json        # English translations
│   └── fr.json                # French translations
├── shopify.extension.toml     # Extension configuration
├── package.json               # Dependencies
└── [Documentation files]      # Guides and references
```

## 🎯 Extension Target

**Target**: `purchase.checkout.block.render`

This allows merchants to configure where in the checkout the PayID payment option appears. The extension renders in the payment section of the checkout flow.

## 🔑 Required Permissions

- ✅ `network_access` - Make API calls to Firebase
- ✅ `api_access` - Query Shopify Storefront API
- ✅ Checkout attributes - Store payment details

## 💳 Payment Flow

1. **Customer clicks** "Pay with PayID"
2. **Extension generates** NPP QR code via backend
3. **Customer scans** QR with banking app
4. **Customer completes** payment in bank
5. **Extension polls** for payment verification (every 3s)
6. **Backend verifies** via Global Payments webhook
7. **Checkout proceeds** when payment confirmed

**Average time**: ~40 seconds

## 🌐 Supported Countries

- 🇦🇺 Australia only (PayID/NPP network)

## 🏦 Supported Banks

All major Australian banks with PayID support:
- Commonwealth Bank, Westpac, ANZ, NAB
- Bendigo Bank, Suncorp, Bank of Queensland
- ING, Macquarie Bank, and 100+ more

## 📞 Support

- **Email**: developer@scanandpay.com.au
- **Merchant Support**: merchant-support@scanandpay.com.au
- **Emergency**: 1800 SCAN PAY
- **Docs**: See documentation files above

## 🐛 Troubleshooting

### Extension won't build
```bash
# Check dependency versions match
npm view @shopify/ui-extensions-react versions
# Should use 2025.7.x
```

### QR code not displaying
- Verify `network_access = true` in shopify.extension.toml
- Check Firebase function URL is correct
- Test API endpoint with curl

### Payment verification fails
- Check Firestore `/transactions` collection
- Verify webhook is being received
- Confirm amount matches (in cents)

See **[TROUBLESHOOTING_FIXES.md](TROUBLESHOOTING_FIXES.md)** for detailed solutions.

## 📄 License

Proprietary - Scan & Pay Platform
© 2024 All Rights Reserved

---

## Useful Shopify Links

- [Checkout UI extension documentation](https://shopify.dev/api/checkout-extensions)
- [Configuration](https://shopify.dev/docs/api/checkout-ui-extensions/configuration)
- [Extension Targets](https://shopify.dev/docs/api/checkout-ui-extensions/targets)
- [API Reference](https://shopify.dev/docs/api/checkout-ui-extensions/apis)
- [UI Components](https://shopify.dev/docs/api/checkout-ui-extensions/components)

---

**Version**: 1.0.0
**Shopify API**: 2025-07
**Last Updated**: 2024-12-05
