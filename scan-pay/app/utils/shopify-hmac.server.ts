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
    const generatedHmac = createHmac("sha256", secret)
      .update(rawBody.toString(), "utf-8")
      .digest("base64");

    const hmacBuffer = Buffer.from(hmacHeader, "base64");
    const generatedHmacBuffer = Buffer.from(generatedHmac, "base64");

    let isValid = false;
    try {
      isValid = timingSafeEqual(generatedHmacBuffer, hmacBuffer);
    } catch (e) {
      // ignore
    }

    if (!isValid) {
      console.error("HMAC verification failed");
      return false;
    }

    return true;
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
  if (request.bodyUsed) {
    // If the body is already used, we can't clone it and read it again.
    // This is a limitation of the current approach.
    // We will have to rely on the fact that the body has been read into a raw buffer before.
    // This is a workaround, and a better solution would be to use a middleware that
    // captures the raw body before it's parsed.
    console.warn(
      "Request body already used. HMAC verification might not be accurate."
    );
    // This is a bit of a hack, but we'll try to get the raw body from the request
    // by reading it again. This might not work in all cases.
    const newRequest = new Request(request.url, {
      method: request.method,
      headers: request.headers,
      body: await request.text(),
    });
    return Buffer.from(await newRequest.arrayBuffer());
  }
  // Clone the request so we don't consume the original stream
  const clonedRequest = request.clone();

  // Get the body as ArrayBuffer
  const arrayBuffer = await clonedRequest.arrayBuffer();

  // Convert to Buffer
  return Buffer.from(arrayBuffer);
}
