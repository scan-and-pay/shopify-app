const functions = require('firebase-functions');
const axios = require('axios');

// Global Payments Configuration
// Configure via Firebase CLI: firebase functions:config:set globalpayments.global_payments_master_key="YOUR_KEY"
const GLOBAL_PAYMENTS_CONFIG = {
  baseUrl: functions.config().globalpayments?.base_url || 'https://sandbox.api.gpaunz.com',
  masterKey: functions.config().globalpayments?.global_payments_master_key
};

// Cache for API key
let apiKeyCache = {
  key: null,
  expiry: null
};

/**
 * Get or create an API key
 * The API key is cached for 1 hour to reduce API calls
 */
async function getApiKey() {
  // Validate configuration
  if (!GLOBAL_PAYMENTS_CONFIG.masterKey) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Global Payments master key not configured. Run: firebase functions:config:set globalpayments.global_payments_master_key="YOUR_KEY"'
    );
  }

  // Check if cached key is still valid
  if (apiKeyCache.key && apiKeyCache.expiry && Date.now() < apiKeyCache.expiry) {
    return apiKeyCache.key;
  }

  try {
    const response = await axios.post(
      `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/apikeys`,
      {},
      {
        headers: {
          'Content-Type': 'application/json',
          'x-master-key': GLOBAL_PAYMENTS_CONFIG.masterKey
        }
      }
    );

    apiKeyCache.key = response.data.apiKey;
    // Cache for 1 hour
    apiKeyCache.expiry = Date.now() + (60 * 60 * 1000);

    console.log('GlobalPayments: Created new API key');
    return apiKeyCache.key;
  } catch (error) {
    console.error('GlobalPayments: Failed to create API key:', error.response?.data || error.message);
    throw new functions.https.HttpsError('internal', 'Failed to create API key');
  }
}

/**
 * Create a customer in Global Payments
 * This is the first step before creating payment instruments
 *
 * @callable
 */
exports.createGlobalPaymentsCustomer = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { name, email, reference } = data;

    if (!name || !email) {
      throw new functions.https.HttpsError('invalid-argument', 'Name and email are required');
    }

    try {
      const apiKey = await getApiKey();

      const response = await axios.post(
        `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/customers`,
        {
          name,
          email,
          reference: reference || context.auth.uid
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
          }
        }
      );

      console.log(`GlobalPayments: Customer created for user ${context.auth.uid}`);
      return response.data;
    } catch (error) {
      console.error('GlobalPayments: Failed to create customer:', error.response?.data || error.message);
      throw new functions.https.HttpsError('internal', 'Failed to create customer');
    }
  });

/**
 * Create a PayTo Payment Agreement (Direct Debit from BSB/Account)
 * This allows recurring payments from a bank account
 *
 * @callable
 */
exports.createPayToAgreement = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const {
      customerId,
      payerName,
      payerType,
      bsb,
      accountNumber,
      agreementType,
      frequency,
      startDate,
      description,
      reference,
      agreementDetails
    } = data;

    if (!customerId || !payerName || !payerType || !bsb || !accountNumber ||
        !agreementType || !frequency || !startDate || !description) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    try {
      const apiKey = await getApiKey();

      const paymentAgreementData = {
        payer: {
          name: payerName,
          type: payerType,
          account: {
            bsb,
            number: accountNumber
          }
        },
        agreementDetails: {
          paymentAgreementType: agreementType,
          frequency,
          establishmentType: 'authorised',
          startDate,
          description,
          currencyCode: 'AUD',
          ...agreementDetails
        }
      };

      const requestBody = {
        paymentAgreement: paymentAgreementData,
        reference: reference || `${context.auth.uid}_${Date.now()}`
      };

      const response = await axios.post(
        `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/customers/${customerId}/PaymentInstruments`,
        requestBody,
        {
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
          }
        }
      );

      console.log(`GlobalPayments: PayTo agreement created for user ${context.auth.uid}`);
      return response.data;
    } catch (error) {
      console.error('GlobalPayments: Failed to create PayTo agreement:', error.response?.data || error.message);
      throw new functions.https.HttpsError('internal', 'Failed to create PayTo agreement');
    }
  });

/**
 * Create a PayID Payment Instrument
 * This allows payments via PayID (email, phone, ABN, or ORG ID)
 *
 * @callable
 */
exports.createPayIdInstrument = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const {
      customerId,
      payerName,
      payerType,
      payIdType,
      payIdValue,
      agreementType,
      frequency,
      startDate,
      description,
      reference,
      agreementDetails
    } = data;

    if (!customerId || !payerName || !payerType || !payIdType || !payIdValue ||
        !agreementType || !frequency || !startDate || !description) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    try {
      const apiKey = await getApiKey();

      // Build PayID object based on type
      let payIdObject;
      switch (payIdType.toLowerCase()) {
        case 'email':
          payIdObject = { email: payIdValue };
          break;
        case 'phone':
          payIdObject = { phone: payIdValue };
          break;
        case 'abn':
          payIdObject = { abn: payIdValue };
          break;
        case 'org':
          payIdObject = { org: payIdValue };
          break;
        default:
          throw new functions.https.HttpsError('invalid-argument', `Invalid PayID type: ${payIdType}`);
      }

      const paymentAgreementData = {
        payer: {
          name: payerName,
          type: payerType,
          payId: payIdObject
        },
        agreementDetails: {
          paymentAgreementType: agreementType,
          frequency,
          establishmentType: 'authorised',
          startDate,
          description,
          currencyCode: 'AUD',
          ...agreementDetails
        }
      };

      const requestBody = {
        paymentAgreement: paymentAgreementData,
        reference: reference || `${context.auth.uid}_${Date.now()}`
      };

      const response = await axios.post(
        `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/customers/${customerId}/PaymentInstruments`,
        requestBody,
        {
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
          }
        }
      );

      console.log(`GlobalPayments: PayID instrument created for user ${context.auth.uid}`);
      return response.data;
    } catch (error) {
      console.error('GlobalPayments: Failed to create PayID instrument:', error.response?.data || error.message);
      throw new functions.https.HttpsError('internal', 'Failed to create PayID instrument');
    }
  });

/**
 * Process a payment using an existing payment instrument
 *
 * @callable
 */
exports.processGlobalPayment = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { paymentInstrumentId, amountInCents, reference, description } = data;

    if (!paymentInstrumentId || !amountInCents) {
      throw new functions.https.HttpsError('invalid-argument', 'Payment instrument ID and amount are required');
    }

    try {
      const apiKey = await getApiKey();

      const response = await axios.post(
        `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/payments`,
        {
          paymentInstrument: paymentInstrumentId,
          amount: amountInCents,
          currencyCode: 'AUD',
          reference: reference || `${context.auth.uid}_${Date.now()}`,
          description
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
          }
        }
      );

      console.log(`GlobalPayments: Payment processed for user ${context.auth.uid}`);
      return response.data;
    } catch (error) {
      console.error('GlobalPayments: Failed to process payment:', error.response?.data || error.message);
      throw new functions.https.HttpsError('internal', 'Failed to process payment');
    }
  });

/**
 * Get customer details
 *
 * @callable
 */
exports.getGlobalPaymentsCustomer = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { customerId } = data;

    if (!customerId) {
      throw new functions.https.HttpsError('invalid-argument', 'Customer ID is required');
    }

    try {
      const apiKey = await getApiKey();

      const response = await axios.get(
        `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/customers/${customerId}`,
        {
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
          }
        }
      );

      return response.data;
    } catch (error) {
      console.error('GlobalPayments: Failed to get customer:', error.response?.data || error.message);
      throw new functions.https.HttpsError('internal', 'Failed to get customer');
    }
  });

/**
 * Get payment instrument details
 *
 * @callable
 */
exports.getGlobalPaymentInstrument = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { customerId, instrumentId } = data;

    if (!customerId || !instrumentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Customer ID and instrument ID are required');
    }

    try {
      const apiKey = await getApiKey();

      const response = await axios.get(
        `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/customers/${customerId}/PaymentInstruments/${instrumentId}`,
        {
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
          }
        }
      );

      return response.data;
    } catch (error) {
      console.error('GlobalPayments: Failed to get payment instrument:', error.response?.data || error.message);
      throw new functions.https.HttpsError('internal', 'Failed to get payment instrument');
    }
  });

/**
 * Cancel payment agreement
 *
 * @callable
 */
exports.cancelGlobalPaymentAgreement = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { customerId, instrumentId } = data;

    if (!customerId || !instrumentId) {
      throw new functions.https.HttpsError('invalid-argument', 'Customer ID and instrument ID are required');
    }

    try {
      const apiKey = await getApiKey();

      await axios.delete(
        `${GLOBAL_PAYMENTS_CONFIG.baseUrl}/customers/${customerId}/PaymentInstruments/${instrumentId}`,
        {
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey
          }
        }
      );

      console.log(`GlobalPayments: Payment agreement cancelled for user ${context.auth.uid}`);
      return { success: true };
    } catch (error) {
      console.error('GlobalPayments: Failed to cancel payment agreement:', error.response?.data || error.message);
      throw new functions.https.HttpsError('internal', 'Failed to cancel payment agreement');
    }
  });

/**
 * Health check for Global Payments API
 *
 * @callable
 */
exports.checkGlobalPaymentsHealth = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    try {
      // Try to get an API key to verify configuration
      const apiKey = await getApiKey();

      return {
        healthy: true,
        configured: true,
        apiUrl: GLOBAL_PAYMENTS_CONFIG.baseUrl,
        region: 'australia-southeast1',
        timestamp: new Date().toISOString(),
        message: 'Global Payments API is configured and ready',
        hasApiKey: !!apiKey
      };
    } catch (error) {
      console.error("Error checking API health:", error);
      return {
        healthy: false,
        configured: false,
        error: error.message,
        timestamp: new Date().toISOString(),
        message: 'Failed to connect to Global Payments API'
      };
    }
  });
