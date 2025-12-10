import type { ActionFunctionArgs } from "react-router";
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
      console.error("Invalid HMAC signature for customers/redact webhook");
      return new Response("Unauthorized", { status: 401 });
    }

    // Step 4: Parse the body after HMAC verification
    const payload = JSON.parse(rawBody.toString("utf8"));
    const shop = request.headers.get("X-Shopify-Shop-Domain") || payload.shop_domain;
    const topic = request.headers.get("X-Shopify-Topic") || "customers/redact";

    console.log(`Received ${topic} webhook for ${shop}`);
    console.log("Customer Redaction Payload:", JSON.stringify(payload, null, 2));

    // For now, log the request - compliance requires deletion within 30 days
    console.log(`Customer redaction requested for customer ${payload.customer?.id} in shop ${shop}`);

    // TODO: Implement customer data deletion logic
    // 1. Query Firebase/Firestore for customer data associated with this shop/customer
    // 2. Delete or anonymize all customer personal data
    // 3. Log the deletion for audit purposes

    return new Response(null, { status: 200 });
  } catch (error) {
    console.error("Error processing customers/redact webhook:", error);
    return new Response("Unauthorized", { status: 401 });
  }
};
