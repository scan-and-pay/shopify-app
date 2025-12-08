import {
  Button,
  Divider,
  Heading,
  Stack,
  Text,
  extend,
} from '@shopify/ui-extensions/checkout';

extend('purchase.checkout.block.render', (root, api) => {
  const total =
    api?.cost?.totalAmount?.current ?? api?.cost?.totalAmount ?? undefined;
  const amount = typeof total?.amount === 'number' ? total.amount : 0;
  const currency = total?.currencyCode ?? 'USD';
  const reference = `SCANPAY-${Date.now()}`;

  const verifyPayment = async () => {
    try {
      const response = await fetch('https://example.com/api/payid/verify', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({amount, currency, reference}),
      });

      const payload = await response.json();
      const status = payload?.status ?? 'UNKNOWN';

      if (status === 'PAID') {
        const complete =
          api?.checkout?.complete ??
          (typeof shopify !== 'undefined' ? shopify?.checkout?.complete : null);
        if (typeof complete === 'function') {
          await complete();
        }
        showToast(api, 'Payment confirmed. Completing checkout…', 'success');
      } else {
        showToast(api, `Payment status: ${status}`, 'info');
      }
    } catch (error) {
      console.error('PayID verification failed', error);
      showToast(
        api,
        'Unable to verify PayID payment right now. Please try again.',
        'critical',
      );
    }
  };

  const layout = root.createComponent(
    Stack,
    {gap: 'base', padding: 'base', background: 'subdued'},
    [
      root.createComponent(Heading, undefined, 'Pay with PayID'),
      root.createComponent(
        Text,
        undefined,
        'Pay the total with PayID, then verify to complete your checkout.',
      ),
      root.createComponent(Stack, {gap: 'extraTight'}, [
        root.createComponent(
          Text,
          undefined,
          `Amount: ${amount.toFixed(2)} ${currency}`,
        ),
        root.createComponent(Text, undefined, `Reference: ${reference}`),
      ]),
      root.createComponent(Divider),
      root.createComponent(
        Button,
        {kind: 'primary', onPress: verifyPayment},
        'Verify PayID payment',
      ),
    ],
  );

  root.appendChild(layout);
});

function showToast(api, message, tone = 'info') {
  // Toast API availability can vary by surface/version.
  api?.ui?.toast?.show?.(message, {tone});
}
