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
      console.error("Invalid HMAC signature for app/uninstalled webhook");
      return new Response("Unauthorized", { status: 401 });
    }

    // Step 4: Parse the body after HMAC verification
    const payload = JSON.parse(rawBody.toString("utf8"));
    const shop = request.headers.get("X-Shopify-Shop-Domain") || payload.shop_domain;
    const topic = request.headers.get("X-Shopify-Topic") || "app/uninstalled";

    console.log(`Received ${topic} webhook for ${shop}`);

    // Mark merchant as uninstalled in our system
    try {
      await db.appInstallation.upsert({
        where: { shop },
        update: {
          installed: false,
          uninstalledAt: new Date(),
        },
        create: {
          shop,
          installed: false,
          uninstalledAt: new Date(),
        },
      });
      console.log(`Marked shop ${shop} as uninstalled in AppInstallation table`);
    } catch (error) {
      console.error(`Error updating AppInstallation for shop ${shop}:`, error);
    }

    // Delete all sessions for this shop
    try {
      const deletedSessions = await db.session.deleteMany({ where: { shop } });
      console.log(`Deleted ${deletedSessions.count} sessions for shop ${shop}`);
    } catch (error) {
      console.error(`Error deleting sessions for shop ${shop}:`, error);
    }

    return new Response(null, { status: 200 });
  } catch (error) {
    console.error("Error processing app/uninstalled webhook:", error);
    return new Response("Unauthorized", { status: 401 });
  }
};
