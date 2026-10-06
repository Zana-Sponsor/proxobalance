The production renderer uses four v3 templates: pill, pill-mint, pill-dark and
pill-white. The v3 release adds optically balanced SVG glyphs and vivid three-stop
provider gradients, including charcoal wrappers around unchanged store badges.

Private documents are traced into the API function. Checksums are registered by
scripts/sql/proxo_gradients_v3_prepare.sql before deploying the matching renderer.
Retire the prior v2 catalog rows only after the v3 production pages are verified,
using scripts/sql/proxo_gradients_v3_retire.sql. Customer cards and ad links are
not rewritten for this visual release. Existing cards render with the current
reviewed source; a successful later edit upgrades their stored version.

The Flutter form offers Contact, Order food and Download the app, reading the
version from the server catalog. Food links open the merchant listing; store
links open the advertised app's own App Store / Google Play listing. External
navigation, ownership checks, safe JSON rendering and original store badge
artwork are preserved.
