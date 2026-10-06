The active integration uses four server-rendered v2 templates: pill, pill-mint,
pill-dark and pill-white. The Flutter form offers Contact, Order food and
Download the app. Food links point to the merchant listing; store links point
to the advertised app's own App Store / Google Play listing.

Private server documents live in api/_lib/proxolink-templates and are bundled
only into the API function. Their checksums are registered by the prepare SQL.
Profile data is serialized safely as JSON and inserted with textContent.
The standalone HTML files and editor in this folder are development tools.

Activation order:
1. Run scripts/sql/proxo_four_prepare.sql (additive schema/catalog preparation).
2. Verify the exact preview commit: backend tests, Flutter tests/build, browser
   dimensions, link navigation and the WhatsApp message-card motion.
3. Run scripts/sql/proxo_four_activate.sql, preserving card IDs, owners, profile
   values and ad relationships; this also archives the prior rows privately.
4. Promote the verified deployment and merge the same changes to main.
5. Verify the live catalog, customer pages and ad selection.

The old eight client style assets and renderer are removed. Telegram here is a
customer contact link; the retired Telegram document-delivery bot stays removed.
Existing merchant Instagram contact data remains usable.
