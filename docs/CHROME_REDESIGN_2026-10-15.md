# Sidebar, profile, navigation and app bar

Requested follow-up: use external icons, harmonize typography/size, correct observed layout/navigation/performance issues, and publish actual screenshots. Baseline is `e61144904f5f9986b8d3a2f486ca7756a3ba267a`. PR remains a draft; production is unchanged.

## Implementation

| Surface | Before | Change |
|---|---|---|
| Sidebar | Solar Linear SVG; width shrank to 78%; fonts scaled down; home always selected | Existing Solar Outline font, wider panel up to 336dp, 24dp icons, 14sp wrapping labels, current tab selection |
| Sidebar loading | Profile waited for three unused loyalty reads and unread query | Profile appears after its own query; removed unused points/levels reads; unread fetch independent of identity display; signed-out loading completes |
| Sidebar routes | Home/help only closed the drawer | Home selects tab 0; help opens existing FAQ; settings retains profile route |
| Profile | Tight fixed quick cards/balance, text scale capped at 1.05, perpetual shine | Natural-height balance, explicit top-up control, responsive quick cards, full system text scale, no perpetual shine |
| Profile labels | Tools named “materials”; single-line truncation | “ئامرازەکان” matches navigation; wrapping names/menu labels; consistent blue and rounded surfaces |
| Bottom navigation | PNG pairs, custom plus, 11.5sp shrunk labels | Solar Outline home2/clapperboardPlay/widget_2/userRounded; Solar Bold addCircle; 24dp tab icons, 12sp labels; active blue capsule; 48dp minimum targets |
| Large-text navigation | Labels shrunk with FittedBox | Measured labels retain system size; horizontal scrolling only when five readable tabs cannot fit; selected tab brought into view |
| App bar | Mixed hand-drawn/Material icons, 36dp buttons, bell target only21dp | Solar hamburgerMenu/bell/magnifier/altArrowRight; 24dp glyphs; 48dp actions; 56dp bar; 24dp logo; descriptive semantics/tooltips |
| Notification motion | Infinite unread pulse | One pulse on count update; respects reduced motion |

No package/version change, icon download, runtime icon website, or new image asset. Uses the existing bundled `solar_icons: 0.1.0` font. Existing home quick actions remain icons and Sorani labels without images. Original raster assets remain available for untouched consumers; no unrelated template/payment/backend redesign.

## Icon source and licenses

- Package: https://pub.dev/packages/solar_icons — BSD-3-Clause, © 2023 Sebastine Odeh; license retained in the dependency and `docs/SOLAR_ICON_LICENSE.txt`.
- Original artwork: Solar Icons by 480 Design, https://www.figma.com/community/file/1166831539721848736 . Original artwork attribution under CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ . Attribution visible in Profile → About. Icons resized/recolored; paths not modified.
- Collection third-party notice checked: https://github.com/saoudi-h/solar-icons/blob/main/LICENSE-THIRD-PARTY . The separate solar_iconkit wrapper reports MIT; this change uses solar_icons, and does not assume that a wrapper's license replaces artwork attribution.

## Verification

Pending hosted execution and screenshot review. `chrome_capture_test.dart` renders real production widgets at 280/393/768dp, DPR1/2/3, text1/2 with read-only fictional profile/wallet fixtures and locally loaded actual fonts. It checks callbacks, 48dp targets, visibility toggle, home navigation, and absence of the removed loyalty requests. Same capture harness runs on immutable baseline. Native suite extends existing Android checks with profile/sidebar/app-bar captures at text1/2 on three configurations. Screenshots are review evidence, not approved goldens.

Removing unused reads and idle animation is a concrete reduction in work, not a measured physical-device FPS/latency claim. Real account/payment flows, physical TalkBack/profile performance and earlier unrelated WebView strict parity blockers remain outside this focused verification.
