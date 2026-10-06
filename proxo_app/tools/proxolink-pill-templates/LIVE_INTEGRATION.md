The production renderer uses four v5 templates: pill, pill-mint, pill-dark and
pill-white. This release adds white provider labels/icons, accessible saturated
three-stop gradients, and the official Talabat, Lezzoo, Toters and WADE marks
embedded from their websites. Original source artwork, checksums and rendering
treatments are documented in official-logo-sources.json and assets/official.

The WhatsApp speech card appears after exactly two seconds above the physical
right side of the button in RTL and LTR, with white text, a small message symbol,
rounded corners and a right-side tail. Its finite entrance/float animation and
static reduced-motion behavior retain the same WhatsApp navigation action.
WhatsApp 25px, Viber 22px and phone 20px glyph sizes still match zoom.html.
Symmetric 44px slots center labels at every mobile width; food marks occupy
24px boxes without stretching their artwork.

Register scripts/sql/proxo_brand_v5_prepare.sql before deploying the matching
renderer. Retire v4 only after the exact v5 production pages pass verification,
using scripts/sql/proxo_brand_v5_retire.sql. Existing customer cards, profile and
contact values, avatars and advertisement relationships are not rewritten.

The Flutter form offers Contact, Order food and Download the app and reads the
version from the server catalog. Food links open the merchant listing; store
links open the advertised app's own App Store / Google Play listing. External
navigation, ownership checks, safe JSON rendering and original store badge
artwork are preserved. This visual release requires no native Dart changes.
