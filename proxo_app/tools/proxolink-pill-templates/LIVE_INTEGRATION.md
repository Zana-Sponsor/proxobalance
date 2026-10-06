The production renderer uses four v4 templates: pill, pill-mint, pill-dark and
pill-white. The v4 release matches the supplied zoom.html icon sizes: WhatsApp
25px, Viber 22px and phone 20px, with symmetric 44px slots and exact embedded
Font Awesome 6.5.0 font glyphs with their original metrics and hinting. The green WhatsApp speech card remains hidden for two
seconds, then appears above the button with a finite animation. Reduced motion
preserves the delay and displays a static card. The vivid provider gradients
and original store badges remain in place.

Private documents are traced into the API function. Checksums are registered by
scripts/sql/proxo_icons_v4_prepare.sql before deploying the matching renderer.
Retire the prior v3 catalog rows only after the v4 production pages are verified,
using scripts/sql/proxo_icons_v4_retire.sql. Customer cards and ad links are
not rewritten for this visual release. Existing cards render with the current
reviewed source; a successful later edit upgrades their stored version.

The Flutter form offers Contact, Order food and Download the app, reading the
version from the server catalog. Food links open the merchant listing; store
links open the advertised app's own App Store / Google Play listing. External
navigation, ownership checks, safe JSON rendering and original store badge
artwork are preserved.
