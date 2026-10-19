# Contextual examples and tutorial links

The ad video-link field and Create Page expose **بینینی نمونە**. A dialog opens a bundled image without waiting for Supabase or a web view; closing it retains the form. Page images are real full-page captures of the production contact, order and download templates, and now match all four selected styles. They are warmed in the image cache while the form is visible. The link example is a real PNG screenshot of the production Proxo URL field, with a complete selectable sample URL beneath it; the old SVG has been removed. [Latest screenshots, 24 selection cases and 96 footer checks](../evidence/proxolink-examples-2026-10-19/README.md).

The ad video-code field, video-link field and Create Page expose **بینینی فێرکاری**. This button reads one configured URL from the existing `public.pa_settings` table on demand. HTTPS URLs open in the user's external video/browser app. Repeated taps share one request; leaving the form prevents a late launch. Missing configuration, a failed lookup or a failed launch shows a localized message and preserves form input.

## Administrator configuration

In the connected Supabase project, edit the `value` of the following rows in **Table Editor → public.pa_settings** using an administrator account. Paste the real YouTube or other HTTPS tutorial link. No new APK is required for later link changes.

| `key` | Location |
|---|---|
| `tutorial_ad_video_code_url` | Ad authorization/video code |
| `tutorial_ad_video_link_url` | Ad video link |
| `tutorial_page_creation_url` | Create Page |

All three rows were seeded and read back successfully. Their values are currently empty because no tutorial video URLs were supplied. The app displays the honest “tutorial not added yet” state until an administrator publishes a link. Existing row-level policies and table privileges were preserved; client users do not gain write access. The migration is insert-only and does not overwrite already configured links.

## Verified examples

| Example | Sorani, 393 dp | Sorani, 280 dp / 2× text |
|---|---|---|
| Video link | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/video-link-ckb-393.png) | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/video-link-ckb-280.png) |
| Contact page | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/contact-ckb-393.png) | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/contact-ckb-280.png) |
| Order page | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/order-ckb-393.png) | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/order-ckb-280.png) |
| Download page | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/download-ckb-393.png) | [View](../evidence/proxolink-examples-2026-10-19/app/help-evidence/download-ckb-280.png) |

The same four dialogs were captured in Arabic and Badini: **24 cases total**, zero layout exceptions, dialog bounds checked against the viewport. Tall images scroll. [Current geometry and image hashes](../evidence/proxolink-examples-2026-10-19/app/page-example-evidence/manifest.json). The new localized captures include the exact production captions.

Eight behavior tests cover scoped GET-only configuration lookup, unsafe URL rejection, local example opening at both sizes, input retention, bundled page images, repeated taps, unpublished links and disposal while awaiting a response. Together with the new selected-style tests and localized captures, the focused run passed **34 tests**, including **24 actual-screen selection scenarios**. [Current log](../evidence/proxolink-examples-2026-10-19/app/example-tests/tests.log).

The suite also covers OTP entry and paste using Arabic-Indic (`١٢٣٤٥٦`), Eastern Arabic (`۱۲۳۴۵۶`), ASCII and mixed numerals. Input is normalized to ASCII for submission; the five added cases check that prior digits survive a partial paste and that a rebuild preserves the code without repeating the completion callback.

Reward claims, voucher-code claims and assigned-voucher activation now share a minimum height of **48 dp** and the **18 dp** control-radius token. Existing tasks/vouchers captures passed all 12 locale/viewport combinations, and all six voucher combinations passed again after the assigned-voucher adjustment. Both voucher controls measured 48 dp at normal text size; at 2× text they grew to 67 dp and 59 dp without layout exceptions. The task-reward claim has the same constraints in code, but the current task fixture has no completed reward, so that branch was not measured in these captures.

These screen and button checks use controlled fixtures and cover the exercised states; they do not certify every business transaction or smooth animation on physical devices. The Android runtime passed 36 cases and captured the production example dialogs; [native evidence and performance limits](native/README.md).

The requested TikTok thumbnail preview is a feasibility question, not a feature added by this change. TikTok's public oEmbed response can provide `thumbnail_url` for available public videos; private/deleted/unavailable videos need a fallback. See https://developers.tiktok.com/doc/embed-videos/.
