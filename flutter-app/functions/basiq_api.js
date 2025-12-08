const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Basiq API configuration
const BASIQ_API_KEY = functions.config().basiq?.api_key || 'YOUR_BASIQ_API_KEY';
const BASIQ_BASE_URL = 'https://au-api.basiq.io';
const BASIQ_VERSION = '3.0';

let accessToken = null;
let tokenExpiresAt = null;

// Helper function to authenticate with Basiq
async function authenticateBasiq() {
    console.log('🔐 Starting Basiq authentication...');
    
    if (accessToken && tokenExpiresAt && new Date() < tokenExpiresAt) {
        console.log('✅ Using cached access token');
        return accessToken;
    }

    try {
        console.log('📡 Making authentication request to:', `${BASIQ_BASE_URL}/token`);
        console.log('📋 Request headers:', {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Basic ${BASIQ_API_KEY.substring(0, 20)}...`,
            'basiq-version': BASIQ_VERSION
        });
        
        const response = await axios.post(`${BASIQ_BASE_URL}/token`, 
            new URLSearchParams({
                'scope': 'SERVER_ACCESS'
            }), {
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                    'Authorization': `Basic ${BASIQ_API_KEY}`,
                    'basiq-version': BASIQ_VERSION
                }
            }
        );

        accessToken = response.data.access_token;
        const expiresIn = response.data.expires_in;
        tokenExpiresAt = new Date(Date.now() + (expiresIn - 60) * 1000);

        console.log('✅ Basiq authentication successful! Token expires at:', tokenExpiresAt.toISOString());
        return accessToken;
    } catch (error) {
        console.error('❌ Basiq authentication failed!');
        console.error('📋 Error response status:', error.response?.status);
        console.error('📋 Error response headers:', error.response?.headers);
        console.error('📋 Error response data:', JSON.stringify(error.response?.data, null, 2));
        console.error('📋 Full error:', error.message);
        throw new Error('Failed to authenticate with Basiq API');
    }
}

// Helper function to get authenticated headers
async function getAuthHeaders() {
    const token = await authenticateBasiq();
    return {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'basiq-version': BASIQ_VERSION
    };
}

// Cloud Function to create Basiq Connect URL
exports.createBasiqConnect = functions
    .region('australia-southeast1')
    .https.onCall(async (data, context) => {
        console.log('🚀 createBasiqConnect function started');
        console.log('📋 Input data:', JSON.stringify(data, null, 2));
        
        try {
            // Verify authentication
            if (!context.auth) {
                console.error('❌ User not authenticated');
                throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
            }
            console.log('✅ User authenticated:', context.auth.uid);

            const { userId, name, payId, email, mobile } = data;
            console.log('📋 Extracted parameters:', { userId, name, payId, email, mobile });

            if (!userId || !name || !payId) {
                console.error('❌ Missing required parameters');
                throw new functions.https.HttpsError('invalid-argument', 'Missing required parameters');
            }

            // Get authenticated headers
            console.log('🔐 Getting authenticated headers...');
            const headers = await getAuthHeaders();
            console.log('✅ Got authenticated headers');

            // Step 1: Create or get Basiq user
            console.log('👤 Step 1: Creating Basiq user...');
            let basiqUser;
            try {
                // Try to create a new user
                const userEmail = email || (payId.includes('@') ? payId : `${name.replace(/\s+/g, '').toLowerCase()}@example.com`);
                let userMobile = mobile || (!payId.includes('@') ? payId : '');
                
                // Format mobile number for Basiq (Australian format)
                if (userMobile) {
                    // Remove all non-digit characters
                    userMobile = userMobile.replace(/\D/g, '');
                    
                    // Skip if empty after cleaning
                    if (!userMobile) {
                        userMobile = null;
                    } else {
                        // Convert to Australian international format
                        if (userMobile.startsWith('04') && userMobile.length === 10) {
                            // 04XXXXXXXX -> +614XXXXXXXX
                            userMobile = '+614' + userMobile.substring(2);
                        } else if (userMobile.startsWith('4') && userMobile.length === 9) {
                            // 4XXXXXXXX -> +614XXXXXXXX
                            userMobile = '+614' + userMobile.substring(1);
                        } else if (userMobile.startsWith('614') && userMobile.length === 12) {
                            // 614XXXXXXXX -> +614XXXXXXXX
                            userMobile = '+' + userMobile;
                        } else if (userMobile.startsWith('61') && userMobile.length === 11) {
                            // 61XXXXXXXX -> +61XXXXXXXX (but this is wrong format)
                            userMobile = null; // Skip invalid format
                        } else {
                            // Invalid format, skip
                            console.log('⚠️ Invalid mobile format, skipping:', userMobile);
                            userMobile = null;
                        }
                    }
                }
                
                // Create user payload - only include non-empty values
                const userPayload = {};
                if (userEmail) userPayload.email = userEmail;
                if (userMobile) userPayload.mobile = userMobile;
                
                console.log('📋 User creation payload:', userPayload);
                console.log('📡 Making request to:', `${BASIQ_BASE_URL}/users`);
                
                const createUserResponse = await axios.post(`${BASIQ_BASE_URL}/users`, userPayload, { headers });

                basiqUser = createUserResponse.data;
                console.log('✅ Created new Basiq user:', basiqUser.id);
            } catch (error) {
                console.error('❌ User creation failed!');
                console.error('📋 Error status:', error.response?.status);
                console.error('📋 Error data:', JSON.stringify(error.response?.data, null, 2));
                
                if (error.response?.status === 400) {
                    // User creation failed, create a unique identifier for now
                    console.log('⚠️ User creation failed, generating unique user ID');
                    basiqUser = { id: `user_${Date.now()}_${Math.random().toString(36).substr(2, 9)}` };
                } else {
                    throw error;
                }
            }

            // Step 2: Generate CLIENT_ACCESS token for Consent UI
            console.log('🎫 Step 2: Generating CLIENT_ACCESS token...');
            console.log('📋 Client token payload:', { scope: 'CLIENT_ACCESS', userId: basiqUser.id });
            
            const clientTokenResponse = await axios.post(`${BASIQ_BASE_URL}/token`, 
                new URLSearchParams({
                    'scope': 'CLIENT_ACCESS',
                    'userId': basiqUser.id
                }), {
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded',
                        'Authorization': `Basic ${BASIQ_API_KEY}`,
                        'basiq-version': BASIQ_VERSION
                    }
                }
            );

            const clientToken = clientTokenResponse.data.access_token;
            console.log('✅ Generated CLIENT_ACCESS token:', clientToken.substring(0, 20) + '...');

            // Step 3: Save Basiq user ID to Firestore
            console.log('💾 Step 3: Saving to Firestore...');
            await admin.firestore()
                .collection('users')
                .doc(context.auth.uid)
                .update({
                    basiqUserId: basiqUser.id,
                    basiqClientToken: clientToken,
                    lastBasiqConnect: admin.firestore.FieldValue.serverTimestamp()
                });
            console.log('✅ Saved to Firestore successfully');

            // Step 4: Generate Consent UI URL
            const consentUrl = `https://consent.basiq.io/home?userId=${basiqUser.id}&token=${clientToken}`;
            console.log('🌐 Step 4: Generated Consent UI URL:', consentUrl);

            const result = {
                success: true,
                connectUrl: consentUrl,
                basiqUserId: basiqUser.id,
                clientToken: clientToken
            };
            
            console.log('🎉 Function completed successfully!');
            console.log('📋 Result:', JSON.stringify(result, null, 2));
            return result;

        } catch (error) {
            console.error('💥 Function failed with error:');
            console.error('📋 Error message:', error.message);
            console.error('📋 Error stack:', error.stack);
            
            if (error instanceof functions.https.HttpsError) {
                throw error;
            }
            
            throw new functions.https.HttpsError('internal', 
                `Failed to create Basiq Connect session: ${error.message}`);
        }
    });

// Cloud Function to handle Basiq webhooks
exports.handleBasiqWebhook = functions
    .region('australia-southeast1')
    .https.onRequest(async (req, res) => {
        try {
            console.log('Received Basiq webhook:', req.body);

            // Verify webhook signature if needed (recommended for production)
            // const signature = req.headers['x-basiq-signature'];
            
            const { type, data } = req.body;

            switch (type) {
                case 'connection.created':
                    await handleConnectionCreated(data);
                    break;
                case 'connection.updated':
                    await handleConnectionUpdated(data);
                    break;
                case 'connection.failed':
                    await handleConnectionFailed(data);
                    break;
                default:
                    console.log('Unhandled webhook type:', type);
            }

            res.status(200).json({ success: true, message: 'Webhook processed' });
        } catch (error) {
            console.error('Error processing Basiq webhook:', error);
            res.status(500).json({ success: false, error: error.message });
        }
    });

// Handle connection created webhook
async function handleConnectionCreated(data) {
    console.log('Processing connection created:', data);
    
    try {
        // Find user by Basiq user ID
        const usersSnapshot = await admin.firestore()
            .collection('users')
            .where('basiqUserId', '==', data.userId)
            .get();

        if (usersSnapshot.empty) {
            console.log('No user found for Basiq user ID:', data.userId);
            return;
        }

        const userDoc = usersSnapshot.docs[0];
        await userDoc.ref.update({
            basiqConnectionId: data.id,
            basiqConnectionStatus: 'connected',
            sellerStatus: 'registered',
            lastBasiqUpdate: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log('Updated user connection status for:', userDoc.id);
    } catch (error) {
        console.error('Error handling connection created:', error);
    }
}

// Handle connection updated webhook
async function handleConnectionUpdated(data) {
    console.log('Processing connection updated:', data);
    
    try {
        const usersSnapshot = await admin.firestore()
            .collection('users')
            .where('basiqConnectionId', '==', data.id)
            .get();

        if (usersSnapshot.empty) {
            console.log('No user found for connection ID:', data.id);
            return;
        }

        const userDoc = usersSnapshot.docs[0];
        await userDoc.ref.update({
            basiqConnectionStatus: data.status,
            lastBasiqUpdate: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log('Updated connection status to:', data.status);
    } catch (error) {
        console.error('Error handling connection updated:', error);
    }
}

// Handle connection failed webhook
async function handleConnectionFailed(data) {
    console.log('Processing connection failed:', data);
    
    try {
        const usersSnapshot = await admin.firestore()
            .collection('users')
            .where('basiqUserId', '==', data.userId)
            .get();

        if (usersSnapshot.empty) {
            console.log('No user found for Basiq user ID:', data.userId);
            return;
        }

        const userDoc = usersSnapshot.docs[0];
        await userDoc.ref.update({
            basiqConnectionStatus: 'failed',
            basiqConnectionError: data.error || 'Unknown error',
            lastBasiqUpdate: admin.firestore.FieldValue.serverTimestamp()
        });

        console.log('Updated connection status to failed for:', userDoc.id);
    } catch (error) {
        console.error('Error handling connection failed:', error);
    }
}

// Cloud Function to get user's Basiq connection status
exports.getBasiqStatus = functions
    .region('australia-southeast1')
    .https.onCall(async (data, context) => {
        try {
            if (!context.auth) {
                throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
            }

            const userDoc = await admin.firestore()
                .collection('users')
                .doc(context.auth.uid)
                .get();

            if (!userDoc.exists) {
                throw new functions.https.HttpsError('not-found', 'User not found');
            }

            const userData = userDoc.data();
            
            return {
                success: true,
                basiqUserId: userData.basiqUserId || null,
                connectionStatus: userData.basiqConnectionStatus || 'not_connected',
                sellerStatus: userData.sellerStatus || 'not_registered',
                lastUpdate: userData.lastBasiqUpdate || null
            };

        } catch (error) {
            console.error('Error getting Basiq status:', error);
            
            if (error instanceof functions.https.HttpsError) {
                throw error;
            }
            
            throw new functions.https.HttpsError('internal', 
                `Failed to get Basiq status: ${error.message}`);
        }
    });