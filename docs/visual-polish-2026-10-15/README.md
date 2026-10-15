# Proxo visual consistency, languages and activation notice

Application source: `1665bdb815c46320815693772eb26318d45f56b4`. Review branch / draft PR #7. No merge, production deployment, production payment, OTP send or live database migration was performed.

## 1. Inspect before replacing

The original [icon inventory](../icon-inventory-2026-10-14.json) and the [current inventory](icon-inventory.json) cover Dart glyph references, local SVGs and PNGs. Counts are lexical references, not visible icons or runtime coverage. Existing Solar Outline/Linear artwork, provider logos, social brands, and suitable system controls were preserved. Generic filled FontAwesome icons in levels/tasks/vouchers and the mixed notification group were harmonized with Solar Outline. Unused candidate SVG downloads were removed.

The latest user instruction is followed: the three Home quick actions contain an icon and localized section name, **no image cards**.

## 2. External icons, provenance and licensing

**34 original Solar Outline SVGs, 70,522 bytes total**, are bundled in `proxo_app/assets/icons/solar/`. SVGs retain crisp geometry across display densities; they are not enlarged raster screenshots. All 34 Git blob hashes match immutable upstream artwork byte for byte. See [integrity checks](asset-integrity.json), [exact source paths and hashes](../../proxo_app/assets/icons/solar/SOURCES.json), and [license notice](../../proxo_app/assets/icons/solar/LICENSE.md).

- Artwork: **480 Design / Solar**, **CC BY 4.0**. Source revision `44017167688b49109d88ae6a98979b23d8950db0` in [480-Design/Solar-Icon-Set](https://github.com/480-Design/Solar-Icon-Set/tree/44017167688b49109d88ae6a98979b23d8950db0).
- [License reference](https://solar-icons.vercel.app/docs/v2/community/license), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Profile → About includes attribution. Geometry is unchanged; runtime size and monochrome tint are supplied by Proxo.
- The existing `solar_icons` package wrapper is BSD-3-Clause; existing `solar_iconkit` is retained. Wrapper licensing does not replace attribution for the artwork.
- Flaticon was reviewed as the suggested source; Solar was chosen to match icons already present in Proxo and provide a traceable, consistently licensed collection. No Flaticon commercial asset was incorporated.
- Uses existing `flutter_svg` and Solar packages; no new package dependency, runtime icon website, or duplicate image variants.

| Component / function | Exact bundled SVG filenames |
|---|---|
| Bottom tabs, shared navigation | `home_2`, `clapperboard_play`, `widget_2`, `user_rounded`, `add_circle` |
| Login, signup, password, recovery, OTP | `login_2`, `user_plus_rounded`, `lock_password`, `lock_keyhole`, `key`, `shield_check` |
| Form fields and password visibility | `letter`, `phone`, `eye`, `eye_closed` |
| Back/forward/menu/notifications/search | `alt_arrow_right`, `alt_arrow_left`, `hamburger_menu`, `bell`, `magnifer` |
| Balance, uploads and copying | `wallet_2`, `gallery_add`, `upload`, `copy` |
| Sidebar and secondary actions | `history`, `settings`, `question_circle`, `logout_2`, `tag_price` |
| Feedback and language | `check_circle`, `close_circle`, `info_circle`, `danger_circle`, `global` |

All filenames above have `.svg` suffix. `ProxoSymbol` renders originals; `ProxoSolarIcon` maps selected existing glyphs to originals and preserves suitable glyphs from the same collection.

| Existing generic icon group | Solar Outline replacement glyphs |
|---|---|
| Levels: medals, rewards, tiers, lock | `medalStar`, `cupStar`, `crown`, `star`, `lock`, `widget_2`, `altArrowRight` |
| Tasks: checklist and completion | `checklist`, `checkCircle`, `altArrowRight` |
| Vouchers: gift, refund, compensation, code, expiry | `handHeart`, `history`, `handShake`, `gift`, `ticket`, `clipboard`, `clockCircle`, `checkCircle` |
| Notification statuses | `checkCircle`, `closeCircle`, `clapperboardPlay`, `cupStar`, `pauseCircle`, `rocket`, `shieldCheck`, `wallet2`, `history`, `gift`, `chatRound`, `restart`, `bell`, `dangerTriangle`, `shieldWarning`, `shield` |
| Notification controls | `letterOpened`, `pin`, `bellOff`, `archive`, `trashBinMinimalistic`, `tuning`, `altArrowRight` |

The stored gem/diamond tier identifiers remain unchanged; their generic presentation now uses an outline star. Brand marks and payment logos retain their original identity. Remaining Material controls were not indiscriminately replaced.

## 3. Layout and visual balance

| Surface | Implemented change |
|---|---|
| Login / signup / forgot password | Soft filled fields, quiet borders, coherent leading/visibility icons, natural-height actions, wrapping prompts, responsive headers, shared spacing, localized errors |
| OTP | Six 48dp targets; two rows of three where six cannot fit; LTR code entry inside RTL UI; paste/focus behavior retained; reduced-motion support |
| Sidebar | Balanced width up to 336dp, 24dp icons, 14sp wrapping labels, correct selected route, independent profile/unread loading, corrected Home/help navigation |
| Profile | Natural-height balance, explicit top-up action, readable responsive quick cards, matching menu surfaces, language picker, no perpetual shine |
| Bottom navigation | 24dp outline tab icons, 12sp labels, selected color/container, **56dp central create button**, at least 48dp tap targets; scrollable readable strip at extreme text scaling |
| App bars | Consistent icon/label treatment and 48dp actions; shared app bar used for deposit and discount codes; notification sliver bar grows with large text |
| Home | Icon-and-label quick actions, localized banner fallback, locale-filtered CMS banners, responsive overview metrics, localized results headings and labels |
| Advertisement creation/list | Existing ordered sections and data contracts preserved; softer controls, localized headings, category/filter/status/validation copy and errors |
| Add balance | Responsive provider grid, original provider logos/numbers, quiet amount field, SVG copy/upload controls, receipt-upload panel grows naturally at large text |
| Secondary screens | Localized counts and captions; Solar icons in levels/tasks/vouchers/notifications; wrapped level name/status badges and notification timestamps |
| History / receipts | Existing transaction/receipt data semantics preserved, explicit locale selection corrected, dynamic app-owned transaction labels localized |

Large text is not reduced to force a fit. Currency, phone numbers, codes and identifiers keep correct LTR isolation within RTL screens. Selected/disabled controls retain state treatment and their existing action handlers.

## 4. Arabic, Sorani and Badini

The local catalog contains **799 app-owned messages**, each with Arabic and Arabic-script Badini values alongside the Sorani source. Generation validates nonempty columns, duplicate keys and placeholder parity. The language choice persists and mounted secondary screens subscribe to changes.

Auth, Home, sidebar, profile, tools/editor, ads and creation, deposit, history/receipt labels, notification defaults, help and account copy use the shared lookup. User names, campaign titles, submitted values, provider numbers, IDs, stored transaction notes and arbitrary CMS/server text are not translated or rewritten.

Badini is represented as `kmr-Arab-IQ` and remains RTL. Existing backend category identifiers and public-page payload contracts are unchanged. CMS images require a matching locale (or `all`); otherwise Home uses localized app text rather than displaying an image with the wrong language.

Limits: stock Flutter Material date/time dialog strings still use the existing Arabic framework fallback for Kurdish; this is not a custom Kurdish framework-localization package. Public ProxoLink page-language options and user-authored content are distinct from app UI language. Human linguistic proofreading, particularly Badini terminology, remains appropriate before a public release; catalog completeness is not certification of translation quality.

## 5. Performance, activation notice and Supabase

### Concrete performance fixes

- Home results respect the existing ten-minute cache on mount instead of forcing a new request.
- Banner image-byte cache is bounded to 12 items / 12 MiB; locale change resets the slider safely.
- Removed unused sidebar loyalty reads from the identity-loading path. Unread fetch does not delay the profile header.
- Removed indefinite decorative motion; banner/OTP/notice transitions honor reduced-motion preferences where changed.
- Auth service resources close on disposal. LevelsPage no longer starts a refresh from the realtime `closed` callback while being disposed, and concurrent silent refreshes are coalesced.
- No fabricated FPS or opening-latency benchmark: these are verified reductions in work and concrete bug fixes, not a claim that every physical-device source of lag has disappeared.

### Suggested notice, implemented

A compact white notice slides/fades from the top with a green Solar verification icon, localized **“Your ad is active”**, the campaign name, **View**, and **Close**. It normally dismisses after seven seconds; accessible navigation keeps it available. It avoids covering the keyboard.

Only an owner-matching server `ad_active` notification dated within the previous **five minutes** qualifies, and the owned ad must currently have `active` status. A metrics update or an old active ad does not qualify. Per-account persisted deduplication, a bounded ten-minute seen cache, session-generation guards, realtime subscription and throttled resume lookup prevent ordinary repeat/old-account displays. Foreground push handling consults the same bridge. See the notice screenshots below.

Parser, visual layout and View/Close callbacks are tested. Full device push delivery, all lifecycle races and OS notification-permission scenarios are not represented by the widget fixture tests.

### Supabase access-control changes prepared and tested

Read-only inspection covered relevant RLS policies, role checks, profile role/balance guards, ad correction and notification ownership. Client access does not use a service-role credential.

The tested, CLI-named migration is [20261014235516_ad_correction_and_notification_guards.sql](../../proxo_app/supabase/migrations/20261014235516_ad_correction_and_notification_guards.sql). It hardens owner-scoped ad corrections with an allowed requested field, review-state/replay checks, row locking, typed date/time validation and server-owned status/timestamps. Direct client ad state/budget mutation and notification-content forgery are blocked; marking one's notification read remains allowed. Ad correction uses the RPC instead of direct table updates.

[Isolated PostgreSQL security verification](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38658420035) applies the committed migration twice and checks valid correction, invalid fields/dates, cross-owner access, replay, direct tampering, notification forgery/read state and anonymous RPC access. **The migration has not been applied to production. It must be applied before releasing the updated ad-correction client.**

## 6. Verification and screenshots

All results below use application commit `1665bdb815c46320815693772eb26318d45f56b4`, except the separately linked SQL run (the migration is unchanged).

| Verification | Result / evidence |
|---|---|
| [Polish screens + Auth/language/notice behavior](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38715756082) | **90/90 candidate capture tests + 23/23 behavior tests pass**; Arabic, Sorani and Badini, 393dp normal / 280dp at 2× text; additional lower-section and notice PNGs |
| [Tools/history/receipt/UI regression](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38715756064) | **64/64 candidate captures + 298/298 behavior tests pass** |
| [Sidebar/Profile/app-bar/navigation](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38715756130) | **20/20 candidate captures + 3/3 behavior tests pass** |
| [Native Android API 35 matrix](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38715756098) | **3/3 emulator jobs pass**: phone 393dp at 3× density, narrow 280dp at 3×, tablet 768dp at 2×; each exercises 1×/2× text; **81 original PNGs** indexed |
| [Release and ProxoLink regression gates](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38715756183) | Flutter analysis/regressions, release APK build and scan, backend, database, edge-function and responsive jobs **all pass** |
| [Credential-free native fixture APK](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38715756294) | Analysis and build **pass**; optional hosted/runtime jobs were skipped by this workflow configuration, not counted as tests |
| [Ad correction / notification security](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38658420035) | Committed migration applies twice; isolated PostgreSQL authorization and tamper checks **pass**; production migration remains pending |

Suite counts are reported separately because some behavior coverage overlaps; they are not a count of unique screens. Native results confirm six quick-action callbacks per device, disabled action rejection, real Android back dismissing the keyboard while keeping the form, decoded 24dp app-bar logos at both text scales, and zero tap-hit warnings. The narrow 2× navigation intentionally scrolls horizontally to keep labels and targets readable.

The repository gallery contains **60 original screenshots**: 27 before/after pairs, three new activation-notice captures, and three representative native captures. Full workflow archives and the 81-image native index remain linked in [verification.json](verification.json).

The screenshots render real production widgets with bundled fonts and fictional read-only data. OTP capture exercises the actual OTP component; no live sign-in/payment is submitted. Before/after sources are immutable and identified per capture group. They are review evidence, not approved golden baselines.

The immutable older baseline has a real LevelsPage realtime teardown assertion. Its six failures and layout errors are retained in the capture log; only the baseline step permits that failure. Candidate exceptions remain blocking. A separate gate requires all 90 baseline and all 90 candidate main screenshots and their metadata, so a permitted baseline failure cannot silently yield an incomplete comparison.

Artifact ZIP SHA-256, ZIP CRC, screenshot dimensions and individual image SHA-256 are recorded in `verification.json`. Images linked below are original PNGs, not generated mockups or retouched screens.

### پێش و دوا / Before and after

| Surface | Before | After |
|---|---|---|
| Login · Sorani | <img src="before/polish-login-ckb-393-s1.0-d3.0.png" width="260" alt="Before Login · Sorani"> | <img src="after/polish-login-ckb-393-s1.0-d3.0.png" width="260" alt="After Login · Sorani"> |
| Signup · Arabic | <img src="before/polish-signup-ar-393-s1.0-d3.0.png" width="260" alt="Before Signup · Arabic"> | <img src="after/polish-signup-ar-393-s1.0-d3.0.png" width="260" alt="After Signup · Arabic"> |
| Forgot password · Badini | <img src="before/polish-forgot-kmr-393-s1.0-d3.0.png" width="260" alt="Before Forgot password · Badini"> | <img src="after/polish-forgot-kmr-393-s1.0-d3.0.png" width="260" alt="After Forgot password · Badini"> |
| OTP · Sorani | <img src="before/polish-otp-ckb-393-s1.0-d3.0.png" width="260" alt="Before OTP · Sorani"> | <img src="after/polish-otp-ckb-393-s1.0-d3.0.png" width="260" alt="After OTP · Sorani"> |
| Home · Arabic | <img src="before/polish-home-ar-393-s1.0-d3.0.png" width="260" alt="Before Home · Arabic"> | <img src="after/polish-home-ar-393-s1.0-d3.0.png" width="260" alt="After Home · Arabic"> |
| Profile · Badini | <img src="before/polish-profile-kmr-393-s1.0-d3.0.png" width="260" alt="Before Profile · Badini"> | <img src="after/polish-profile-kmr-393-s1.0-d3.0.png" width="260" alt="After Profile · Badini"> |
| Bottom navigation | <img src="before/polish-navigation-ckb-393-s1.0-d3.0.png" width="260" alt="Before Bottom navigation"> | <img src="after/polish-navigation-ckb-393-s1.0-d3.0.png" width="260" alt="After Bottom navigation"> |
| Add balance · Arabic | <img src="before/polish-deposit-ar-393-s1.0-d3.0.png" width="260" alt="Before Add balance · Arabic"> | <img src="after/polish-deposit-ar-393-s1.0-d3.0.png" width="260" alt="After Add balance · Arabic"> |
| Advertisements · Arabic | <img src="before/polish-ads-ar-393-s1.0-d3.0.png" width="260" alt="Before Advertisements · Arabic"> | <img src="after/polish-ads-ar-393-s1.0-d3.0.png" width="260" alt="After Advertisements · Arabic"> |
| Create ad · Arabic | <img src="before/polish-create-ar-393-s1.0-d3.0.png" width="260" alt="Before Create ad · Arabic"> | <img src="after/polish-create-ar-393-s1.0-d3.0.png" width="260" alt="After Create ad · Arabic"> |
| Levels · Arabic | <img src="before/polish-levels-ar-393-s1.0-d3.0.png" width="260" alt="Before Levels · Arabic"> | <img src="after/polish-levels-ar-393-s1.0-d3.0.png" width="260" alt="After Levels · Arabic"> |
| Tasks · Badini | <img src="before/polish-tasks-kmr-393-s1.0-d3.0.png" width="260" alt="Before Tasks · Badini"> | <img src="after/polish-tasks-kmr-393-s1.0-d3.0.png" width="260" alt="After Tasks · Badini"> |
| Vouchers · Badini | <img src="before/polish-vouchers-kmr-393-s1.0-d3.0.png" width="260" alt="Before Vouchers · Badini"> | <img src="after/polish-vouchers-kmr-393-s1.0-d3.0.png" width="260" alt="After Vouchers · Badini"> |
| Discount codes · Arabic | <img src="before/polish-discounts-ar-393-s1.0-d3.0.png" width="260" alt="Before Discount codes · Arabic"> | <img src="after/polish-discounts-ar-393-s1.0-d3.0.png" width="260" alt="After Discount codes · Arabic"> |
| Notifications · Arabic | <img src="before/polish-notifications-ar-393-s1.0-d3.0.png" width="260" alt="Before Notifications · Arabic"> | <img src="after/polish-notifications-ar-393-s1.0-d3.0.png" width="260" alt="After Notifications · Arabic"> |
| Profile · lower section | <img src="before/polish-profile-kmr-393-s1.0-d3.0-bottom.png" width="260" alt="Before Profile · lower section"> | <img src="after/polish-profile-kmr-393-s1.0-d3.0-bottom.png" width="260" alt="After Profile · lower section"> |
| Deposit · lower section | <img src="before/polish-deposit-ar-393-s1.0-d3.0-bottom.png" width="260" alt="Before Deposit · lower section"> | <img src="after/polish-deposit-ar-393-s1.0-d3.0-bottom.png" width="260" alt="After Deposit · lower section"> |
| Create · lower section | <img src="before/polish-create-ar-393-s1.0-d3.0-bottom.png" width="260" alt="Before Create · lower section"> | <img src="after/polish-create-ar-393-s1.0-d3.0-bottom.png" width="260" alt="After Create · lower section"> |
| Levels · 280dp / 2× text | <img src="before/polish-levels-ar-280-s2.0-d2.0.png" width="260" alt="Before Levels · 280dp / 2× text"> | <img src="after/polish-levels-ar-280-s2.0-d2.0.png" width="260" alt="After Levels · 280dp / 2× text"> |
| Deposit · 280dp / 2× text | <img src="before/polish-deposit-ar-280-s2.0-d2.0-bottom.png" width="260" alt="Before Deposit · 280dp / 2× text"> | <img src="after/polish-deposit-ar-280-s2.0-d2.0-bottom.png" width="260" alt="After Deposit · 280dp / 2× text"> |
| Notifications · 280dp / 2× text | <img src="before/polish-notifications-ar-280-s2.0-d2.0.png" width="260" alt="Before Notifications · 280dp / 2× text"> | <img src="after/polish-notifications-ar-280-s2.0-d2.0.png" width="260" alt="After Notifications · 280dp / 2× text"> |
| Sidebar | <img src="before/chrome-sidebar-393-s1.0-d3.0.png" width="260" alt="Before Sidebar"> | <img src="after/chrome-sidebar-393-s1.0-d3.0.png" width="260" alt="After Sidebar"> |
| App bar and navigation | <img src="before/chrome-chrome-393-s1.0-d3.0.png" width="260" alt="Before App bar and navigation"> | <img src="after/chrome-chrome-393-s1.0-d3.0.png" width="260" alt="After App bar and navigation"> |
| Edit profile | <img src="before/chrome-edit-393-s1.0-d3.0.png" width="260" alt="Before Edit profile"> | <img src="after/chrome-edit-393-s1.0-d3.0.png" width="260" alt="After Edit profile"> |
| Tools | <img src="before/ui-tools-393-s1.0-d3.0.png" width="260" alt="Before Tools"> | <img src="after/ui-tools-393-s1.0-d3.0.png" width="260" alt="After Tools"> |
| History | <img src="before/ui-history-393-s1.0-d3.0.png" width="260" alt="Before History"> | <img src="after/ui-history-393-s1.0-d3.0.png" width="260" alt="After History"> |
| Receipt | <img src="before/ui-receipt-393-s1.0-d3.0.png" width="260" alt="Before Receipt"> | <img src="after/ui-receipt-393-s1.0-d3.0.png" width="260" alt="After Receipt"> |

### New activation notice

New feature; no fabricated before image. Actual component at 393dp, production font, with fictional campaign text.

| Sorani | Arabic | Badini |
|---|---|---|
| <img src="after/polish-activation-ckb-393-s1.0-d2.0.png" width="260" alt="Activation notice ckb"> | <img src="after/polish-activation-ar-393-s1.0-d2.0.png" width="260" alt="Activation notice ar"> | <img src="after/polish-activation-kmr-393-s1.0-d2.0.png" width="260" alt="Activation notice kmr"> |


### Native Android examples

Actual API 35 emulator captures, using fictional read-only data. Debug ribbons identify the fixture build. The app-bar/navigation fixtures deliberately have an empty body to isolate chrome; these are not incomplete Home screens.

| Phone profile · 393dp / 1× text | Narrow navigation · 280dp / 2× text | Tablet chrome · 768dp / 1× text |
|---|---|---|
| <img src="native/phone-profile-scale-1.0.png" width="260" alt="Native phone Profile"> | <img src="native/narrow-chrome-native-scale-2.0-adb.png" width="260" alt="Native narrow large-text navigation"> | <img src="native/tablet-chrome-native-scale-1.0-adb.png" width="360" alt="Native tablet app bar and navigation"> |


## Changed files and remaining verification boundaries

See `changed-files.txt` for the complete follow-up file list relative to `74beaa8bc06c7c3c13185d9d0e01bd7078e455bc`. Application assets added: the 34 SVGs plus `SOURCES.json` and `LICENSE.md`; `pubspec.yaml` registers the local folder. No dependency version or lockfile change is required for these additions.

Main integration points: `widgets/proxo_symbol.dart`, shared auth widgets, `screens/auth/*`, `theme/app_locale.dart`, `l10n/*`, sidebar/profile/bottom-nav/app-bar widgets, Home/banner/results, ads/creation/deposit/notifications, secondary pages and `widgets/ad_activation_notice.dart`. Security migration and isolated tests are included. `docs/` PNGs are evidence only and are not bundled in the application.

Physical Android performance profiling, TalkBack review, real account/payment/FCM end-to-end checks and native linguistic review remain release validation boundaries. Existing unrelated ProxoLink WebView parity findings are not claimed resolved by this icon/UI work. PR stays a draft; production is unchanged.
