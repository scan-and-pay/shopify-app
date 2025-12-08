const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

exports.verifyOtp = functions
  .region('australia-southeast1')
  .runWith({ timeoutSeconds: 60, memory: '256MB' })
  .https.onCall(async (data, context) => {
    const email = data.email;
    const otp = data.otp;

    // --- 1. Input Validation ---
    if (!email || !otp) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        "Invalid request. Both 'email' and 'otp' fields are required."
      );
    }

    // Normalize email
    const emailLower = String(email).trim().toLowerCase();

    // Validate OTP format (6 digits)
    if (!/^\d{6}$/.test(otp)) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid OTP format. Must be 6 digits.'
      );
    }

    try {
      // --- 2. Retrieve OTP from Firestore ---
      const otpRef = db.collection('sendOtpEmail').doc(emailLower);
      const otpDoc = await otpRef.get();

      if (!otpDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'No OTP found for this email. Please request a new code.'
        );
      }

      const otpData = otpDoc.data();

      // --- 3. Check if already verified ---
      if (otpData.verified) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'This OTP has already been used. Please request a new code.'
        );
      }

      // --- 4. Check if OTP has expired ---
      const now = new Date();
      const expiresAt = otpData.expiresAt.toDate();

      if (now > expiresAt) {
        // Delete expired OTP
        await otpRef.delete();
        throw new functions.https.HttpsError(
          'deadline-exceeded',
          'OTP has expired. Please request a new code.'
        );
      }

      // --- 5. Verify OTP ---
      if (otpData.otp !== otp) {
        throw new functions.https.HttpsError(
          'permission-denied',
          'Invalid OTP code. Please check and try again.'
        );
      }

      // --- 6. Mark OTP as verified ---
      await otpRef.update({
        verified: true,
        verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // --- 7. Create or get existing user ---
      let uid;
      try {
        // Try to get existing user by email
        const userRecord = await admin.auth().getUserByEmail(emailLower);
        uid = userRecord.uid;
      } catch (error) {
        // User doesn't exist, create new user
        const newUser = await admin.auth().createUser({
          email: emailLower,
          emailVerified: true, // Email is verified through OTP
        });
        uid = newUser.uid;
      }

      // --- 8. Create custom token for sign-in ---
      const customToken = await admin.auth().createCustomToken(uid);

      // --- 9. Clean up OTP document (optional - or keep for audit trail) ---
      // Delete after successful verification
      await otpRef.delete();

      return {
        success: true,
        customToken: customToken,
        email: emailLower,
        message: 'Email verified successfully',
      };
    } catch (error) {
      // Re-throw HttpsErrors
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      // Log unexpected errors
      console.error('Error verifying OTP:', error);
      throw new functions.https.HttpsError(
        'internal',
        'An error occurred while verifying the OTP code.'
      );
    }
  });
