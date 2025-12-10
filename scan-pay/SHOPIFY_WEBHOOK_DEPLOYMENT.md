# Shopify Compliance Webhook Deployment Guide

## Summary

Your Shopify app webhook handlers are **already implemented** with built-in HMAC verification via `@shopify/shopify-app-react-router`. The 404 error you're experiencing is a **deployment/routing issue**, not a code issue.

## What Was Already Done

✅ **Webhook Routes Created** (in `app/routes/`):
- `webhooks.app.uninstalled.ts` - Handles app uninstallation
- `webhooks.customers.data_request.ts` - GDPR data request compliance
- `webhooks.customers.redact.ts` - GDPR customer data deletion
- `webhooks.shop.redact.ts` - Shop data deletion (48hrs after uninstall)

✅ **HMAC Verification**: Built into `authenticate.webhook(request)` from Shopify's library

## What Was Fixed

### 1. Dockerfile Updated
Changed from port 3000 to port 8080 to match standard reverse proxy configurations.

**Location**: `Dockerfile:5,11`

### 2. Webhook Subscriptions Added
All 4 mandatory compliance webhooks registered in Shopify app config.

**Location**: `shopify.app.toml:11-28`

### 3. Nginx Configuration Created
Complete nginx reverse proxy configuration with:
- SSL/HTTPS support
- Proper header forwarding for HMAC verification
- Webhook-specific routing
- Request buffering disabled for webhooks

**Location**: `nginx.conf` (new file)

---

## Deployment Steps

### Step 1: Rebuild and Deploy Docker Container

```bash
cd C:\dev\shopify-app\scan-pay

# Build new Docker image
docker build -t scanandpay-shopify:latest .

# Test locally first (optional)
docker run -p 8080:8080 \
  -e SHOPIFY_API_KEY="your_api_key" \
  -e SHOPIFY_API_SECRET="your_api_secret" \
  -e SHOPIFY_APP_URL="https://merchants.scanandpay.com.au" \
  -e SCOPES="read_customers,read_payment_terms,write_checkouts,write_orders,write_products" \
  scanandpay-shopify:latest

# Push to your container registry (example for Docker Hub)
docker tag scanandpay-shopify:latest YOUR_REGISTRY/scanandpay-shopify:latest
docker push YOUR_REGISTRY/scanandpay-shopify:latest

# Deploy to your production server (example for generic VPS)
ssh your-server "docker pull YOUR_REGISTRY/scanandpay-shopify:latest && docker-compose up -d"
```

### Step 2: Configure Nginx on Production Server

**Option A: Direct nginx Installation**

```bash
# SSH into your production server
ssh your-server

# Copy nginx.conf to nginx sites-available
sudo cp /path/to/nginx.conf /etc/nginx/sites-available/merchants.scanandpay.com.au

# Update SSL certificate paths in the config
sudo nano /etc/nginx/sites-available/merchants.scanandpay.com.au
# Edit lines 13-14 to point to your actual SSL certificates

# Create symlink to sites-enabled
sudo ln -s /etc/nginx/sites-available/merchants.scanandpay.com.au /etc/nginx/sites-enabled/

# Test nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx
```

**Option B: If Using Docker Compose with Nginx**

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  app:
    image: scanandpay-shopify:latest
    container_name: scanandpay-app
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=8080
      - SHOPIFY_API_KEY=${SHOPIFY_API_KEY}
      - SHOPIFY_API_SECRET=${SHOPIFY_API_SECRET}
      - SHOPIFY_APP_URL=https://merchants.scanandpay.com.au
      - SCOPES=read_customers,read_payment_terms,write_checkouts,write_orders,write_products
    volumes:
      - ./data:/app/prisma
    networks:
      - scanandpay-network

  nginx:
    image: nginx:alpine
    container_name: scanandpay-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/ssl/certs:/etc/ssl/certs:ro
      - /etc/ssl/private:/etc/ssl/private:ro
    depends_on:
      - app
    networks:
      - scanandpay-network

networks:
  scanandpay-network:
    driver: bridge
```

Then deploy:

```bash
docker-compose up -d
```

### Step 3: Update Shopify App Configuration

```bash
# From your local development machine
cd C:\dev\shopify-app\scan-pay

# Deploy updated configuration to Shopify
npm run deploy

# Follow prompts to deploy
```

This will register all 4 webhook subscriptions with Shopify.

### Step 4: Verify Webhooks Are Accessible

Test each webhook endpoint manually:

```bash
# Test from external location (not your server)
curl -X POST https://merchants.scanandpay.com.au/webhooks/app/uninstalled \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Should return 401 (Unauthorized) - this is CORRECT
# It means the endpoint is reachable but HMAC verification is working
# A 404 means routing is broken
```

Expected responses:
- **200 OK**: Webhook processed (only happens with valid HMAC from Shopify)
- **401 Unauthorized**: HMAC verification failed (endpoint is working correctly!)
- **404 Not Found**: Routing issue - nginx not forwarding to app

### Step 5: Run Shopify Automated App Checklist

1. Go to Shopify Partners Dashboard
2. Navigate to your app: "Scan & Pay"
3. Go to "App Setup" → "Compliance"
4. Click "Run Automated Tests"
5. All webhook tests should now pass ✅

---

## Environment Variables Required

Ensure these are set in your production environment:

```bash
# Required
SHOPIFY_API_KEY=c8e9eb698f57cdc0a5d62d83c9137436
SHOPIFY_API_SECRET=your_actual_secret_here
SHOPIFY_APP_URL=https://merchants.scanandpay.com.au

# Optional
SCOPES=read_customers,read_payment_terms,write_checkouts,write_orders,write_products
NODE_ENV=production
PORT=8080
```

---

## Troubleshooting

### Issue: Still Getting 404

**Check 1: Is the app running on port 8080?**
```bash
docker logs scanandpay-app | grep -i port
# Should see: "Listening on http://0.0.0.0:8080"
```

**Check 2: Is nginx forwarding correctly?**
```bash
sudo nginx -t
sudo tail -f /var/log/nginx/scanandpay-error.log
```

**Check 3: Test from inside the server**
```bash
ssh your-server
curl http://127.0.0.1:8080/webhooks/app/uninstalled
# Should NOT return 404
```

### Issue: Getting 401 (Unauthorized)

This is **EXPECTED** if you're testing manually. The `authenticate.webhook()` function verifies Shopify's HMAC signature. Manual requests will fail.

To test properly, trigger a real webhook from Shopify:
1. Install your app on a test store
2. Uninstall it
3. Check server logs for webhook processing

### Issue: HMAC Verification Failing from Shopify

Check nginx is preserving headers:
```bash
# In nginx.conf, ensure this line exists:
proxy_set_header X-Shopify-Hmac-Sha256 $http_x_shopify_hmac_sha256;
```

Also verify `SHOPIFY_API_SECRET` environment variable matches your Partner Dashboard.

---

## How HMAC Verification Works

The `authenticate.webhook(request)` function automatically:

1. Reads `X-Shopify-Hmac-Sha256` header
2. Reads raw request body
3. Computes HMAC-SHA256 using `SHOPIFY_API_SECRET`
4. Compares computed hash with header value
5. Returns 401 if mismatch

**You don't need to implement this yourself** - it's already done by `@shopify/shopify-app-react-router`.

---

## Quick Deployment Checklist

- [ ] Update Dockerfile (already done ✅)
- [ ] Update shopify.app.toml (already done ✅)
- [ ] Create nginx.conf (already done ✅)
- [ ] Rebuild Docker image
- [ ] Deploy Docker container to production
- [ ] Configure nginx on production server
- [ ] Update SSL certificate paths in nginx config
- [ ] Test nginx configuration: `sudo nginx -t`
- [ ] Reload nginx: `sudo systemctl reload nginx`
- [ ] Deploy Shopify app config: `npm run deploy`
- [ ] Verify endpoints return 401 (not 404): `curl -X POST https://merchants.scanandpay.com.au/webhooks/app/uninstalled`
- [ ] Run Shopify automated compliance tests
- [ ] Monitor logs: `docker logs -f scanandpay-app`

---

## Post-Deployment Verification

After deployment, check:

```bash
# 1. Docker container is running
docker ps | grep scanandpay

# 2. App is listening on port 8080
docker logs scanandpay-app | grep -i listening

# 3. Nginx is running
sudo systemctl status nginx

# 4. Endpoints are reachable (should return 401, not 404)
curl -X POST https://merchants.scanandpay.com.au/webhooks/app/uninstalled
curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/data_request
curl -X POST https://merchants.scanandpay.com.au/webhooks/customers/redact
curl -X POST https://merchants.scanandpay.com.au/webhooks/shop/redact
```

All should return **401 Unauthorized** (HMAC verification working) or **200 OK** with valid Shopify signature.

---

## Additional Notes

### React Router File-Based Routing

Your app uses React Router's file-based routing. The route files are automatically mapped:

- `app/routes/webhooks.app.uninstalled.ts` → `/webhooks/app/uninstalled`
- `app/routes/webhooks.customers.data_request.ts` → `/webhooks/customers/data_request`
- `app/routes/webhooks.customers.redact.ts` → `/webhooks/customers/redact`
- `app/routes/webhooks.shop.redact.ts` → `/webhooks/shop/redact`

**No Express.js configuration needed** - React Router handles this automatically.

### Database Migrations

If you haven't run the AppInstallation migration yet:

```bash
cd C:\dev\shopify-app\scan-pay

# Create migration
npm run prisma migrate dev --name add_app_installation

# Or in production
docker exec -it scanandpay-app npm run setup
```

This creates the `AppInstallation` table used by `webhooks.app.uninstalled.ts`.

---

## Support

If issues persist after following this guide:

1. Check Docker logs: `docker logs -f scanandpay-app`
2. Check nginx logs: `sudo tail -f /var/log/nginx/scanandpay-error.log`
3. Verify environment variables: `docker exec scanandpay-app env | grep SHOPIFY`
4. Test locally with `npm run dev` to ensure routes work in development

---

## Summary

**Your code is correct.** The issue is deployment configuration. Follow the steps above to:

1. Deploy updated Docker image (port 8080)
2. Configure nginx to proxy to port 8080
3. Deploy Shopify app config with all webhooks
4. Verify endpoints are reachable (401 response is correct)
5. Run Shopify compliance tests

All webhook handlers already have HMAC verification built-in via `authenticate.webhook()`.
