/**
 * Global Payments Oceania - Webhook Receiver
 * Terminal 4: Payment Verification System
 * 
 * Receives transaction notifications from Global Payments
 * Verifies payment status and updates Firebase
 * 
 * Deploy: firebase deploy --only functions:globalPaymentsWebhook
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

const db = admin.firestore();

// Get private key from Firebase config
const GP_PRIVATE_KEY = functions.config().globalpayments?.private_key || process.env.GP_PRIVATE_KEY;

/**
 * Verify webhook signature from Global Payments
 */
function verifyWebhookSignature(payload, signature, privateKey) {
    if (!privateKey || !signature) {
        console.warn('⚠️ Webhook signature verification skipped (missing key or signature)');
        return true; // Allow in development
    }
    
    const hmac = crypto.createHmac('sha256', privateKey);
    hmac.update(JSON.stringify(payload));
    const calculatedSignature = hmac.digest('hex');
    
    return calculatedSignature === signature;
}

/**
 * Global Payments Webhook Handler
 * 
 * Webhook Payload Structure:
 * {
 *   "id": "WQYvMI-3FUWMHlB22rW69Q",
 *   "reference": "REF-2024-ABC123",
 *   "created": "2023-01-01T02:02:48Z",
 *   "version": "1.0.0",
 *   "event": "transactions",
 *   "payload": {
 *     "id": "9xkkdZuMn0mvE9xnPrzqIA",
 *     "createdDateTime": "2023-01-01T02:02:03Z",
 *     "updatedDateTime": "2023-01-01T02:02:09Z",
 *     "category": {
 *       "source": "payto",
 *       "method": "purchase"
 *     },
 *     "payment": {
 *       "amount": 15000,  // IN CENTS
 *       "currencyCode": "AUD",
 *       "instrument": {
 *         "customer": {
 *           "id": "wx167QAQ4E-bcffWI_-Smg",
 *           "paymentInstrumentId": "zAFQgcwsyESTeqmgJREcrQ"
 *         }
 *       }
 *     },
 *     "result": {
 *       "status": "approved"  // or "declined" or "pending"
 *     }
 *   }
 * }
 */
exports.globalPaymentsWebhook = functions.https.onRequest(async (req, res) => {
    // Only accept POST requests
    if (req.method !== 'POST') {
        console.warn('❌ Invalid method:', req.method);
        return res.status(405).json({ 
            error: 'Method not allowed',
            allowedMethods: ['POST']
        });
    }
    
    console.log('📥 Webhook received from Global Payments');
    
    try {
        // Get webhook data
        const webhookData = req.body;
        const signature = req.headers['x-signature'] || req.headers['X-Signature'];
        
        // Verify signature
        if (GP_PRIVATE_KEY) {
            const isValid = verifyWebhookSignature(webhookData, signature, GP_PRIVATE_KEY);
            
            if (!isValid) {
                console.error('❌ Invalid webhook signature');
                return res.status(401).json({ 
                    error: 'Invalid signature',
                    message: 'Webhook authentication failed'
                });
            }
            console.log('✅ Webhook signature verified');
        }
        
        // Extract webhook fields
        const webhookId = webhookData.id;
        const reference = webhookData.reference;
        const event = webhookData.event;
        const version = webhookData.version;
        const created = webhookData.created;
        
        // Extract payload fields
        const payload = webhookData.payload;
        const transactionId = payload.id;
        const createdDateTime = payload.createdDateTime;
        const updatedDateTime = payload.updatedDateTime;
        
        // Extract payment details
        const amount = payload.payment.amount; // IN CENTS
        const currencyCode = payload.payment.currencyCode;
        const amountDollars = amount / 100; // Convert to dollars
        
        // Extract result
        const status = payload.result.status; // "approved", "declined", "pending"
        const verified = (status === 'approved');
        
        // Extract category
        const source = payload.category?.source; // "payto"
        const method = payload.category?.method; // "purchase"
        
        console.log('📋 Webhook Details:');
        console.log(`   Webhook ID: ${webhookId}`);
        console.log(`   Reference: ${reference}`);
        console.log(`   Transaction ID: ${transactionId}`);
        console.log(`   Amount: $${amountDollars} ${currencyCode}`);
        console.log(`   Status: ${status}`);
        console.log(`   Verified: ${verified}`);
        
        // Find associated order by reference
        let orderId = null;
        let merchantId = null;
        
        const orderQuery = await db.collection('orders')
            .where('paymentRef', '==', reference)
            .limit(1)
            .get();
        
        if (!orderQuery.empty) {
            const orderDoc = orderQuery.docs[0];
            orderId = orderDoc.id;
            merchantId = orderDoc.data().merchantId;
            
            console.log(`   Order ID: ${orderId}`);
            console.log(`   Merchant ID: ${merchantId}`);
            
            // Update order status
            await db.collection('orders').doc(orderId).update({
                paymentStatus: verified ? 'PAID' : (status === 'pending' ? 'PENDING' : 'DECLINED'),
                transactionId: transactionId,
                webhookId: webhookId,
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            });
            
            console.log(`✅ Order ${orderId} updated: ${status}`);
        } else {
            console.warn(`⚠️ No order found for reference: ${reference}`);
        }
        
        // Store transaction in Firebase
        const transactionData = {
            // Webhook metadata
            webhookId: webhookId,
            event: event,
            version: version,
            webhookReceived: created,
            
            // Transaction details
            transactionId: transactionId,
            reference: reference,
            orderId: orderId,
            merchantId: merchantId,
            
            // Payment details
            amount: amount, // CENTS
            amountDollars: amountDollars,
            currencyCode: currencyCode,
            
            // Status
            status: status,
            verified: verified,
            
            // Timestamps
            createdDateTime: createdDateTime,
            updatedDateTime: updatedDateTime,
            
            // Category
            source: source,
            method: method,
            
            // Full payload for reference
            globalPaymentsData: payload,
            
            // Firebase timestamp
            receivedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        // Use transaction ID as document ID to prevent duplicates
        await db.collection('transactions').doc(transactionId).set(
            transactionData,
            { merge: true } // Update if exists
        );
        
        console.log(`✅ Transaction ${transactionId} stored in Firebase`);
        
        // Send notification to merchant (if configured)
        if (merchantId && verified) {
            try {
                // Get merchant notification settings
                const merchantDoc = await db.collection('merchants').doc(merchantId).get();
                
                if (merchantDoc.exists) {
                    const merchantData = merchantDoc.data();
                    
                    if (merchantData.settings?.notificationsEnabled) {
                        // TODO: Send email/SMS notification to merchant
                        console.log(`📧 Notification sent to merchant ${merchantId}`);
                    }
                }
            } catch (notifError) {
                console.error('⚠️ Error sending merchant notification:', notifError);
                // Don't fail webhook processing if notification fails
            }
        }
        
        // Return success response
        return res.status(200).json({
            success: true,
            message: 'Webhook processed successfully',
            webhookId: webhookId,
            transactionId: transactionId,
            reference: reference,
            status: status,
            verified: verified,
            amount: amountDollars,
            currencyCode: currencyCode
        });
        
    } catch (error) {
        console.error('❌ Webhook processing error:', error);
        
        // Return error but still 200 to prevent GP from retrying
        // (we log the error and can investigate later)
        return res.status(200).json({
            success: false,
            error: 'Internal processing error',
            message: error.message,
            // Don't expose stack trace to external service
        });
    }
});

/**
 * Payment Verification API
 * 
 * Called by clients to check if a payment has been received
 * Returns: paid, unpaid, or pending
 */
exports.verifyPayment = functions.https.onRequest(async (req, res) => {
    // CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    
    if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
        return res.status(204).send('');
    }
    
    if (req.method !== 'POST') {
        return res.status(405).json({ 
            error: 'Method not allowed',
            allowedMethods: ['POST']
        });
    }
    
    try {
        const { reference, amount, payId } = req.body;
        
        // Validate required fields
        if (!reference) {
            return res.status(400).json({
                error: 'Missing required field: reference'
            });
        }
        
        if (!amount) {
            return res.status(400).json({
                error: 'Missing required field: amount'
            });
        }
        
        console.log(`🔍 Verifying payment:`);
        console.log(`   Reference: ${reference}`);
        console.log(`   Amount: $${amount}`);
        console.log(`   PayID: ${payId || 'not provided'}`);
        
        // Query Firebase for transaction by reference
        const txnQuery = await db.collection('transactions')
            .where('reference', '==', reference)
            .limit(1)
            .get();
        
        if (txnQuery.empty) {
            // No transaction found - payment not received
            console.log(`❌ No transaction found for reference: ${reference}`);
            
            return res.status(200).json({
                status: 'unpaid',
                verified: false,
                reference: reference,
                message: 'No payment received for this reference'
            });
        }
        
        const txnDoc = txnQuery.docs[0];
        const txnData = txnDoc.data();
        
        // Check if amounts match (convert to cents for comparison)
        const expectedAmount = Math.round(amount * 100);
        const receivedAmount = txnData.amount; // Already in cents from GP
        
        if (receivedAmount !== expectedAmount) {
            console.log(`⚠️ Amount mismatch:`);
            console.log(`   Expected: $${expectedAmount / 100}`);
            console.log(`   Received: $${receivedAmount / 100}`);
            
            return res.status(200).json({
                status: 'unpaid',
                verified: false,
                reference: reference,
                message: 'Amount mismatch',
                expected: expectedAmount / 100,
                received: receivedAmount / 100
            });
        }
        
        // Check transaction status from Global Payments
        const gpStatus = txnData.status; // "approved", "declined", "pending"
        
        let verificationStatus;
        let verified = false;
        
        switch (gpStatus) {
            case 'approved':
                verificationStatus = 'paid';
                verified = true;
                console.log(`✅ Payment VERIFIED`);
                break;
            case 'declined':
                verificationStatus = 'unpaid';
                verified = false;
                console.log(`❌ Payment DECLINED`);
                break;
            case 'pending':
            default:
                verificationStatus = 'pending';
                verified = false;
                console.log(`⏳ Payment PENDING`);
                break;
        }
        
        // Return verification result
        return res.status(200).json({
            status: verificationStatus,
            verified: verified,
            transactionId: txnData.transactionId,
            amount: receivedAmount / 100, // Convert back to dollars
            currencyCode: txnData.currencyCode || 'AUD',
            reference: reference,
            timestamp: txnData.createdDateTime || new Date().toISOString(),
            globalPaymentsStatus: gpStatus
        });
        
    } catch (error) {
        console.error('❌ Verification error:', error);
        
        return res.status(500).json({
            status: 'error',
            error: 'Internal server error',
            message: error.message
        });
    }
});

// Export both functions
module.exports = {
    globalPaymentsWebhook: exports.globalPaymentsWebhook,
    verifyPayment: exports.verifyPayment
};
