const functions = require('firebase-functions');
const admin = require('firebase-admin');

  // The admin SDK is initialized by the managed environment.
  const db = admin.firestore();

exports.sendOtp = functions
  .region('australia-southeast1')
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .https.onCall(async (data, context) => {
      const email = data.email;

  // --- 1. Input Validation (Security) ---
  if (!email) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      "Invalid request. The 'email' field is required."
    );
  }

  // Allow unauthenticated requests for OTP (user is not logged in yet)
  // Security is enforced through rate limiting and email verification

  // Build Firestore ref for this email
  const emailLower = String(email).trim().toLowerCase();
  const otpRef = db.collection('sendOtpEmail').doc(emailLower);
  const cooldownSeconds = 60;

  // Apply global cooldown: blocks ANY request if another was made within cooldown
  await enforceEmailCooldown(emailLower, cooldownSeconds);

  // --- Modified Global Email Cooldown Function ---
  // This blocks ANY email request for 60 seconds after ANY previous request
async function enforceEmailCooldown(emailLower, cooldownSeconds) {
    const now = Date.now();
    const cooldownMs = cooldownSeconds * 1000;

    // Query for ANY OTP requests within the cooldown period
    const recentOtpsQuery = db.collection('sendOtpEmail')
      .where('createdAt', '>', admin.firestore.Timestamp.fromMillis(now - cooldownMs))
      .orderBy('createdAt', 'desc')
      .limit(1);

    const recentOtpsSnapshot = await recentOtpsQuery.get();

    if (!recentOtpsSnapshot.empty) {
      // Found a recent OTP request (to ANY email)
      const mostRecentDoc = recentOtpsSnapshot.docs[0];
      const mostRecentData = mostRecentDoc.data();
      const createdMs = mostRecentData.createdAt.toMillis();

      const timeSinceLastRequest = now - createdMs;
      const remaining = cooldownMs - timeSinceLastRequest;

      if (remaining > 0) {
        throw new functions.https.HttpsError(
          'resource-exhausted',
          `Please wait ${Math.ceil(remaining / 1000)} seconds before requesting another verification code.`
        );
      }
    }

    // No recent requests found - allow the request
    return;
  }

  // --- 2. OTP Generation & Persistence ---
  // Generate a secure 6-digit OTP (avoid Math.random)
  const crypto = require('crypto');
  const raw = crypto.randomBytes(3).readUIntBE(0, 3); // 0..16,777,215
  const otp = String(raw % 1000000).padStart(6, '0');
  const ttlMinutes = 1; // The OTP will be valid for 1 minute
  const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);


      try {
        // Store the OTP in Firestore for later verification
        await otpRef.set({
          otp: otp,
          createdAt: admin.firestore.FieldValue.serverTimestamp(), // use server time
          expiresAt: expiresAt,
          verified: false,
        });

        // --- 3. Email Dispatch via Mailgun ---
        const config = functions.config();
        const apiKey = config.mailgun.key;
        const domain = config.mailgun.domain;

        const fetch = (await import('node-fetch')).default;
        const response = await fetch(`https://api.mailgun.net/v3/${domain}/messages`, {
          method: 'POST',
          headers: {
            'Authorization': 'Basic ' + Buffer.from(`api:${apiKey}`).toString('base64'),
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({
            from: `Scan & Pay <noreply@scanandpay.com.au>`,
            to: email,
            subject: `Your Scan & Pay Verification Code`,
            text: `Your verification code is: ${otp}\n\nThis code will expire in ${ttlMinutes} minutes.`,
            html:
              `<div style="font-family:Arial,sans-serif;font-size:16px;line-height:1.5">
              <p>Your verification code is:<strong> ${otp}</strong></p>
              <p>This code will expire in ${ttlMinutes} minute${ttlMinutes === 1 ? '' : 's'}.</p>
              </div>`
          }),
        });

        if (!response.ok) {
          const errorBody = await response.text();
          console.error('Mailgun API Error:', errorBody);
          throw new functions.https.HttpsError('internal', 'Failed to send email.');
        }

        const result = await response.json();
        return {
          success: true,
          message: `OTP successfully sent to ${email}.`,
          email: email
        };

        } catch (error) {
          console.error('Function execution error:', error);
          return {
            success: false,
            message: error.message || 'An unexpected error occurred.',
            email: email || null
          };
        }
  });
