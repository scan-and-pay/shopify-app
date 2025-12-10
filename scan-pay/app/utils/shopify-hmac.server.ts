import { createHmac, timingSafeEqual } from "crypto";

/**
 * Verifies Shopify webhook HMAC signature using timing-safe comparison.
 *
 * CRITICAL: Must use raw request body (not parsed JSON) for verification.
 *
 * @param rawBody - The raw request body as Buffer or string
 * @param hmacHeader - The X-Shopify-Hmac-Sha256 header value
 * @param secret - Your Shopify API secret key
 * @returns true if HMAC is valid, false otherwise
 */
export function verifyShopifyHmac(
  rawBody: Buffer | string,
  hmacHeader: string | null | undefined,
  secret: string
): boolean {
  if (!hmacHeader) {
    console.error("Missing X-Shopify-Hmac-Sha256 header");
    return false;
  }

  if (!secret) {
    console.error("Missing SHOPIFY_API_SECRET environment variable");
    return false;
  }

  try {
    // Convert rawBody to string if it's a Buffer
    const bodyString = typeof rawBody === "string" ? rawBody : rawBody.toString("utf8");

    // Compute HMAC-SHA256 using the raw body
    const generatedHmac = createHmac("sha256", secret)
      .update(bodyString, "utf8")
      .digest("base64");

    // Use timing-safe comparison to prevent timing attacks
    const isValid = timingSafeEqual(
      Buffer.from(generatedHmac, "utf8"),
      Buffer.from(hmacHeader, "utf8")
    );

    if (!isValid) {
      console.error("HMAC verification failed");
      console.error("Expected:", generatedHmac);
      console.error("Received:", hmacHeader);
    }

    return isValid;
  } catch (error) {
    console.error("Error during HMAC verification:", error);
    return false;
  }
}

/**
 * Extracts the raw body from a Request object.
 * React Router may have already parsed the body, so we need to handle both cases.
 *
 * @param request - The incoming Request object
 * @returns Promise<Buffer> - The raw request body as Buffer
 */
export async function getRawBody(request: Request): Promise<Buffer> {
  // Clone the request so we don't consume the original stream
  const clonedRequest = request.clone();

  // Get the body as ArrayBuffer
  const arrayBuffer = await clonedRequest.arrayBuffer();

  // Convert to Buffer
  return Buffer.from(arrayBuffer);
}
