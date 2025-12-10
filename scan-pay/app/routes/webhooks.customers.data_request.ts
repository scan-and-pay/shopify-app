import type { ActionFunctionArgs } from "react-router";
import { authenticate } from "../shopify.server";

export const action = async ({ request }: ActionFunctionArgs) => {
  try {
    const { shop, topic, payload } = await authenticate.webhook(request);

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
    return new Response(null, { status: 401 });
  }
};
