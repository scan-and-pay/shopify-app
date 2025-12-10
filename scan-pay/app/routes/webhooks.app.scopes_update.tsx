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
      console.error("Invalid HMAC signature for app/scopes_update webhook");
      return new Response("Invalid HMAC", { status: 400 });
    }

    // Step 4: Parse the body after HMAC verification
    const payload = JSON.parse(rawBody.toString("utf8"));
    const shop = request.headers.get("X-Shopify-Shop-Domain") || payload.shop_domain;
    const topic = request.headers.get("X-Shopify-Topic") || "app/scopes_update";

    console.log(`Received ${topic} webhook for ${shop}`);

    const current = payload.current as string[];

    // Update session scopes in database
    try {
      const sessions = await db.session.findMany({ where: { shop } });
      if (sessions.length > 0) {
        await db.session.updateMany({
          where: { shop },
          data: {
            scope: current.toString(),
          },
        });
        console.log(`Updated scopes for ${sessions.length} sessions for shop ${shop}`);
      }
    } catch (error) {
      console.error(`Error updating session scopes for shop ${shop}:`, error);
    }

    return new Response(null, { status: 200 });
  } catch (error) {
    console.error("Error processing app/scopes_update webhook:", error);
    return new Response("Invalid HMAC", { status: 400 });
  }
};
