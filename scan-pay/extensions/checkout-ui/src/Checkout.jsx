import '@shopify/ui-extensions/preact';
import {render} from "preact";

// 1. Export the extension
export default async () => {
  render(<Extension />, document.body)
};

function Extension() {
  // Just adding a simple string here:
  const TEST = "TEST";

  // 2. Check instructions for feature availability
  if (!shopify.instructions.value.attributes.canUpdateAttributes) {
    return (
      <s-banner heading="checkout-ui" tone="warning">
        {shopify.i18n.translate("attributeChangesAreNotSupported")} - {TEST}
      </s-banner>
    );
  }

  // 3. Render a UI
  return (
    <s-banner heading="checkout-ui">
      <s-stack gap="base">
        <s-text>
          {shopify.i18n.translate("welcome", {
            target: <s-text type="emphasis">{shopify.extension.target}</s-text>,
          })} - {TEST}
        </s-text>
        <s-button onClick={handleClick}>
          {shopify.i18n.translate("addAFreeGiftToMyOrder")}
        </s-button>
      </s-stack>
    </s-banner>
  );

  async function handleClick() {
    // 4. Call the API to modify checkout
    const result = await shopify.applyAttributeChange({
      key: "requestedFreeGift",
      type: "updateAttribute",
      value: "yes",
    });
    console.log("applyAttributeChange result", result, TEST);
  }
}
