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
      console.error("Invalid HMAC signature for customers/data_request webhook");
      return new Response("Invalid HMAC", { status: 400 });
    }

    // Step 4: Parse the body after HMAC verification
    const payload = JSON.parse(rawBody.toString("utf8"));
    const shop = request.headers.get("X-Shopify-Shop-Domain") || payload.shop_domain;
    const topic = request.headers.get("X-Shopify-Topic") || "customers/data_request";

    console.log(`Received ${topic} webhook for ${shop}`);
    console.log("GDPR Data Request Payload:", JSON.stringify(payload, null, 2));

    // For now, log the request - compliance requires responding within 30 days
    console.log(`GDPR data request for customer ${payload.customer?.id} in shop ${shop}`);

    // TODO: Implement GDPR data request logic
    // 1. Query Firebase/Firestore for any customer data associated with this shop
    // 2. Compile customer data into required format
    // 3. Send data to customer via email or make it available for download

    return new Response(null, { status: 200 });
  } catch (error) {
    console.error("Error processing customers/data_request webhook:", error);
    return new Response("Invalid HMAC", { status: 400 });
  }
};
