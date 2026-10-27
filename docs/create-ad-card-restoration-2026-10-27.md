# Restore the original Create Ad cards

The earlier restoration selected `3e96d569`, immediately before the app-wide redesign. That commit already contained the October 25 Create Ad redesign: open sections, a fixed bottom price bar and bottom navigation. Restoring those files therefore did not restore the original Create Ad screen from PR #44.

This correction uses the card presentation in PR #44 (`058f2f6ca7040481d82f5eaaec6edee28b1d3615`) and its existing [full-form capture](evidence/pr44-audit-2026-10-20/screenshots/create_ad_full_preview.png) and [price/payment capture](evidence/pr44-audit-2026-10-20/screenshots/create_ad_pricing_preview.png). The subsequent `88287b3` screen retained these cards while adding the payment editor and linked TikTok controls.

The screen again uses the original regular Rabar text, pale selected controls, rounded white section cards, restrained shadows, 20dp page gutters and 24dp card separation. Advertisement information appears first. Audience, budget, schedule, coupon, forecast, price and submission remain individual cards. The price breakdown scrolls with the form; the later fixed price bar and bottom navigation are removed.

This is a restoration of the original visual structure, not a claim of pixel identity to an older binary. The four current advertisement types, filtered page selection, linked TikTok account/video controls, confirmed payment editor and all ownership, payment, persistence and recovery behavior are retained. Newly retained controls use the original card styling. Provider feature gates are unchanged.

The in-form price summary hides stale amounts during recalculation and after failed quote requests. The review button uses its original static text, so an old quote cannot appear on the action while a newer quote is pending. Discounts and wallet balance still come from the authoritative current quote.

## Verification

The existing behavior and screenshot suites are updated to verify the original card structure, responsive text and touch targets, all four advertisement types, retained payment selection, linked-account behavior, stale-price suppression, discount display and quote recovery. Current screenshots are generated in GitHub CI under `docs/app-wide-release-2026-10-26/screenshots/create-ad/`; that directory is the existing artifact location, not the date of the new evidence. The PR checks and artifact metadata identify the exact source revision.

Local Dart parsing/formatting and `git diff --check` are available. Flutter compilation, tests and APK verification must be reported from this revision's GitHub CI; an earlier passing build does not validate this correction. No production deployment or release is implied.
