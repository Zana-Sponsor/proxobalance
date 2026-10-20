# Visual review — 20 October 2026

Source: [`9fdd08d`](https://github.com/Zana-Sponsor/proxobalance/commit/9fdd08d14f982e40221455cc4ab5dac0f3c368e3).

The gallery contains **155 actual production-widget screenshots**, each paired with widget geometry. All **42 capture scenarios passed** on the final source. Both viewports load the full bundled font manifest: 393 × 852dp at 100% text and 320 × 740dp at 200% text. No layout exception was recorded in any capture.

The screen collection was reviewed in overview sheets, with individual full-size inspection of representative Home, thumbnail, Profile, Pages, Ads, payment, menu and dialog states. All seven exported PDF pages were inspected individually. Geometry files provide the actual bounds and fonts behind the screenshots; they are not proposed design measurements.

Two findings from the visual pass were corrected and recaptured:

- The edit-profile camera badge intersected its circular parent clip. Moving the 32dp badge to a 12dp inset keeps its full circle inside the 96dp parent. The new screenshot shows the complete badge; a geometry assertion covers the placement.
- The first receipt “middle” capture used a lazy list’s estimated scroll extent and repeated the bottom. The harness now lays out the entire list before taking overlapping intermediate captures. The narrow receipt’s budget section is visibly present and asserted to lie within the viewport. This was an evidence-coverage issue; all receipt pixels were already retained by the PDF export.

The Home card is also captured after scrolling it into view in its collapsed state, so 200% text does not leave that state outside the initial screenshot. Expanded details remain in the same card. Missing and deliberately failed thumbnails use the same shared Proxo fallback; the successful image is a real bundled JPEG used as a fictional creative.

The OTP keyboard view focuses and reveals the real input, then asserts its full bounds remain above a simulated 300dp keyboard inset. Flutter widget tests do not render the Android keyboard bitmap. At 200% text the dialog content scrolls, while its actions remain reachable. Native keyboard evidence is a separate check.

The Profile long-name fixture wraps Kurdish and Latin content; missing optional data has a deliberate placeholder. Shared Pages and Advertisements states distinguish empty, loading and failed reads. The small-screen payment and menu content scrolls, and their final actions are captured separately. The existing Advertisements filter strip retains its legacy text-scale cap; the new empty/error panels honor 200%.

This review does not establish physical-device frame rates, live payment success, production page persistence, FCM delivery or email delivery. The Pages creation journey saves only to an in-memory repository; the email dialog uses a strict mocked custom API client. Payment recipient numbers are the app’s existing configuration and no transfer was made. See the linked readiness reports in the [gallery](README.md) for deployment limits.
