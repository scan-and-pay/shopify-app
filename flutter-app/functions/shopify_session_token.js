/**
 * Shopify Session Token Verification for Firebase Cloud Functions
 *
 * This middleware verifies JWT session tokens from Shopify App Bridge
 * using Shopify's JWKS (JSON Web Key Set)
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Shopify JWKS endpoint
const SHOPIFY_JWKS_URL = 'https://shopify.com/.well-known/jwks.json';

// Your Shopify app's API key (client ID)
const SHOPIFY_API_KEY = 'c8e9eb698f57cdc0a5d62d83c9137436';

// Create JWKS client to fetch Shopify's public keys
const client = jwksClient({
  jwksUri: SHOPIFY_JWKS_URL,
  cache: true,
  cacheMaxAge: 86400000, // 24 hours
  rateLimit: true,
  jwksRequestsPerMinute: 10,
});

/**
 * Get the signing key from Shopify's JWKS
 */
function getKey(header, callback) {
  client.getSigningKey(header.kid, (err, key) => {
    if (err) {
      console.error('Error getting signing key:', err);
      return callback(err);
    }
    const signingKey = key.getPublicKey();
    callback(null, signingKey);
  });
}

/**
 * Verify Shopify session token (JWT)
 * @param {string} token - The JWT session token from Authorization header
 * @returns {Promise<Object>} - Decoded and verified token payload
 */
async function verifySessionToken(token) {
  return new Promise((resolve, reject) => {
    // Verify JWT with Shopify's public key
    jwt.verify(
      token,
      getKey,
      {
        audience: SHOPIFY_API_KEY, // Must match your app's API key
        issuer: (payload) => {
          // Issuer format: https://{shop-domain}/admin
          const shopDomain = payload.dest?.replace('https://', '').split('/')[0];
          return `https://${shopDomain}/admin`;
        },
        algorithms: ['RS256'], // Shopify uses RS256
      },
      (err, decoded) => {
        if (err) {
          console.error('Session token verification failed:', err.message);
          return reject(err);
        }

        console.log('✅ Session token verified for shop:', decoded.dest);
        resolve(decoded);
      }
    );
  });
}

/**
 * Middleware: Extract and verify session token from Authorization header
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Object|null} - Decoded token or null if verification fails
 */
async function authenticateSessionToken(req, res) {
  try {
    // Extract token from Authorization header
    const authHeader = req.headers.authorization || req.headers.Authorization;

    if (!authHeader) {
      console.error('❌ No Authorization header found');
      res.status(401).json({ error: 'Unauthorized - No session token provided' });
      return null;
    }

    // Extract Bearer token
    const match = authHeader.match(/^Bearer (.+)$/);
    if (!match) {
      console.error('❌ Invalid Authorization header format');
      res.status(401).json({ error: 'Unauthorized - Invalid token format' });
      return null;
    }

    const token = match[1];

    // Verify the session token
    const decoded = await verifySessionToken(token);

    console.log('✅ Authenticated shop:', decoded.dest);
    console.log('  User ID:', decoded.sub);
    console.log('  Expires:', new Date(decoded.exp * 1000).toISOString());

    return decoded; // Contains: dest (shop URL), sub (user ID), aud, iss, exp, nbf, iat, jti, sid

  } catch (error) {
    console.error('❌ Session token authentication failed:', error.message);
    res.status(401).json({
      error: 'Unauthorized - Invalid session token',
      details: error.message,
    });
    return null;
  }
}

/**
 * Example Firebase Function: Get Merchant Data (with session token auth)
 */
exports.getMerchantData = functions
  .region('us-central1')
  .https.onRequest(async (req, res) => {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }

    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    // CRITICAL: Authenticate session token
    const sessionData = await authenticateSessionToken(req, res);
    if (!sessionData) {
      return; // Response already sent by middleware
    }

    // Extract shop domain from session token
    const shopDomain = sessionData.dest.replace('https://', '').split('/')[0];

    try {
      // Example: Fetch merchant data from Firestore
      const db = admin.firestore();
      const merchantDoc = await db.collection('merchants').doc(shopDomain).get();

      if (!merchantDoc.exists) {
        return res.status(404).json({
          error: 'Merchant not found',
          shop: shopDomain,
        });
      }

      const merchantData = merchantDoc.data();

      return res.status(200).json({
        success: true,
        shop: shopDomain,
        merchant: merchantData,
        authenticatedUser: sessionData.sub,
      });

    } catch (error) {
      console.error('Error fetching merchant data:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  });

/**
 * Example Firebase Function: Generate PayID QR (with session token auth)
 */
exports.generatePayIDQRWithAuth = functions
  .region('us-central1')
  .https.onRequest(async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
      return res.status(204).send('');
    }

    if (req.method !== 'POST') {
      return res.status(405).send('Method Not Allowed');
    }

    // CRITICAL: Verify session token
    const sessionData = await authenticateSessionToken(req, res);
    if (!sessionData) {
      return; // Response already sent
    }

    const shopDomain = sessionData.dest.replace('https://', '').split('/')[0];

    try {
      const { amount, currency, description } = req.body;

      // Validate request
      if (!amount || !currency) {
        return res.status(400).json({ error: 'Missing required fields' });
      }

      console.log(`Generating PayID QR for shop: ${shopDomain}`);
      console.log(`Amount: ${amount} ${currency}`);

      // TODO: Your PayID QR generation logic here
      const qrCodeData = {
        payid: 'merchant@scanandpay.com.au',
        amount: amount,
        currency: currency,
        description: description || 'Payment',
      };

      return res.status(200).json({
        success: true,
        shop: shopDomain,
        qrCodeUrl: `https://example.com/qr/${Date.now()}`,
        qrCodeData: qrCodeData,
        authenticatedBy: 'session-token',
      });

    } catch (error) {
      console.error('Error generating PayID QR:', error);
      return res.status(500).json({ error: 'Internal server error' });
    }
  });

// Export the verification function for reuse
exports.verifySessionToken = verifySessionToken;
exports.authenticateSessionToken = authenticateSessionToken;
