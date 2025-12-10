import type { ActionFunctionArgs } from "react-router";
import { authenticate } from "../shopify.server";

export const action = async ({ request }: ActionFunctionArgs) => {
  try {
    const { shop, topic, payload } = await authenticate.webhook(request);

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
    return new Response(null, { status: 401 });
  }
};
