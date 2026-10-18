# Proxo — Auth and interface polish

فۆڕمی دروستکردنی هەژمار یەک بەشە و OTP لە شاشەی جیاوازە. ئایکۆنی 3D، AppBar ـی هاوسەنگ، دوگمەی نەرم، ئاڵای عێراق، سپڵاش و گواستنەوەی ئەنیمەیشن زیاد کراون. چوونەژوورەوەی هەژماری پێشوو پێویستی بە ئامادەکردنی پڕۆفایل نییە.

## Changes

- Returning email/phone logins, restored sessions and named routes use a session-only `AuthenticatedGate`. Only signup retains provisioning. Database access still uses the signed-in user's RLS policies.
- Locally bundled 3D glass/porcelain artwork replaces the Auth intro tiles. Toolbar and field glyphs stay compact. The AppBar has 40 dp breathing room below it.
- Name, email, password and confirmation stay together, without numbered steps; OTP is separate. Email/phone forms fade sequentially, so fields never overlap. The selected channel moves across a pale track and values persist when switching back.
- Shared Material button themes and custom CTA tokens use soft 18 dp corners, including Auth, profile, ad, results, ProxoLink, deposit, receipt and error actions. Auth fields and OTP cells use 16 dp corners.
- OTP digits align horizontally and vertically without an invisible caret reserving width. The Iraq flag and +964 remain visible while typing.
- Routes animate for 320 ms; tabs have a 280 ms arrival while retaining scroll/form state and muting hidden tickers. Reduced-motion settings are respected.
- The shared refresh strip shows **نوێدەکرێتەوە** beside its spinner, with Arabic/Badini translations and space for large text.
- Native launch colors and the Flutter splash are aligned. The splash adds a blue halo and rounded brand surface.
- Background/terminated Android notification messages use the compact monochrome Proxo P mark and blue tint. Foreground and data-only messages also show the Proxo wordmark as their large icon. Removed the generic Firebase service declaration that competed with the Flutter messaging service.

## Actual screen captures

Production Flutter widgets with bundled fonts and fictional offline fixtures. The icon artwork was generated; these screenshots are rendered from the app implementation.

| Email login | Phone entry |
|---|---|
| ![Email](images/login-ckb-393.png) | ![Phone](images/login-phone-filled-ckb-393.png) |

| Single signup form | Separate OTP |
|---|---|
| ![Signup](images/signup-ckb-393.png) | ![OTP](images/otp-filled-ckb-393.png) |

| Splash | Refresh in progress |
|---|---|
| ![Splash](images/splash-ckb-393.png) | ![Refresh](images/refresh-ckb-393.png) |

[Full 150-case gallery with other app sections and scroll-bottom captures](screenshots.md)

## Measurements

Flutter logical pixels. Text follows system accessibility scaling. At 280 dp / 2× text, long forms scroll and phone digits can scroll horizontally within the input.

| Component | Specification |
|---|---|
| Page gutters / maximum form width | 20 each side / 440 |
| AppBar / wordmark | 56 high / 84 × 24 |
| Back and language touch areas | 48 × 48 |
| AppBar → intro / intro → form | 40 / 28 |
| 3D intro artwork | 64 × 64; decoded at 256 px |
| Heading / labels / input and button text | 20 / 13 / 14 |
| Auth font | RabarAuthRegular, weight 400 |
| Input height / radius | Minimum 48 / 16 |
| Primary button height / radius | Minimum 50 / 18 |
| OTP cell / radius / gap | 48 × 56 / 16 / 8; 3 columns on narrow screens |
| Phone flag | 24 × 16, 8 dp from +964 |
| Refresh spinner / normal reveal | 22 / 60 |
| Android notification small icon | White-alpha P on a 24 dp canvas |

Actual Sorani signup at 393 × 852 dp (DPR 3):

| Element | Left | Top | Width | Height |
|---|---:|---:|---:|---:|
| AppBar | 20 | 20 | 353 | 56 |
| Wordmark | 154.5 | 36 | 84 | 24 |
| Title | 100 | 133 | 273 | 30 |
| 3D artwork | 20 | 116 | 64 | 64 |
| Name | 20 | 261 | 353 | 48 |
| Email | 20 | 351 | 353 | 48 |
| Password | 20 | 441 | 353 | 48 |
| Confirmation | 20 | 633 | 353 | 48 |
| Submit | 20 | 697 | 353 | 50 |

[CSV geometry](measurements.csv) · [Component bounds](component-bounds.json) · [Full measurements](measurements.json.gz) · [OTP ink centers](otp-ink-centers.json) · [Hashes and counts](evidence.json)

## Verification and remaining deployment work

- **57 behavior tests passed:** native email signup/OTP contracts, invalid-code and auto-confirmation rejection, field retention, phone normalization, OTP lifecycle, returning-user entry, refresh coalescing, tab state, reduced-motion splash and signup provisioning.
- **150 visual cases passed:** 25 views/states × 3 languages × 2 viewport/text settings. **194 screenshots**, **10,290 measured RenderObjects**, **zero rendering exceptions**.
- No Auth text exceeds its maximum line count. Eighteen existing truncations remain in narrow notification summaries, an ad identifier and a task title; the report records them.
- Targeted analyzer: zero errors, 3 pre-existing Auth warnings, 27 informational lints.
- These are headless Flutter captures, not Android device screenshots. No live account, OTP, push message or payment was created.
- **Live email signup is blocked by server configuration:** the connected project's public Auth settings report `mailer_autoconfirm: true`, so Confirm email is currently disabled. The app rejects an auto-confirmed signup session instead of bypassing OTP. Email signup is enabled and the live profile trigger copies `full_name`, but the connector cannot edit hosted Auth configuration. Apply the remaining settings in [email-signup.md](email-signup.md) before releasing email signup.
- **Push server branding deployed:** live `send-notification` is now version 5, with `icon: ic_notification` and `color: #046CFA`. Its JWT requirement and all other behavior were preserved; the retrieved deployment matches the repository source. `send-push-notification` is not deployed in this project and was only updated in the repository. No live notification was sent; delivery and OEM notification rendering remain unverified.
- The workflow builds and retains `proxo-release-apk`. Without a configured release keystore it uses the repository's debug-signing fallback, so this is a test APK.

[Visual log](capture.log) · [Behavior log](behavior.log) · [Analyzer log](analyze.log) · [OTP recapture](otp-centering.log)

## Reproduce

Flutter 3.47.2 / Dart 3.13.2 with locked dependencies:

```sh
cd proxo_app
export FLUTTER_SUPPRESS_ANALYTICS=true DART_SUPPRESS_ANALYTICS=true
flutter --suppress-analytics pub get
flutter --suppress-analytics test --no-pub test/auth_refresh_test.dart test/auth_email_signup_test.dart test/auth_phone_flow_test.dart test/auth_otp_lifecycle_test.dart test/proxo_tab_stack_test.dart test/account_setup_test.dart test/whatsapp_marketing_test.dart test/proxo_polish_test.dart
flutter --suppress-analytics test --no-pub test/polish_capture_test.dart --reporter expanded
```

Android notification reference: https://firebase.google.com/docs/cloud-messaging/android/receive-messages

[Artwork provenance](../../proxo_app/assets/icons/auth/SOURCES.md)
