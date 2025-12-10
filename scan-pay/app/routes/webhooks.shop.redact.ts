import type { ActionFunctionArgs } from "react-router";
import db from "../db.server";
import { verifyShopifyHmac, getRawBody } from "../utils/shopify-hmac.server";

export const action = async ({ request }: ActionFunctionArgs) => {
  try {
    // Step 1: Get raw body BEFORE any parsing
    const rawBody = await getRawBody(request);

    // Step 2: Get HMAC header
    const hmacHeader = request.headers.get("X-Shopify-Hmac-Sha256");

    // Step 3: Verify HMAC signature
    const secret = process.env.SHOPIFY_API_SECRET || "";
    if (!verifyShopifyHmac(rawBody, hmacHeader, secret)) {
      console.error("Invalid HMAC signature for shop/redact webhook");
      return new Response("Invalid HMAC", { status: 400 });
    }

    // Step 4: Parse the body after HMAC verification
    const payload = JSON.parse(rawBody.toString("utf8"));
    const shop = request.headers.get("X-Shopify-Shop-Domain") || payload.shop_domain;
    const topic = request.headers.get("X-Shopify-Topic") || "shop/redact";

    console.log(`Received ${topic} webhook for ${shop}`);
    console.log("Shop Redaction Payload:", JSON.stringify(payload, null, 2));

    // This webhook is sent 48 hours after app uninstall
    // We must delete ALL shop and customer data
    console.log(`Shop redaction requested for shop ${shop} (ID: ${payload.shop_id})`);

    // Delete shop sessions from local database
    try {
      const deletedSessions = await db.session.deleteMany({ where: { shop } });
      console.log(`Deleted ${deletedSessions.count} local sessions for shop ${shop}`);
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
    return new Response("Invalid HMAC", { status: 400 });
  }
};
