import type { ActionFunctionArgs } from "react-router";
import { authenticate } from "../shopify.server";
import db from "../db.server";

export const action = async ({ request }: ActionFunctionArgs) => {
  try {
    const { shop, topic, payload } = await authenticate.webhook(request);

    console.log(`Received ${topic} webhook for ${shop}`);
    console.log("Shop Redaction Payload:", JSON.stringify(payload, null, 2));

    // This webhook is sent 48 hours after app uninstall
    // We must delete ALL shop and customer data
    console.log(`Shop redaction requested for shop ${shop} (ID: ${payload.shop_id})`);

    // Delete shop sessions from local database
    try {
      await db.session.deleteMany({ where: { shop } });
      console.log(`Deleted local sessions for shop ${shop}`);
    } catch (error) {
      console.error(`Error deleting sessions for shop ${shop}:`, error);
    }

    // TODO: Implement shop data deletion logic
    // 1. Delete all shop-related data from Firebase/Firestore
    // 2. Delete all customer data associated with this shop
    // 3. Clean up any stored configurations, payment data, etc.

    return new Response(null, { status: 200 });
  } catch (error) {
    console.error("Error processing shop/redact webhook:", error);
    return new Response(null, { status: 401 });
  }
};
