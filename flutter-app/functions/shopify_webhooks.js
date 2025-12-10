const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

/**
 * Verify Shopify HMAC signature
 * @param {Buffer} bodyBuffer - Raw request body as Buffer
 * @param {string} hmacHeader - X-Shopify-Hmac-Sha256 header value
 * @returns {boolean} - True if signature is valid
 */
function verifyShopifyWebhook(bodyBuffer, hmacHeader) {
  const shopifySecret = process.env.SHOPIFY_API_SECRET || functions.config().shopify?.api_secret;

  if (!shopifySecret) {
    console.error('SHOPIFY_API_SECRET not configured');
    return false;
  }

  const hash = crypto
    .createHmac('sha256', shopifySecret)
    .update(bodyBuffer)
    .digest('base64');

  return hash === hmacHeader;
}

/**
 * Webhook: app/uninstalled
 * Called when merchant uninstalls the app
 */
exports.appUninstalled = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Shopify-Hmac-Sha256, X-Shopify-Shop-Domain, X-Shopify-Topic');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    // Get raw body for HMAC verification
    const rawBody = req.rawBody;
    const hmacHeader = req.headers['x-shopify-hmac-sha256'];
    const shopDomain = req.headers['x-shopify-shop-domain'];
    const topic = req.headers['x-shopify-topic'];

    console.log(`Received webhook: ${topic} from ${shopDomain}`);

    // Verify HMAC
    if (!verifyShopifyWebhook(rawBody, hmacHeader)) {
      console.error('HMAC verification failed');
      return res.status(401).send('Unauthorized - Invalid HMAC');
    }

    console.log('HMAC verification passed');

    const payload = JSON.parse(rawBody.toString('utf8'));

    // Mark shop as uninstalled in Firestore
    const db = admin.firestore();
    await db.collection('shopify_installations').doc(shopDomain).set({
      shop: shopDomain,
      installed: false,
      uninstalledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`Marked shop ${shopDomain} as uninstalled`);

    // Delete any sessions or app data for this shop
    const sessionsSnapshot = await db.collection('shopify_sessions')
      .where('shop', '==', shopDomain)
      .get();

    const batch = db.batch();
    sessionsSnapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();

    console.log(`Deleted ${sessionsSnapshot.size} sessions for shop ${shopDomain}`);

    return res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing app/uninstalled webhook:', error);
    return res.status(500).send('Internal Server Error');
  }
});

/**
 * Webhook: customers/data_request
 * GDPR compliance - customer requests their data
 */
exports.customersDataRequest = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Shopify-Hmac-Sha256, X-Shopify-Shop-Domain, X-Shopify-Topic');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    const rawBody = req.rawBody;
    const hmacHeader = req.headers['x-shopify-hmac-sha256'];
    const shopDomain = req.headers['x-shopify-shop-domain'];
    const topic = req.headers['x-shopify-topic'];

    console.log(`Received webhook: ${topic} from ${shopDomain}`);

    // Verify HMAC
    if (!verifyShopifyWebhook(rawBody, hmacHeader)) {
      console.error('HMAC verification failed');
      return res.status(401).send('Unauthorized - Invalid HMAC');
    }

    console.log('HMAC verification passed');

    const payload = JSON.parse(rawBody.toString('utf8'));
    console.log('Payload:', JSON.stringify(payload, null, 2));

    const { customer, shop_domain, orders_requested } = payload;

    console.log(`GDPR data request for customer ${customer?.id} in shop ${shop_domain}`);
    console.log(`Customer email: ${customer?.email}, Orders requested: ${orders_requested?.length || 0}`);

    // TODO: Implement GDPR data request logic
    // 1. Query Firestore for any customer data associated with this shop/customer
    // 2. Compile customer data into required format
    // 3. Send data to customer via email or make it available for download
    // 4. You have 30 days to fulfill this request

    const db = admin.firestore();
    await db.collection('gdpr_requests').add({
      type: 'data_request',
      shop: shop_domain,
      customerId: customer?.id,
      customerEmail: customer?.email,
      ordersRequested: orders_requested || [],
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      dueDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
    });

    console.log('GDPR data request logged');

    return res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing customers/data_request webhook:', error);
    return res.status(500).send('Internal Server Error');
  }
});

/**
 * Webhook: customers/redact
 * GDPR compliance - delete customer data
 */
exports.customersRedact = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Shopify-Hmac-Sha256, X-Shopify-Shop-Domain, X-Shopify-Topic');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    const rawBody = req.rawBody;
    const hmacHeader = req.headers['x-shopify-hmac-sha256'];
    const shopDomain = req.headers['x-shopify-shop-domain'];
    const topic = req.headers['x-shopify-topic'];

    console.log(`Received webhook: ${topic} from ${shopDomain}`);

    // Verify HMAC
    if (!verifyShopifyWebhook(rawBody, hmacHeader)) {
      console.error('HMAC verification failed');
      return res.status(401).send('Unauthorized - Invalid HMAC');
    }

    console.log('HMAC verification passed');

    const payload = JSON.parse(rawBody.toString('utf8'));
    console.log('Payload:', JSON.stringify(payload, null, 2));

    const { customer, shop_domain, orders_to_redact } = payload;

    console.log(`Customer redaction requested for customer ${customer?.id} in shop ${shop_domain}`);
    console.log(`Customer email: ${customer?.email}, Orders to redact: ${orders_to_redact?.length || 0}`);

    // TODO: Implement customer data deletion logic
    // 1. Query Firestore for customer data associated with this shop/customer
    // 2. Delete or anonymize all customer personal data
    // 3. Log the deletion for audit purposes
    // 4. You have 30 days to complete this

    const db = admin.firestore();

    // Log the redaction request
    await db.collection('gdpr_requests').add({
      type: 'customer_redact',
      shop: shop_domain,
      customerId: customer?.id,
      customerEmail: customer?.email,
      ordersToRedact: orders_to_redact || [],
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      dueDate: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days from now
    });

    console.log('Customer redaction request logged');

    // Example: Delete customer payment history (if stored)
    // const paymentsSnapshot = await db.collection('payments')
    //   .where('shop', '==', shop_domain)
    //   .where('customerId', '==', customer?.id)
    //   .get();
    //
    // const batch = db.batch();
    // paymentsSnapshot.forEach((doc) => {
    //   batch.delete(doc.ref);
    // });
    // await batch.commit();

    return res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing customers/redact webhook:', error);
    return res.status(500).send('Internal Server Error');
  }
});

/**
 * Webhook: shop/redact
 * GDPR compliance - delete all shop data (48 hours after uninstall)
 */
exports.shopRedact = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST');
  res.set('Access-Control-Allow-Headers', 'Content-Type, X-Shopify-Hmac-Sha256, X-Shopify-Shop-Domain, X-Shopify-Topic');

  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  try {
    const rawBody = req.rawBody;
    const hmacHeader = req.headers['x-shopify-hmac-sha256'];
    const shopDomain = req.headers['x-shopify-shop-domain'];
    const topic = req.headers['x-shopify-topic'];

    console.log(`Received webhook: ${topic} from ${shopDomain}`);

    // Verify HMAC
    if (!verifyShopifyWebhook(rawBody, hmacHeader)) {
      console.error('HMAC verification failed');
      return res.status(401).send('Unauthorized - Invalid HMAC');
    }

    console.log('HMAC verification passed');

    const payload = JSON.parse(rawBody.toString('utf8'));
    console.log('Payload:', JSON.stringify(payload, null, 2));

    const { shop_id, shop_domain: payloadShopDomain } = payload;

    console.log(`Shop redaction requested for shop ${payloadShopDomain || shopDomain} (ID: ${shop_id})`);
    console.log('This webhook is sent 48 hours after app uninstall');

    // TODO: Delete ALL shop-related data
    // 1. Delete all shop-related data from Firestore
    // 2. Delete all customer data associated with this shop
    // 3. Clean up any stored configurations, payment data, etc.

    const db = admin.firestore();
    const shopToDelete = payloadShopDomain || shopDomain;

    // Delete shop installation record
    await db.collection('shopify_installations').doc(shopToDelete).delete();
    console.log(`Deleted installation record for ${shopToDelete}`);

    // Delete all sessions
    const sessionsSnapshot = await db.collection('shopify_sessions')
      .where('shop', '==', shopToDelete)
      .get();

    const batch = db.batch();
    sessionsSnapshot.forEach((doc) => {
      batch.delete(doc.ref);
    });
    await batch.commit();
    console.log(`Deleted ${sessionsSnapshot.size} sessions for ${shopToDelete}`);

    // Example: Delete all shop-related payments
    // const paymentsSnapshot = await db.collection('payments')
    //   .where('shop', '==', shopToDelete)
    //   .get();
    //
    // const paymentBatch = db.batch();
    // paymentsSnapshot.forEach((doc) => {
    //   paymentBatch.delete(doc.ref);
    // });
    // await paymentBatch.commit();

    // Log the redaction
    await db.collection('gdpr_requests').add({
      type: 'shop_redact',
      shop: shopToDelete,
      shopId: shop_id,
      status: 'completed',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log(`Shop redaction completed for ${shopToDelete}`);

    return res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing shop/redact webhook:', error);
    return res.status(500).send('Internal Server Error');
  }
});
