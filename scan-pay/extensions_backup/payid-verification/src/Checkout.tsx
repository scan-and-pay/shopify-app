import {
  reactExtension,
  Banner,
  BlockStack,
  Button,
  Divider,
  Heading,
  Image,
  InlineLayout,
  InlineStack,
  Text,
  View,
  useApi,
  useCartLines,
  useShippingAddress,
  useBuyerJourneyIntercept,
  useApplyAttributeChange,
  useSettings,
} from '@shopify/ui-extensions-react/checkout';
import { useState, useCallback } from 'react';

// Type for merchant settings
interface MerchantSettings {
  merchant_payid?: string;
  merchant_name?: string;
  firebase_project_id?: string;
  enable_manual_entry?: boolean;
}

export default reactExtension(
  'purchase.checkout.block.render',
  () => <Extension />,
);

function Extension() {
  const { query } = useApi();
  const cartLines = useCartLines();
  const shippingAddress = useShippingAddress();
  const applyAttributeChange = useApplyAttributeChange();

  // Merchant settings from extension configuration
  const settings = useSettings() as MerchantSettings;
  const merchantPayId = settings.merchant_payid || 'payments@scanandpay.com.au';
  const merchantName = settings.merchant_name || 'Scan & Pay';
  const firebaseProjectId = settings.firebase_project_id || 'scan-and-pay-guihzm';
  const enableManualEntry = settings.enable_manual_entry !== false;

  // Firebase/Backend Configuration
  const FIREBASE_FUNCTION_URL = `https://australia-southeast1-${firebaseProjectId}.cloudfunctions.net`;
  const GENERATE_QR_URL = `${FIREBASE_FUNCTION_URL}/generatePayIDQR`;
  const VERIFY_PAYMENT_URL = `${FIREBASE_FUNCTION_URL}/verifyPayment`;
  const CHECK_STATUS_URL = `${FIREBASE_FUNCTION_URL}/checkPayIDStatus`;

  // Payment state
  const [paymentReference, setPaymentReference] = useState('');
  const [qrCodeDataUrl, setQrCodeDataUrl] = useState('');
  const [paymentStatus, setPaymentStatus] = useState('idle'); // idle, pending, paid, failed
  const [showPaymentUI, setShowPaymentUI] = useState(false);
  const [verificationAttempts, setVerificationAttempts] = useState(0);
  const [errorMessage, setErrorMessage] = useState('');

  // Calculate cart total
  const cartTotal = cartLines.reduce((total, line) => {
    return total + (parseFloat(line.cost.totalAmount.amount) || 0);
  }, 0);

  // Generate cryptographically secure payment reference
  const generatePaymentReference = useCallback(() => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const length = 12;
    let reference = 'REF-2024-';

    // Use crypto for secure random generation
    const array = new Uint8Array(length);
    crypto.getRandomValues(array);

    for (let i = 0; i < length; i++) {
      reference += chars[array[i] % chars.length];
    }

    return reference;
  }, []);

  // Generate NPP-compliant QR code via backend
  const generateQRCode = useCallback(async (payId, amount, reference, merchantName = 'Scan & Pay') => {
    try {
      // Call Firebase Cloud Function to generate NPP-compliant QR code
      const response = await fetch(GENERATE_QR_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          payId: payId,
          amount: amount,
          reference: reference,
          merchantName: merchantName,
        }),
      });

      if (!response.ok) {
        throw new Error(`QR generation failed: ${response.statusText}`);
      }

      const result = await response.json();

      // Backend returns QR code as data URL or base64 image
      if (result.qrCodeDataUrl) {
        setQrCodeDataUrl(result.qrCodeDataUrl);
      } else if (result.qrData) {
        // Fallback to displaying QR data as text if image not available
        setQrCodeDataUrl(result.qrData);
      }
    } catch (error) {
      console.error('QR code generation failed:', error);
      setErrorMessage('Failed to generate QR code. Please try again.');
    }
  }, []);

  // Initialize payment
  const initializePayment = useCallback(async () => {
    const reference = generatePaymentReference();
    setPaymentReference(reference);

    await generateQRCode(merchantPayId, cartTotal, reference, merchantName);

    // Store payment reference in checkout attributes
    await applyAttributeChange({
      type: 'updateAttribute',
      key: 'payid_reference',
      value: reference,
    });

    setShowPaymentUI(true);
  }, [cartTotal, merchantPayId, merchantName, generatePaymentReference, generateQRCode, applyAttributeChange]);

  // Verify payment with backend (using Global Payments webhook system)
  const verifyPayment = useCallback(async () => {
    if (!paymentReference) return;

    try {
      setPaymentStatus('pending');
      setVerificationAttempts(prev => prev + 1);

      // Call verifyPayment endpoint (Terminal 4 API)
      // This queries Global Payments transaction records from webhook data
      const params = new URLSearchParams({
        reference: paymentReference,
        amount: Math.round(cartTotal * 100).toString(), // Convert to cents
        payId: merchantPayId,
      });

      const response = await fetch(`${VERIFY_PAYMENT_URL}?${params.toString()}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        throw new Error(`Verification failed: ${response.statusText}`);
      }

      const result = await response.json();

      // Backend returns: { status: 'paid' | 'unpaid' | 'pending', transactionId?, amount?, verified? }
      if (result.status === 'paid' && result.verified) {
        // Payment confirmed via Global Payments webhook
        setPaymentStatus('paid');

        // Store transaction details in checkout attributes
        await applyAttributeChange({
          type: 'updateAttribute',
          key: 'payid_transaction_id',
          value: result.transactionId || paymentReference,
        });

        await applyAttributeChange({
          type: 'updateAttribute',
          key: 'payid_status',
          value: 'paid',
        });

        await applyAttributeChange({
          type: 'updateAttribute',
          key: 'payid_amount_cents',
          value: result.amount?.toString() || Math.round(cartTotal * 100).toString(),
        });

        setErrorMessage('');
      } else if (result.status === 'pending' || result.status === 'unpaid') {
        // Payment not yet received - continue polling
        setPaymentStatus('pending');

        // Poll again after 3 seconds (max 40 attempts = 2 minutes)
        if (verificationAttempts < 40) {
          setTimeout(() => verifyPayment(), 3000);
        } else {
          setPaymentStatus('failed');
          setErrorMessage('Payment verification timeout. Please contact support if you completed the payment.');
        }
      } else {
        // Payment declined or error
        setPaymentStatus('failed');
        setErrorMessage(result.message || 'Payment not received. Please complete the payment and try again.');
      }
    } catch (error) {
      console.error('Payment verification error:', error);
      setPaymentStatus('failed');
      setErrorMessage('Verification error. Please try again or contact support.');
    }
  }, [paymentReference, cartTotal, merchantPayId, verificationAttempts, applyAttributeChange, VERIFY_PAYMENT_URL]);

  // Intercept buyer journey to validate payment
  useBuyerJourneyIntercept(({ canBlockProgress }) => {
    if (!showPaymentUI) {
      // PayID not initiated, allow normal checkout
      return {
        behavior: 'allow',
      };
    }

    if (paymentStatus === 'paid') {
      // Payment verified, allow order completion
      return {
        behavior: 'allow',
      };
    }

    if (canBlockProgress && paymentStatus !== 'paid') {
      // Block checkout until payment is verified
      return {
        behavior: 'block',
        reason: 'Please complete PayID payment and verify before continuing.',
        errors: [
          {
            message: 'Payment verification required',
            target: '$.cart',
          },
        ],
      };
    }

    return {
      behavior: 'allow',
    };
  });

  // Render payment status indicator
  const renderPaymentStatus = () => {
    if (paymentStatus === 'paid') {
      return (
        <Banner status="success">
          Payment Confirmed! Your order is being processed.
        </Banner>
      );
    }

    if (paymentStatus === 'pending') {
      return (
        <Banner status="warning">
          Verifying payment... Please wait.
        </Banner>
      );
    }

    if (paymentStatus === 'failed' && errorMessage) {
      return (
        <Banner status="critical">
          {errorMessage}
        </Banner>
      );
    }

    return null;
  };

  if (!showPaymentUI) {
    // Initial state - show PayID option
    return (
      <BlockStack spacing="base">
        <Divider />
        <Heading level={2}>Pay with PayID</Heading>
        <Text>Scan QR code and pay instantly with your bank app</Text>

        <BlockStack spacing="tight">
          <InlineStack>
            <Text appearance="subdued">Total Amount:</Text>
            <Text emphasis="bold">${cartTotal.toFixed(2)} AUD</Text>
          </InlineStack>
        </BlockStack>

        <Button kind="primary" onPress={initializePayment}>
          Pay with PayID QR Code
        </Button>

        <Text size="small" appearance="subdued">
          Secure payment powered by Global Payments Oceania
        </Text>
      </BlockStack>
    );
  }

  // Payment UI active
  return (
    <BlockStack spacing="base">
      <Divider />

      {renderPaymentStatus()}

      <Heading level={2}>PayID Payment</Heading>

      {/* Payment Details */}
      <View border="base" padding="base" cornerRadius="base">
        <BlockStack spacing="tight">
          <InlineStack>
            <Text appearance="subdued">Amount:</Text>
            <Text emphasis="bold" size="large">
              ${cartTotal.toFixed(2)} AUD
            </Text>
          </InlineStack>

          <Divider />

          <BlockStack spacing="extraTight">
            <Text size="small" appearance="subdued">PayID:</Text>
            <Text emphasis="bold">{merchantPayId}</Text>
          </BlockStack>

          <Divider />

          <BlockStack spacing="extraTight">
            <Text size="small" appearance="subdued">Payment Reference:</Text>
            <Text emphasis="bold">{paymentReference}</Text>
          </BlockStack>
        </BlockStack>
      </View>

      {/* QR Code */}
      {qrCodeDataUrl && (
        <View padding="base">
          <BlockStack spacing="tight">
            <Text emphasis="bold">Scan QR Code:</Text>
            <Image source={qrCodeDataUrl} />
          </BlockStack>
        </View>
      )}

      {/* Instructions */}
      <View border="base" padding="base" cornerRadius="base">
        <BlockStack spacing="tight">
          <Text emphasis="bold">How to Pay:</Text>
          <BlockStack spacing="extraTight">
            <Text size="small">1. Open your banking app</Text>
            <Text size="small">2. Select PayID or Pay Anyone</Text>
            <Text size="small">3. Scan the QR code OR enter details manually</Text>
            <Text size="small">4. Confirm the payment in your bank</Text>
            <Text size="small">5. Click "I've Paid" button below</Text>
          </BlockStack>
        </BlockStack>
      </View>

      {/* Manual Entry Option */}
      {enableManualEntry && (
        <View border="base" padding="base" cornerRadius="base">
          <BlockStack spacing="tight">
            <Text emphasis="bold">Manual Entry:</Text>
            <Text size="small">
              If you can't scan the QR code, enter these details in your banking app:
            </Text>
            <BlockStack spacing="extraTight">
              <Text size="small">PayID: {merchantPayId}</Text>
              <Text size="small">Amount: ${cartTotal.toFixed(2)}</Text>
              <Text size="small">Reference: {paymentReference}</Text>
            </BlockStack>
          </BlockStack>
        </View>
      )}

      {/* Verification Button */}
      {paymentStatus !== 'paid' && (
        <Button
          kind="primary"
          onPress={verifyPayment}
          loading={paymentStatus === 'pending'}
        >
          {paymentStatus === 'pending' ? 'Verifying...' : "I've Paid - Verify Now"}
        </Button>
      )}

      {paymentStatus === 'paid' && (
        <Banner status="success">
          Payment verified! You can now complete your order.
        </Banner>
      )}

      {/* Cancel Option */}
      {paymentStatus !== 'paid' && paymentStatus !== 'pending' && (
        <Button onPress={() => setShowPaymentUI(false)}>
          Cancel PayID Payment
        </Button>
      )}
    </BlockStack>
  );
}
