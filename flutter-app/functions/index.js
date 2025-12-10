const admin = require("firebase-admin");
const { defineSecret } = require("firebase-functions/params");

// Define secrets - These will be automatically injected from Google Secret Manager
const FIREBASE_PROJECT_ID = defineSecret("FIREBASE_PROJECT_ID");
const FIREBASE_API_KEY = defineSecret("FIREBASE_API_KEY");
const FIREBASE_STORAGE_BUCKET = defineSecret("FIREBASE_STORAGE_BUCKET");
const GLOBALPAYMENTS_MASTER_KEY = defineSecret("GLOBALPAYMENTS_MASTER_KEY");
const GLOBALPAYMENTS_BASE_URL = defineSecret("GLOBALPAYMENTS_BASE_URL");
const MAILGUN_API_KEY = defineSecret("MAILGUN_API_KEY");
const MAILGUN_DOMAIN = defineSecret("MAILGUN_DOMAIN");
const BASIQ_API_KEY = defineSecret("BASIQ_API_KEY");
const ENCRYPTION_KEY = defineSecret("ENCRYPTION_KEY");
const SHOPIFY_API_SECRET = defineSecret("SHOPIFY_API_SECRET");

// Initialize Firebase Admin only if not already initialized
admin.initializeApp();

// Export OTP functions (already properly configured with secrets)
const sendOtp = require('./send_otp_email.js');
exports.sendOtp = sendOtp.sendOtp;

const verifyOtp = require('./verify_otp_email.js');
exports.verifyOtp = verifyOtp.verifyOtp;

// TEMPORARILY DISABLED: Basiq API functions (waiting for CDR compliance)
// Will be re-enabled once regulatory requirements are met
// const basiqApi = require('./basiq_api.js');
// exports.createBasiqConnect = basiqApi.createBasiqConnect;
// exports.handleBasiqWebhook = basiqApi.handleBasiqWebhook;
// exports.getBasiqStatus = basiqApi.getBasiqStatus;

// Export PayID QR functions
const payidQr = require('./payid_qr.js');
exports.generatePayIDQR = payidQr.generatePayIDQR;
exports.checkPayIDStatus = payidQr.checkPayIDStatus;

// Export Global Payments API functions (Active payment provider)
const globalPaymentsApi = require('./global_payments_api.js');
exports.createGlobalPaymentsCustomer = globalPaymentsApi.createGlobalPaymentsCustomer;
exports.createPayToAgreement = globalPaymentsApi.createPayToAgreement;
exports.createPayIdInstrument = globalPaymentsApi.createPayIdInstrument;
exports.processGlobalPayment = globalPaymentsApi.processGlobalPayment;
exports.getGlobalPaymentsCustomer = globalPaymentsApi.getGlobalPaymentsCustomer;
exports.getGlobalPaymentInstrument = globalPaymentsApi.getGlobalPaymentInstrument;
exports.cancelGlobalPaymentAgreement = globalPaymentsApi.cancelGlobalPaymentAgreement;
exports.checkGlobalPaymentsHealth = globalPaymentsApi.checkGlobalPaymentsHealth;

// Export User Account Management functions
const deleteUserAccount = require('./delete_user_account.js');
exports.deleteUserAccount = deleteUserAccount.deleteUserAccount;

// Export Shopify Webhook handlers
const shopifyWebhooks = require('./shopify_webhooks');
exports.appUninstalled = shopifyWebhooks.appUninstalled;
exports.customersDataRequest = shopifyWebhooks.customersDataRequest;
exports.customersRedact = shopifyWebhooks.customersRedact;
exports.shopRedact = shopifyWebhooks.shopRedact;

// Export Shopify Session Token Auth functions (for embedded app)
const shopifySessionToken = require('./shopify_session_token');
exports.getMerchantData = shopifySessionToken.getMerchantData;
exports.generatePayIDQRWithAuth = shopifySessionToken.generatePayIDQRWithAuth;
