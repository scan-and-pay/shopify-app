const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");

/**
 * Cloud Function to delete user account and all associated data
 * This function:
 * 1. Verifies the user is authenticated
 * 2. Deletes user document from Firestore
 * 3. Deletes all user's payment intents
 * 4. Deletes user from Firebase Authentication
 */
exports.deleteUserAccount = functions
  .region("australia-southeast1")
  .https.onCall(async (data, context) => {
    console.log("🗑️ Delete user account request received");

    // Verify user is authenticated
    if (!context.auth) {
      console.error("❌ Unauthorized: No authentication context");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to delete account"
      );
    }

    const uid = context.auth.uid;
    console.log(`🔍 Processing account deletion for user: ${uid}`);

    try {
      const db = admin.firestore();
      const auth = admin.auth();

      // Step 1: Delete user document from Firestore
      console.log(`📄 Deleting user document for: ${uid}`);
      await db.collection("users").doc(uid).delete();
      console.log(`✅ User document deleted`);

      // Step 2: Delete all user's payment intents
      console.log(`💰 Searching for payment intents for user: ${uid}`);
      const paymentIntentsSnapshot = await db
        .collection("paymentIntents")
        .where("userId", "==", uid)
        .get();

      if (!paymentIntentsSnapshot.empty) {
        console.log(
          `💰 Found ${paymentIntentsSnapshot.size} payment intents to delete`
        );

        // Delete all payment intents in batch
        const batch = db.batch();
        paymentIntentsSnapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
        console.log(`✅ Deleted ${paymentIntentsSnapshot.size} payment intents`);
      } else {
        console.log(`💰 No payment intents found for user`);
      }

      // Step 3: Delete user from Firebase Authentication
      console.log(`🔐 Deleting user from Firebase Auth: ${uid}`);
      await auth.deleteUser(uid);
      console.log(`✅ User deleted from Firebase Auth`);

      console.log(`✅ Successfully deleted account for user: ${uid}`);

      return {
        success: true,
        message: "Account successfully deleted",
        deletedAt: new Date().toISOString(),
      };
    } catch (error) {
      console.error(`❌ Error deleting account for user ${uid}:`, error);

      // Handle specific error cases
      if (error.code === "auth/user-not-found") {
        throw new functions.https.HttpsError(
          "not-found",
          "User not found in authentication system"
        );
      }

      throw new functions.https.HttpsError(
        "internal",
        `Failed to delete account: ${error.message}`
      );
    }
  });
