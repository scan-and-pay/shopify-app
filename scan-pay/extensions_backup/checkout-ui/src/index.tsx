
import {
  reactExtension,
  useApi,
  useCheckout,
  BlockStack,
  Button,
  Heading,
  Text,
  Banner,
  View,
} from '@shopify/ui-extensions-react/checkout';
import React, { useState, useEffect, useCallback, useMemo } from 'react';
import { generateQrCodeMatrix } from './qr-code';

const QrCode = ({ value }: { value: string }) => {
  const matrix = useMemo(() => generateQrCodeMatrix(value), [value]);

  const moduleSize = 4;
  const quietZone = 4;
  const quietZonePixels = quietZone * moduleSize;
  const numModules = matrix.length;
  const qrCodeSize = numModules * moduleSize;
  const totalSize = qrCodeSize + 2 * quietZonePixels;

  const svgPaths = useMemo(() => {
    let path = '';
    matrix.forEach((row, r) => {
      row.forEach((isDark, c) => {
        if (isDark) {
          const x = quietZonePixels + c * moduleSize;
          const y = quietZonePixels + r * moduleSize;
          path += `M${x},${y}h${moduleSize}v${moduleSize}h-${moduleSize}z`;
        }
      });
    });
    return path;
  }, [matrix, moduleSize, quietZonePixels]);

  const svg = `
    <svg width="${totalSize}" height="${totalSize}" viewBox="0 0 ${totalSize} ${totalSize}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${totalSize}" height="${totalSize}" fill="white"/>
      <path d="${svgPaths}" fill="black"/>
    </svg>
  `;

  const dataUrl = `data:image/svg+xml;base64,${btoa(svg)}`;

  return <Image source={dataUrl} />;
};


export default reactExtension(
  'purchase.checkout.block.render',
  () => <Extension />,
);

function Extension() {
  const { cost, currency } = useCheckout();
  const api = useApi();

  const [paymentStatus, setPaymentStatus] = useState('UNPAID'); // UNPAID, PENDING, PAID, ERROR
  const [reference, setReference] = useState('');
  const [showQr, setShowQr] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [polling, setPolling] = useState(false);

  const BACKEND_URL = 'https://scanandpay-backend.example.com/api/payid/verify';

  const generateReference = () => {
    const timestamp = Date.now();
    return `SCANPAY-${timestamp}`;
  };

  const handlePayClick = () => {
    const newReference = generateReference();
    setReference(newReference);
    setShowQr(true);
  };

  const verifyPayment = useCallback(async () => {
    if (polling || paymentStatus === 'PAID') return;

    setPolling(true);
    setPaymentStatus('PENDING');
    setErrorMessage('');

    try {
      const response = await fetch(BACKEND_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          amount: cost.totalAmount.current.amount,
          currency: currency.isoCode,
          reference: reference,
        }),
      });

      const result = await response.json();

      if (response.ok) {
        setPaymentStatus(result.status);
        if (result.status === 'UNPAID') {
          setErrorMessage(result.message || 'Payment not yet received.');
        }
      } else {
        setPaymentStatus('ERROR');
        setErrorMessage(result.message || 'An error occurred during verification.');
      }
    } catch (error) {
      setPaymentStatus('ERROR');
      setErrorMessage('Network error. Please try again.');
    } finally {
      setPolling(false);
    }
  }, [reference, cost.totalAmount.current.amount, currency.isoCode, polling, paymentStatus]);


  useEffect(() => {
    if (paymentStatus === 'PENDING' && !polling) {
      const interval = setInterval(() => {
        verifyPayment();
      }, 5000); // Poll every 5 seconds

      return () => clearInterval(interval);
    }
  }, [paymentStatus, polling, verifyPayment]);
  
  useEffect(() => {
    if (paymentStatus === 'PAID') {
      api.checkout.complete();
    }
  }, [paymentStatus, api]);


  const renderStatusBanner = () => {
    switch (paymentStatus) {
      case 'PAID':
        return <Banner status="success">Payment successful! Completing checkout...</Banner>;
      case 'PENDING':
        return <Banner status="info">Verifying payment... Please wait.</Banner>;
      case 'ERROR':
        return <Banner status="critical">{errorMessage}</Banner>;
      case 'UNPAID':
        if(errorMessage) return <Banner status="warning">{errorMessage}</Banner>;
        return null;
      default:
        return null;
    }
  };
  
  if (paymentStatus === 'PAID') {
    return (
      <BlockStack>
        {renderStatusBanner()}
      </BlockStack>
    )
  }

  if (showQr) {
    const payIdValue = `payid:your-pay-id?amount=${cost.totalAmount.current.amount}&ref=${reference}`;
    return (
      <BlockStack spacing="md">
        <Heading>Pay with PayID</Heading>
        {renderStatusBanner()}
        <View>
            <QrCode value={payIdValue} />
        </View>
        <BlockStack>
            <Text>Amount: {cost.totalAmount.current.amount} {currency.isoCode}</Text>
            <Text>Reference: {reference}</Text>
        </BlockStack>

        <Button onPress={verifyPayment} loading={polling}>
          I've paid - Check status
        </Button>
      </BlockStack>
    );
  }

  return (
    <BlockStack spacing="md">
      <Heading>Pay with PayID via Scan & Pay</Heading>
      <Button onPress={handlePayClick} >
        Pay with PayID
      </Button>
    </BlockStack>
  );
}
