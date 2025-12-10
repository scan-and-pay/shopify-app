# Architecture Overview: Secret Manager Integration

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Flutter Mobile App                          │
│                    (No changes - 100% compatible)                   │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                             │ HTTPS Calls
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Firebase Cloud Functions                         │
│                  (australia-southeast1 region)                      │
│                                                                     │
│  ┌───────────────┐  ┌──────────────────┐  ┌───────────────────┐  │
│  │   sendOtp     │  │ generatePayIDQR  │  │ processPayment    │  │
│  │   verifyOtp   │  │ checkPayIDStatus │  │ createCustomer    │  │
│  └───────┬───────┘  └────────┬─────────┘  └─────────┬─────────┘  │
│          │                   │                       │             │
│          │                   │                       │             │
│          ▼                   ▼                       ▼             │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │              Secret Access via defineSecret()                │ │
│  │                                                              │ │
│  │  MAILGUN_API_KEY          GLOBALPAYMENTS_MASTER_KEY        │ │
│  │  MAILGUN_DOMAIN           GLOBALPAYMENTS_BASE_URL          │ │
│  │  SHOPIFY_API_SECRET       BASIQ_API_KEY                    │ │
│  └──────────────────────────┬───────────────────────────────────┘ │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
                              │ Secret Access (IAM authenticated)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│               Google Cloud Secret Manager                           │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
│  │ MAILGUN_API_KEY  │  │ GLOBALPAYMENTS_  │  │ SHOPIFY_API_    │ │
│  │   (v1, v2, v3)   │  │   MASTER_KEY     │  │    SECRET       │ │
│  └──────────────────┘  └──────────────────┘  └─────────────────┘ │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
│  │ MAILGUN_DOMAIN   │  │ GLOBALPAYMENTS_  │  │ BASIQ_API_KEY   │ │
│  │                  │  │    BASE_URL      │  │   (disabled)    │ │
│  └──────────────────┘  └──────────────────┘  └─────────────────┘ │
│                                                                     │
│  Features:                                                          │
│  ✅ Automatic versioning                                           │
│  ✅ IAM-based access control                                       │
│  ✅ Audit logging                                                  │
│  ✅ Encryption at rest                                             │
│  ✅ Secret rotation support                                        │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              │ Secrets used to authenticate with
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      External APIs                                  │
│                                                                     │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
│  │   Mailgun API    │  │  Global Payments │  │  Shopify API    │ │
│  │  (Email OTP)     │  │   (PayTo, PayID) │  │   (Webhooks)    │ │
│  └──────────────────┘  └──────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Function-to-Secret Mapping

### Email Authentication Flow
```
┌──────────────┐      uses      ┌──────────────────┐
│   sendOtp    │ ─────────────> │ MAILGUN_API_KEY  │
│              │                 │ MAILGUN_DOMAIN   │
└──────────────┘                 └──────────────────┘
       │
       │ sends email
       ▼
┌──────────────────┐
│   Mailgun API    │
└──────────────────┘

┌──────────────┐      no secrets needed
│  verifyOtp   │ ──────> (uses Firestore only)
└──────────────┘
```

### Payment Processing Flow
```
┌─────────────────────┐      uses      ┌──────────────────────────┐
│ Global Payments     │ ─────────────> │ GLOBALPAYMENTS_MASTER_KEY│
│ Functions (8 total) │                 │ GLOBALPAYMENTS_BASE_URL  │
└─────────────────────┘                 └──────────────────────────┘
       │
       │ API calls
       ▼
┌──────────────────────┐
│ Global Payments API  │
│ (PayTo, PayID)       │
└──────────────────────┘
```

### Shopify Webhook Flow
```
┌──────────────────┐      uses      ┌──────────────────────┐
│ Shopify Webhooks │ ─────────────> │ SHOPIFY_API_SECRET   │
│ (4 endpoints)    │                 │ (HMAC verification)  │
└──────────────────┘                 └──────────────────────┘
       │
       │ receives webhooks
       ▼
┌──────────────────┐
│   Shopify API    │
└──────────────────┘
```

## Security Flow

```
1. Function Cold Start
   │
   ▼
2. defineSecret() declaration
   (Secret reference created, not accessed yet)
   │
   ▼
3. Function Invocation
   │
   ▼
4. secret.value() called
   │
   ▼
5. IAM Permission Check
   │
   ├─> ✅ Authorized → Return secret value (cached)
   │
   └─> ❌ Denied → Throw permission error
```

## Before vs. After Comparison

### Before: functions.config()
```
Firebase Console (Manual Entry)
         │
         ▼
   functions.config()
         │
         ▼
   Deployed to Functions
   (Not encrypted at rest)
```

**Limitations:**
- ❌ No versioning
- ❌ No audit logs
- ❌ No rotation support
- ❌ Manual configuration via CLI
- ❌ Limited security controls

### After: Secret Manager
```
Google Cloud Secret Manager
         │
         ▼
   defineSecret()
         │
         ▼
   Deployed to Functions
   (Encrypted at rest & in transit)
```

**Benefits:**
- ✅ Automatic versioning
- ✅ Full audit logging
- ✅ Secret rotation support
- ✅ IAM-based access control
- ✅ Encryption at rest
- ✅ Multiple environments support

## Data Flow: Email OTP Example

```
1. Flutter App
   └─> calls sendOtp({ email: "user@example.com" })

2. Firebase Function (sendOtp)
   ├─> Access MAILGUN_API_KEY.value()
   │   └─> Secret Manager returns key (10-50ms first access)
   │
   ├─> Access MAILGUN_DOMAIN.value()
   │   └─> Secret Manager returns domain (cached, ~1ms)
   │
   └─> Call Mailgun API
       └─> Send email with OTP

3. User receives email, enters OTP

4. Flutter App
   └─> calls verifyOtp({ email: "user@example.com", otp: "123456" })

5. Firebase Function (verifyOtp)
   ├─> No secrets needed
   ├─> Verify OTP from Firestore
   └─> Return custom token

6. Flutter App
   └─> Signs in with custom token
```

## Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| Cold start (first secret access) | +10-50ms | One-time per instance |
| Warm instance (cached secrets) | ~0ms | Secrets cached in memory |
| Secret rotation | +10-50ms | Only on next cold start |
| Function execution | Same as before | No ongoing overhead |

## Secret Versioning Strategy

```
Production Flow:

MAILGUN_API_KEY
├── v1 (current, enabled)
├── v2 (testing, disabled)
└── v3 (future, disabled)

Deployment Process:
1. Create v2 with new key
2. Test with v2 (disabled by default)
3. Enable v2 (gradual rollout)
4. Disable v1 after verification
5. Delete v1 after 30 days
```

## Monitoring & Observability

```
┌─────────────────────────┐
│   Function Execution    │
└───────────┬─────────────┘
            │
            ├─> Cloud Logging
            │   └─> Function logs
            │       └─> Secret access logs
            │
            ├─> Cloud Monitoring
            │   └─> Secret access metrics
            │       └─> Access latency
            │
            └─> Audit Logs
                └─> IAM policy changes
                    └─> Secret access attempts
```

## Disaster Recovery

### Backup Strategy
```
Secret Manager
├─> Automatic versioning (built-in backups)
├─> Point-in-time recovery (any version)
└─> Multi-region replication (automatic)

Recovery Time Objective (RTO): < 5 minutes
Recovery Point Objective (RPO): 0 (no data loss)
```

### Rollback Plan
```
1. Code rollback
   git checkout <previous-commit>
   firebase deploy --only functions

2. Secret rollback
   gcloud secrets versions enable <previous-version>
   gcloud secrets versions disable <current-version>

3. Verify
   firebase functions:log
   Test critical endpoints
```

## Cost Analysis

### Secret Manager Pricing (as of 2024)
- **Secret versions**: $0.06 per secret version per month
- **Access operations**: Free tier: 10,000 accesses/month
- **Additional accesses**: $0.03 per 10,000 accesses

### Estimated Monthly Cost
```
Secrets: 10 secrets × $0.06 = $0.60/month
Accesses: ~1,000/month (within free tier) = $0.00
Total: ~$0.60/month
```

**Previous approach (functions.config())**: $0.00 (but with security trade-offs)

---

**Architecture designed for security, scalability, and maintainability** 🔒
