# Copy-Paste This Into Claude CLI

```
I'm working on Scan & Pay - a Shopify PayID payment system with 5-terminal architecture.

KEY CONTEXT:
- Terminal 4 is our innovation: a dedicated API that ONLY verifies payments (doesn't process them)
- Returns 3 states: paid | unpaid | pending
- Global Payments Oceania sends webhooks → we store in Firebase → Terminal 4 checks status
- Payment references use crypto.getRandomValues() (format: REF-2024-XXXXXX)
- Amounts ALWAYS in CENTS internally (×100 for dollars, ÷100 for display)
- Webhook signatures verified with HMAC SHA-256

TECH STACK:
- Backend: Firebase (Firestore, Auth, Cloud Functions)
- Payment: Global Payments Oceania API + PayID
- Frontend: HTML/JS with QRCode.js
- Auth: SMS OTP (Twilio) + Email OTP (SendGrid) + PIN codes

FILES AVAILABLE:
- global-payments-webhook.js (Cloud Function: webhook receiver + verify API)
- payid-qr-payment.html (standalone QR payment page)
- shopify-buyer-checkout.html (complete checkout flow)
- CLAUDE.md (full documentation)

CURRENT TASK: [describe what you need help with]

Full context in CLAUDE.md. All files in /mnt/user-data/outputs/
```

---

## Usage Examples

### Example 1: Add New Feature
```
[Copy the prompt above, then add:]

CURRENT TASK: Add a refund processing function to global-payments-webhook.js
that calls Global Payments API to initiate a refund and updates the transaction
status in Firestore.
```

### Example 2: Debug Issue
```
[Copy the prompt above, then add:]

CURRENT TASK: Debug webhook signature verification failing. The webhook
is being received but signature validation returns false even though
I've verified the private key is correct.
```

### Example 3: Create New Endpoint
```
[Copy the prompt above, then add:]

CURRENT TASK: Create a new Cloud Function endpoint that allows merchants
to manually mark an order as paid, with proper authentication and
verification that they own the order.
```

### Example 4: Update Frontend
```
[Copy the prompt above, then add:]

CURRENT TASK: Update shopify-buyer-checkout.html to add a countdown timer
showing how long until the payment reference expires, and automatically
generate a new reference after expiry.
```

---

## Pro Tips for Claude CLI

**Always include:**
- What you're trying to accomplish
- Any error messages you're seeing
- What you've already tried
- Which file(s) need to be modified

**Quick commands to run after Claude helps:**
```bash
# Test function locally
firebase emulators:start

# Deploy
firebase deploy --only functions:functionName

# Check logs
firebase functions:log --only functionName
```

**If Claude needs more context:**
- "See CLAUDE.md section on [topic]"
- "Reference the 5-terminal architecture in CLAUDE.md"
- "Check the Firebase schema in CLAUDE.md"

---

Save this file and use it as a template whenever you start a new Claude CLI session!
