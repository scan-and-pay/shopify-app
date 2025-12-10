import type { ActionFunctionArgs } from "react-router";
import { verifyShopifyHmac, getRawBody } from "../utils/shopify-hmac.server";

export const action = async ({ request }: ActionFunctionArgs) => {
  try {
    const topic = request.headers.get("X-Shopify-Topic");
    if (!topic) {
        return new Response("Invalid request", { status: 400 });
    }

    // Step 1: Get raw body BEFORE any parsing
    const rawBody = await getRawBody(request);

    // Step 2: Get HMAC header
    const hmacHeader = request.headers.get("X-Shopify-Hmac-Sha256");

    // Step 3: Verify HMAC signature
    const secret = process.env.SHOPIFY_API_SECRET || "";
    if (!verifyShopifyHmac(rawBody, hmacHeader, secret)) {
      console.error(`Invalid HMAC signature for ${topic} webhook`);
      return new Response("Invalid HMAC", { status: 400 });
    }

    // Step 4: Parse the body after HMAC verification
    const payload = JSON.parse(rawBody.toString("utf8"));
    const shop = request.headers.get("X-Shopify-Shop-Domain") || payload.shop_domain;

    console.log(`Received ${topic} webhook for ${shop}`);

    switch (topic) {
      case "customers/data_request":
        console.log("GDPR Data Request Payload:", JSON.stringify(payload, null, 2));
        console.log(`GDPR data request for customer ${payload.customer?.id} in shop ${shop}`);
        break;
      case "customers/redact":
        console.log("Customer Redaction Payload:", JSON.stringify(payload, null, 2));
        console.log(`Customer redaction requested for customer ${payload.customer?.id} in shop ${shop}`);
        break;
      case "shop/redact":
        console.log("Shop Redaction Payload:", JSON.stringify(payload, null, 2));
        console.log(`Shop redaction requested for shop ${shop} (ID: ${payload.shop_id})`);
        break;
      default:
        console.log(`Unhandled webhook topic: ${topic}`);
    }

    return new Response(null, { status: 200 });
  } catch (error) {
    console.error("Error processing webhook:", error);
    return new Response("Invalid HMAC", { status: 400 });
  }
};
