# Contextual examples and tutorial links

The ad video-link field and Create Page expose **بینینی نمونە**. A dialog opens a bundled image without waiting for Supabase or a web view; closing it retains the form. Page images are the existing rendered contact, order and download templates. They are warmed in the image cache while the form is visible. The link example is an exact SVG illustration with selectable sample URL text.

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
| Video link | [View](help-images/video-link-ckb-393.png) | [View](help-images/video-link-ckb-280.png) |
| Contact page | [View](help-images/contact-ckb-393.png) | [View](help-images/contact-ckb-280.png) |
| Order page | [View](help-images/order-ckb-393.png) | [View](help-images/order-ckb-280.png) |
| Download page | [View](help-images/download-ckb-393.png) | [View](help-images/download-ckb-280.png) |

The same four dialogs were captured in Arabic and Badini: **24 cases total**, zero layout exceptions, dialog bounds checked against the viewport. Tall images scroll. [All geometry and image hashes](help-measurements.json).

Eight behavior tests cover scoped GET-only configuration lookup, unsafe URL rejection, local example opening at both sizes, input retention, bundled page images, repeated taps, unpublished links and disposal while awaiting a response. The complete Flutter suite passed **880 tests**; its final log ends with `+880: All tests passed!`.

The suite also covers OTP entry and paste using Arabic-Indic (`١٢٣٤٥٦`), Eastern Arabic (`۱۲۳۴۵۶`), ASCII and mixed numerals. Input is normalized to ASCII for submission; the five added cases check that prior digits survive a partial paste and that a rebuild preserves the code without repeating the completion callback.

Reward claims, voucher-code claims and assigned-voucher activation now share a minimum height of **48 dp** and the **18 dp** control-radius token. Existing tasks/vouchers captures passed all 12 locale/viewport combinations, and all six voucher combinations passed again after the assigned-voucher adjustment. Both voucher controls measured 48 dp at normal text size; at 2× text they grew to 67 dp and 59 dp without layout exceptions. The task-reward claim has the same constraints in code, but the current task fixture has no completed reward, so that branch was not measured in these captures.

These screen and button checks use controlled fixtures and cover the exercised states; they do not certify every business transaction or smooth animation on physical devices. The Android runtime passed 36 cases and captured the production example dialogs; [native evidence and performance limits](native/README.md).

The requested TikTok thumbnail preview is a feasibility question, not a feature added by this change. TikTok's public oEmbed response can provide `thumbnail_url` for available public videos; private/deleted/unavailable videos need a fallback. See https://developers.tiktok.com/doc/embed-videos/.
