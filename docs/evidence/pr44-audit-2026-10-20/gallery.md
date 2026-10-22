# Current screenshot and receipt review

Receipt appearance was subsequently restored to the original style with balanced typography. See the [October 23 receipt correction and new previews](../receipt-restoration-2026-10-23/README.md). The receipt images below remain evidence of the earlier checkpoint.

Actual Flutter renders using fictional fixtures and production widgets. The original 34 screenshots and four PDFs are from verified source `3a90b93059a2a74d7eb37eb3f509582cce2fa366`; the four opened-checkout screenshots are from follow-up source `12e4e7cc9048449cd46d347597fbedda714a5563`. They do not prove hosted persistence or physical-device performance. Images are captured at 2× pixel density. Checkout captures use the bundled Kurdish fonts and DejaVu Sans Mono as a declared fixture substitute for Android's system monospace font.

[Eight actual Android profile captures from the final source](native/current/README.md) include native Back dismissal, real keyboard input after an error, and both receipts, with observed device dimensions and performance limits.

| Screen / section | State | Viewport / text | Screenshot |
| --- | --- | --- | --- |
| Home and shared app bar | Summary only | 393×852dp / 100% | [Open](screenshots/home-393-s1.png) |
| Home advertisement | Loaded thumbnail | 393×852dp / 100% | [Open](screenshots/home-thumbnail-image-393-s1-summary-card.png) |
| Home advertisement | Failed image fallback | 393×852dp / 100% | [Open](screenshots/home-thumbnail-failed-393-s1-summary-card.png) |
| Home advertisement | Long title, large text | 320×740dp / 200% | [Open](screenshots/home-long-label-320-s2-summary-card.png) |
| Best Results | Collapsed | 393×852dp / 100% | [Open](screenshots/results-393-s1-collapsed-card.png) |
| Best Results | Expanded objective and budget | 393×852dp / 100% | [Open](screenshots/results-393-s1-expanded.png) |
| Best Results | Expanded details, large text | 320×740dp / 200% | [Open](screenshots/results-320-s2-expanded-bottom.png) |
| Profile | Identity, balance and account options | 393×852dp / 100% | [Open](screenshots/profile-393-s1.png) |
| Profile | Support, language and WhatsApp | 393×852dp / 100% | [Open](screenshots/profile-393-s1-bottom.png) |
| Profile | Long name, large text | 320×740dp / 200% | [Open](screenshots/profile-long-320-s2.png) |
| Profile | Settings and logout, large text | 320×740dp / 200% | [Open](screenshots/profile-320-s2-bottom.png) |
| Profile OTP | Narrow dialog, large text | 320×740dp / 200% | [Open](screenshots/profile-email-otp-320-s2-dialog.png) |
| Profile OTP | Keyboard inset, large text | 320×740dp / 200% | [Open](screenshots/profile-email-otp-320-s2-keyboard-inset.png) |
| Menu | Large viewport and bottom action | 430×932dp / 100% | [Open](screenshots/menu-430-s1-bottom.png) |
| Menu | Small viewport and bottom action, large text | 320×740dp / 200% | [Open](screenshots/menu-320-s2-bottom.png) |
| Add Balance | Amount and two providers | 393×852dp / 100% | [Open](screenshots/deposit-393-s1.png) |
| Add Balance | FIB details and primary action | 393×852dp / 100% | [Open](screenshots/deposit-fib-393-s1-details.png) |
| Add Balance | FastPay checkout entry | 430×932dp / 100% | [Open](screenshots/deposit-fastpay-430-s1-checkout-entry.png) |
| Add Balance | FIB receipt selection, large text | 320×740dp / 200% | [Open](screenshots/deposit-fib-320-s2-receipt.png) |
| FastPay checkout | Official logo, full reference, amount and countdown | 393×852dp / 100% | [Open](screenshots/checkout-fastpay-393-s1.png) |
| FastPay checkout | Primary and cancellation actions | 393×852dp / 100% | [Open](screenshots/checkout-fastpay-393-s1-bottom.png) |
| FastPay checkout | Stacked summary and scrollable reference, large text | 320×740dp / 200% | [Open](screenshots/checkout-fastpay-320-s2.png) |
| FastPay checkout | Both bottom actions reachable, large text | 320×740dp / 200% | [Open](screenshots/checkout-fastpay-320-s2-bottom.png) |
| Pages | Empty list | 393×852dp / 100% | [Open](screenshots/tools-393-s1.png) |
| Create Page | Unavailable and real Retry, large text | 320×740dp / 200% | [Open](screenshots/tools-320-s2-create-unavailable.png) |
| Create Page | Usable form with fixture catalog | 393×852dp / 100% | [Open](screenshots/tools-create-flow-393-s1-contact-form.png) |
| Create Page | Saved fixture page, not hosted persistence | 393×852dp / 100% | [Open](screenshots/tools-create-flow-393-s1-created-in-memory.png) |
| Advertisements | Empty account and shared app bar | 393×852dp / 100% | [Open](screenshots/ads-empty-393-s1.png) |
| Advertisements | Empty account, large text | 320×740dp / 200% | [Open](screenshots/ads-empty-320-s2.png) |
| Advertisements | Request failure, large text | 320×740dp / 200% | [Open](screenshots/ads-error-320-s2.png) |
| Payment receipt | Complete standard receipt | 393×852dp / 100% | [Open](screenshots/transaction-receipt-393-s1.png) |
| Advertisement receipt | Header, targeting and totals | 393×852dp / 100% | [Open](screenshots/ad-receipt-393-s1.png) |
| Advertisement receipt | Payment details and full reference | 393×852dp / 100% | [Open](screenshots/ad-receipt-393-s1-bottom.png) |
| Payment receipt | Narrow reference row, large text | 320×740dp / 200% | [Open](screenshots/transaction-receipt-320-s2.png) |
| Advertisement receipt | Narrow reference row, large text | 320×740dp / 200% | [Open](screenshots/ad-receipt-320-s2-bottom.png) |
| Create Advertisement | Complete form and pricing | 393×852dp / 100% / full content | [Open](screenshots/create_ad_full_preview.png) |
| Create Advertisement | Pricing, payment options and submission | 393×852dp / 100% | [Open](screenshots/create_ad_pricing_preview.png) |
| Advertisement confirmation | Review and submission controls | 393×852dp / 100% | [Open](screenshots/ad_confirmation_preview.png) |

## Actual exported receipts

| Export | Pages | File |
| --- | --- | --- |
| Advertisement, standard free | 1 | [PDF](pdf/standard_free.pdf) |
| Advertisement, narrow paid | 3 | [PDF](pdf/narrow_paid.pdf) |
| Payment, standard | 1 | [PDF](pdf/transaction_standard.pdf) |
| Payment, narrow | 2 | [PDF](pdf/transaction_narrow.pdf) |

All four exports were rendered and visually inspected. Complete identifiers remain available in the exported output. Narrow screen identifier scrolling does not truncate the export.

[Checksums and capture metadata](gallery-manifest.json) · [Implementation and verification report](README.md)
