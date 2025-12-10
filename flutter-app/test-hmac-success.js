/**
 * Test script to demonstrate webhook HMAC success path
 * This simulates what Shopify's automated check does
 */

const crypto = require('crypto');
const https = require('https');

// Your Shopify API Secret (get from Firebase Secret Manager or shopify.app.toml)
const SHOPIFY_API_SECRET = process.env.SHOPIFY_API_SECRET || 'your-shopify-api-secret-here';

// Webhook endpoint to test
const WEBHOOK_URL = 'https://merchants.scanandpay.com.au/webhooks/app/uninstalled';

// Test payload (what Shopify sends)
const payload = JSON.stringify({
  id: 12345,
  shop_domain: 'test-shop.myshopify.com',
  shop_id: 54321,
  uninstalled_at: new Date().toISOString()
});

// Generate valid HMAC signature
const hmac = crypto
  .createHmac('sha256', SHOPIFY_API_SECRET)
  .update(payload)
  .digest('base64');

console.log('=== Testing Webhook with Valid HMAC ===\n');
console.log('Endpoint:', WEBHOOK_URL);
console.log('Payload:', payload);
console.log('HMAC:', hmac);
console.log('\nSending request...\n');

// Parse URL
const url = new URL(WEBHOOK_URL);

// Make request
const options = {
  hostname: url.hostname,
  path: url.pathname,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
    'X-Shopify-Hmac-Sha256': hmac,
    'X-Shopify-Shop-Domain': 'test-shop.myshopify.com',
    'X-Shopify-Topic': 'app/uninstalled',
    'X-Shopify-API-Version': '2024-10'
  }
};

const req = https.request(options, (res) => {
  console.log('HTTP Status:', res.statusCode);
  console.log('Status Message:', res.statusMessage);
  console.log('\nResponse Headers:');
  console.log(JSON.stringify(res.headers, null, 2));
  console.log('\nResponse Body:');

  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    console.log(data);
    console.log('\n=== Test Result ===');

    if (res.statusCode === 200) {
      console.log('✅ SUCCESS: Webhook returned 200 OK for valid HMAC');
      console.log('✅ Shopify automated check should PASS');
    } else if (res.statusCode === 401) {
      console.log('❌ FAILED: HMAC verification failed (check your SHOPIFY_API_SECRET)');
    } else {
      console.log('❌ FAILED: Unexpected status code:', res.statusCode);
    }
  });
});

req.on('error', (error) => {
  console.error('Error:', error);
});

req.write(payload);
req.end();
