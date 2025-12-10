import type { ActionFunctionArgs } from "react-router";
import { authenticate } from "../shopify.server";
import db from "../db.server";

export const action = async ({ request }: ActionFunctionArgs) => {
  try {
    const { shop, session, topic } = await authenticate.webhook(request);

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

    // Webhook requests can trigger multiple times and after an app has already been uninstalled.
    // If this webhook already ran, the session may have been deleted previously.
    if (session) {
      await db.session.deleteMany({ where: { shop } });
      console.log(`Deleted sessions for shop ${shop}`);
    }

    return new Response(null, { status: 200 });
  } catch (error) {
    console.error("Error processing app/uninstalled webhook:", error);
    return new Response(null, { status: 401 });
  }
};
