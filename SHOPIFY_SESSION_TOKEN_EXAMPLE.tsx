// Example React Component: Using Session Tokens with App Bridge
// Location: Put this in your React frontend (merchants.scanandpay.com.au)

import { useEffect, useState } from 'react';
import { useAppBridge } from '@shopify/app-bridge-react';

// Your Firebase Cloud Function URL
const FIREBASE_API_URL = 'https://us-central1-scan-and-pay-guihzm.cloudfunctions.net';

export function MerchantDashboard() {
  const app = useAppBridge(); // Get App Bridge instance
  const [sessionToken, setSessionToken] = useState<string | null>(null);
  const [merchantData, setMerchantData] = useState(null);
  const [loading, setLoading] = useState(false);

  // Get session token on mount (this triggers Shopify's check)
  useEffect(() => {
    async function fetchSessionToken() {
      try {
        // CRITICAL: This retrieves the JWT session token
        const token = await app.idToken();
        setSessionToken(token);
        console.log('✅ Session token retrieved');
      } catch (error) {
        console.error('❌ Failed to get session token:', error);
      }
    }

    fetchSessionToken();
  }, [app]);

  // Example API call using session token
  async function callFirebaseFunction() {
    if (!sessionToken) {
      alert('No session token available');
      return;
    }

    setLoading(true);
    try {
      // CRITICAL: Send session token in Authorization header
      const response = await fetch(`${FIREBASE_API_URL}/getMerchantData`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${sessionToken}`, // Session token here!
        },
        body: JSON.stringify({
          action: 'get_merchant_profile',
        }),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      setMerchantData(data);
      console.log('✅ API call successful with session token');
    } catch (error) {
      console.error('❌ API call failed:', error);
      alert('Failed to fetch merchant data');
    } finally {
      setLoading(false);
    }
  }

  // Example: Generate PayID QR Code (triggers backend with session token)
  async function generatePayIDQR() {
    if (!sessionToken) {
      alert('No session token available');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch(`${FIREBASE_API_URL}/generatePayIDQR`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${sessionToken}`,
        },
        body: JSON.stringify({
          amount: 100.00,
          currency: 'AUD',
          description: 'Test Payment',
        }),
      });

      const data = await response.json();
      console.log('✅ PayID QR generated with session token auth');
      alert(`QR Code generated: ${data.qrCodeUrl}`);
    } catch (error) {
      console.error('❌ Failed to generate QR:', error);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ padding: '20px' }}>
      <h1>Merchant Dashboard</h1>

      {/* Session Token Status */}
      <div style={{ marginBottom: '20px', padding: '10px', background: sessionToken ? '#d4edda' : '#f8d7da' }}>
        {sessionToken ? (
          <>
            <strong>✅ Session Token Active</strong>
            <p style={{ fontSize: '12px', wordBreak: 'break-all' }}>
              Token: {sessionToken.substring(0, 50)}...
            </p>
          </>
        ) : (
          <strong>⏳ Fetching session token...</strong>
        )}
      </div>

      {/* Action Buttons */}
      <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
        <button
          onClick={callFirebaseFunction}
          disabled={!sessionToken || loading}
          style={{ padding: '10px 20px', cursor: 'pointer' }}
        >
          {loading ? 'Loading...' : 'Fetch Merchant Data'}
        </button>

        <button
          onClick={generatePayIDQR}
          disabled={!sessionToken || loading}
          style={{ padding: '10px 20px', cursor: 'pointer' }}
        >
          {loading ? 'Loading...' : 'Generate PayID QR'}
        </button>
      </div>

      {/* Display Merchant Data */}
      {merchantData && (
        <div style={{ marginTop: '20px', padding: '15px', background: '#f0f0f0' }}>
          <h3>Merchant Data:</h3>
          <pre>{JSON.stringify(merchantData, null, 2)}</pre>
        </div>
      )}
    </div>
  );
}

// Alternative: Plain JavaScript (no React)
export async function callFirebaseWithSessionToken() {
  // Get App Bridge instance
  const app = window.shopifyApp;

  if (!app) {
    console.error('❌ App Bridge not initialized');
    return;
  }

  try {
    // Get session token
    const token = await app.idToken();
    console.log('✅ Got session token');

    // Make API call
    const response = await fetch(
      'https://us-central1-scan-and-pay-guihzm.cloudfunctions.net/generatePayIDQR',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`, // Session token
        },
        body: JSON.stringify({ amount: 50, currency: 'AUD' }),
      }
    );

    const data = await response.json();
    console.log('✅ Response:', data);
    return data;
  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  }
}
