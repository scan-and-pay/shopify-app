const admin = require("firebase-admin");


// Initialize Firebase Admin only if not already initialized
admin.initializeApp();

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