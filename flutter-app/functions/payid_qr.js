const functions = require('firebase-functions');
const admin = require('firebase-admin');

// PayID QR Code generation function
exports.generatePayIDQR = functions
    .region('australia-southeast1')
    .https.onCall(async (data, context) => {
        console.log('🔗 generatePayIDQR function started');
        console.log('📋 Input data:', JSON.stringify(data, null, 2));
        
        try {
            // Verify authentication
            if (!context.auth) {
                console.error('❌ User not authenticated');
                throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
            }
            console.log('✅ User authenticated:', context.auth.uid);

            const { amount, reference, payId, merchantName } = data;
            console.log('📋 Extracted parameters:', { amount, reference, payId, merchantName });

            // Validate required parameters
            if (!amount || typeof amount !== 'number' || amount <= 0) {
                console.error('❌ Invalid amount');
                throw new functions.https.HttpsError('invalid-argument', 'Valid amount is required');
            }

            if (!payId || typeof payId !== 'string') {
                console.error('❌ Invalid PayID');
                throw new functions.https.HttpsError('invalid-argument', 'Valid PayID is required');
            }

            // Generate payment ID
            const paymentId = generatePaymentId();
            const timestamp = new Date().toISOString();
            const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString(); // 5 minutes

            console.log('📋 Generated payment ID:', paymentId);

            // Generate NPP/EMV compliant QR code data
            const qrData = generateNPPQRCode({
                paymentId,
                amount,
                reference: reference || `Payment ${paymentId}`,
                payId,
                merchantName: merchantName || 'ScanPay Merchant',
                expiresAt,
            });

            console.log('🔗 Generated QR data length:', qrData.length);

            // Save payment intent to Firestore
            const paymentDoc = {
                paymentId,
                amount,
                reference: reference || `Payment ${paymentId}`,
                payId,
                merchantName: merchantName || 'ScanPay Merchant',
                status: 'pending',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: new Date(expiresAt),
                createdBy: context.auth.uid,
                qrData
            };

            await admin.firestore()
                .collection('payments')
                .doc(paymentId)
                .set(paymentDoc);

            console.log('💾 Payment intent saved to Firestore');

            const result = {
                success: true,
                paymentId,
                qrData,
                amount,
                reference: reference || `Payment ${paymentId}`,
                expiresAt,
                payId
            };
            
            console.log('🎉 Function completed successfully!');
            return result;

        } catch (error) {
            console.error('💥 Function failed with error:');
            console.error('📋 Error message:', error.message);
            console.error('📋 Error stack:', error.stack);
            
            if (error instanceof functions.https.HttpsError) {
                throw error;
            }
            
            throw new functions.https.HttpsError('internal', 
                `Failed to generate PayID QR: ${error.message}`);
        }
    });

// Generate NPP/EMV compliant QR code data
function generateNPPQRCode({
    paymentId,
    amount,
    reference,
    payId,
    merchantName,
    expiresAt
}) {
    // NPP QR Code follows EMV QR Code standard
    // This is a simplified version - in production you'd use proper EMV library
    
    // EMV QR Code data elements
    const payloadFormatIndicator = '01'; // Fixed value
    const pointOfInitiationMethod = '12'; // Dynamic QR Code
    
    // Merchant Account Information (PayID)
    const merchantAccountInfo = formatEMVData('26', [
        formatEMVData('00', 'AU.GOV.NPP'),  // Globally unique identifier for NPP
        formatEMVData('01', payId),          // PayID
        formatEMVData('02', merchantName)    // Merchant name
    ].join(''));
    
    // Transaction Currency (Australian Dollar)
    const transactionCurrency = '5303036'; // AUD ISO code 036
    
    // Transaction Amount
    const transactionAmount = formatEMVData('54', amount.toFixed(2));
    
    // Country Code
    const countryCode = '5802AU'; // Australia
    
    // Merchant Name
    const merchantNameField = formatEMVData('59', merchantName);
    
    // Merchant City (optional)
    const merchantCity = formatEMVData('60', 'Sydney');
    
    // Additional Data Field Template
    const additionalData = formatEMVData('62', [
        formatEMVData('01', reference),      // Bill Number/Reference
        formatEMVData('05', paymentId),      // Reference Label
        formatEMVData('07', expiresAt)       // Terminal Label (expiry)
    ].join(''));
    
    // Build the payload (without CRC)
    const payload = [
        formatEMVData('00', payloadFormatIndicator),
        formatEMVData('01', pointOfInitiationMethod),
        merchantAccountInfo,
        '52040000', // Merchant Category Code (0000 = not specified)
        transactionCurrency,
        transactionAmount,
        countryCode,
        merchantNameField,
        merchantCity,
        additionalData
    ].join('');
    
    // Calculate CRC16 and append
    const crc = calculateCRC16(payload + '6304');
    const finalPayload = payload + '63' + '04' + crc;
    
    console.log('🔗 Generated EMV QR payload:', finalPayload);
    return finalPayload;
}

// Format EMV data field
function formatEMVData(tag, value) {
    const length = value.length.toString().padStart(2, '0');
    return tag + length + value;
}

// Simple CRC16 calculation for EMV QR codes
function calculateCRC16(data) {
    let crc = 0xFFFF;
    const polynomial = 0x1021;
    
    for (let i = 0; i < data.length; i++) {
        crc ^= (data.charCodeAt(i) << 8);
        
        for (let j = 0; j < 8; j++) {
            if (crc & 0x8000) {
                crc = (crc << 1) ^ polynomial;
            } else {
                crc <<= 1;
            }
            crc &= 0xFFFF;
        }
    }
    
    return crc.toString(16).toUpperCase().padStart(4, '0');
}

// Generate unique payment ID
function generatePaymentId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

// Cloud Function to check payment status
exports.checkPayIDStatus = functions
    .region('australia-southeast1')
    .https.onCall(async (data, context) => {
        try {
            if (!context.auth) {
                throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
            }

            const { paymentId } = data;

            if (!paymentId) {
                throw new functions.https.HttpsError('invalid-argument', 'Payment ID is required');
            }

            const paymentDoc = await admin.firestore()
                .collection('payments')
                .doc(paymentId)
                .get();

            if (!paymentDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'Payment not found');
            }

            const paymentData = paymentDoc.data();

            return {
                success: true,
                paymentId,
                status: paymentData.status,
                amount: paymentData.amount,
                reference: paymentData.reference,
                createdAt: paymentData.createdAt,
                paidAt: paymentData.paidAt || null,
                expiresAt: paymentData.expiresAt
            };

        } catch (error) {
            console.error('Error checking PayID status:', error);
            
            if (error instanceof functions.https.HttpsError) {
                throw error;
            }
            
            throw new functions.https.HttpsError('internal', 
                `Failed to check payment status: ${error.message}`);
        }
    });