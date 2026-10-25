# Point-by-point acceptance

The scope is implemented and tested locally where indicated. **Production is not accepted or released.** See [full report](README.md), [test record](verification.json), [gallery](screenshots.md) and [icon provenance](icons.md). Fixture success is not live provider success.

| Point | Requirement | Status / evidence |
|---|---|---|
| 1 | PRIMARY GOAL | Implemented shared design; overall release blocked by point 68. |
| 2 | VISUAL BASELINE | Shared Create Ad palette/roles/geometry; reviewed gallery. |
| 3 | PIXEL-BY-PIXEL REQUIREMENT | Measured layout/pixel checks plus 31 side-by-side sheets; native release acceptance pending. |
| 4 | SHARED TYPOGRAPHY SYSTEM | ProxoDesign typography roles shared by themes/components. |
| 5 | TYPOGRAPHY VISUAL TARGET | 18/16/15/14/13sp roles; RabarAuthRegular, controlled weights. |
| 6 | SHARED SPACING SYSTEM | 20/16/32/12dp shared spacing. |
| 7 | VISUAL RHYTHM RULE | Open section rhythm in Create Page, Home and Profile; gallery reviewed. |
| 8 | SHARED CONTROL GEOMETRY | 56dp fields, 50dp buttons, 12dp control radius; responsive growth. |
| 9 | SHARED COLOR SYSTEM | Shared white/ink/gray/blue/pale-blue palette. |
| 10 | IMPORTANT PRIMARY SELECTION CONTROLS | Primary blue/white active selections; strict ad tests. |
| 11 | SECONDARY RESOURCE / DESTINATION CONTROLS | Pale secondary resource selections; rendered pixel sampling. |
| 12 | PNG ICON SYSTEM — CRITICAL | 22 original local PNGs; Profile/Menu/Home and relevant empty/update states. |
| 13 | PNG ICON SOURCE REQUIREMENT | Per-icon original source/download/license/hash documented in icons.md. |
| 14 | LOCAL PNG ASSETS ONLY FOR THESE UI ICONS | Bundled assets registered in pubspec; decoded image assertions. |
| 15 | DO NOT USE RANDOM GENERIC MATERIAL ICONS | Semantic artwork selected for each main section; no random replacements. |
| 16 | PNG ICON VISUAL NORMALIZATION | Measured alpha bounds normalize visible 22dp ink inside 24dp box. |
| 17 | PNG ICON SIZE SYSTEM | 24dp normal/28dp Home; reviewed against labels. |
| 18 | ICON + TEXT ALIGNMENT | 12dp icon gap and RTL placement; native drawer checks scheduled. |
| 19 | ICON BACKGROUND | Transparent artwork with quiet wells only where appropriate. |
| 20 | ICON LICENSING / ATTRIBUTION | Original-source license and provenance retained; see icons.md. |
| 21 | CREATE PAGE — MATCH CREATE AD | White open Create Page layout and shared AppBar/form roles. |
| 22 | CREATE PAGE MUST FULLY WORK | Fixture API/recovery/ownership/restart tests pass; live API save/reopen BLOCKED. |
| 23 | CREATE PAGE FROM CREATE AD | Direct Back to existing Create Ad route tested. |
| 24 | CREATE PAGE SUCCESS RETURN | Authoritative-save return/new-page refresh/state preservation tested with fixtures. |
| 25 | HOME SCREEN — MATCH CREATE AD | Shared Home typography/palette/gutters/PNG shortcuts. |
| 26 | HOME GRADIENT BANNER | Blue gradient hero responsive to width and text scale. |
| 27 | HOME BANNER CONTENT | Real Create Ad CTA; existing announcements preserved; no fake stats. |
| 28 | HOME BANNER ICON | Hero is text/CTA; no decorative icon or emoji needed. |
| 29 | HOME BEST RESULTS | Compact Home card preserved; detailed cards stay on dedicated screen. |
| 30 | HOME BEST RESULTS THUMBNAIL BUG | Ad-ID/URL image key and stale-frame reset; late image race tested. |
| 31 | THUMBNAIL FALLBACK | Approved Proxo fallback for missing/invalid/failed/pending image. |
| 32 | BEST RESULTS SCREEN | Dedicated expandable cards; numeric large-text wrapping fixed. |
| 33 | PROFILE — MATCH CREATE AD | Shared Profile AppBar/rows/groups/spacing/colors. |
| 34 | PROFILE PNG ICONS | Profile semantic PNG family; source and bounds documented. |
| 35 | MENU / SIDEBAR PNG ICONS | Menu same PNG family and RTL alignment; selected state reviewed. |
| 36 | AUTH — SAME TYPOGRAPHY | Auth shared Rabar typography and geometry. |
| 37 | AUTH COLORS | Auth aliases shared palette. |
| 38 | SIGN-UP BY MOBILE NUMBER ONLY | Phone-only signup/OTP flow implemented/tested; real delivery pending. |
| 39 | PHONE NORMALIZATION | Canonical Iraqi normalization including local/+964/non-Latin digits tested. |
| 40 | ERROR MESSAGES — MANUAL CLOSE | Manual close, 48dp target, RTL notice placement. |
| 41 | ERROR AUTO-DISMISS | 2s short/3s long transient notice; actionable notices sticky. |
| 42 | ERROR STATE RECOVERY | Editable-form/timer/retry/request-generation recovery tests pass. |
| 43 | TIKTOK CONNECTION QA | Fixture isolation/connect/video/reconnect tests pass; live provider verification BLOCKED. |
| 44 | CREATE ADVERTISEMENT FUNCTIONAL QA | Complete fixture form/submission suite passes; live paid/provider actions BLOCKED. |
| 45 | PRICE BREAKDOWN — APPROVED DESIGN | Long rectangular card with app margins, upward expansion and separate Sponsor. |
| 46 | PRICE CARD COLLAPSED | Total/value/icon only; no disclosure text. |
| 47 | PRICE CARD EXPANDED | Base/service/conditional discount/divider/total rows measured. |
| 48 | PRICE CARD GEOMETRY | 20dp margins, 10dp radius, compact 64dp normal collapsed row. |
| 49 | PRICE LOADING | Stable geometry and pending/error amount states use authoritative result. |
| 50 | SPONSOR BUTTON | Sponsor separate in scrollable form; assertions and screenshots. |
| 51 | APP-WIDE EMPTY STATES | Consistent ads/pages/results empty states and relevant CTA. |
| 52 | APPBAR CONSISTENCY | Shared adaptive AppBars; Home/Ads keep matching logo top bar. |
| 53 | UPDATE DELIVERY FOR EXISTING USERS | Checker implemented; pre-checker binaries require a store/distribution bridge update. |
| 54 | OPTIONAL UPDATE | Update/Later and 24h revision/build-keyed deferral tested. |
| 55 | REQUIRED UPDATE | Required root gate tested; no enabled production policy or minimum. |
| 56 | UPDATE UI DESIGN | Shared PNG/blue/spacing/type update UI across full matrix. |
| 57 | BACKWARD COMPATIBILITY | Additive schema/client compatibility tests pass; live old-client smoke tests pending. |
| 58 | PRODUCTION MIGRATION ORDER | Page + disabled update schema applied and verified; provider/finance migrations pending. |
| 59 | RELEASE ORDER | Release intentionally stopped before deployment/distribution; blockers documented. |
| 60 | FULL BUTTON QA | Major control behavior tests pass; live external actions pending provider access. |
| 61 | NAVIGATION QA | Navigation behavior and lifecycle tests pass; native CI on final source pending. |
| 62 | DATA ISOLATION | Owner/cache/draft/provider isolation negative tests pass; live multi-account acceptance pending. |
| 63 | PERFORMANCE | Local bundled assets, no new expensive effects; native profile metrics pending. |
| 64 | SCREENSHOT REQUIREMENT | 224 fresh PNGs with manifests and fixture labeling; native CI artifacts separate. |
| 65 | SCREENSHOT SIDE-BY-SIDE REVIEW | 31 side-by-side sheets manually reviewed; corrections documented. |
| 66 | DEVICE MATRIX | 393/320/280dp and large-text widget matrix passes; physical device unavailable. |
| 67 | DO NOT RELY ONLY ON AUTOMATED TESTS | Tests plus manual visual review performed; backend/provider readiness remains distinct. |
| 68 | FINAL ACCEPTANCE CHECKLIST | NOT COMPLETE FOR PRODUCTION: unresolved gates are listed in report item 28. |
| 69 | FINAL REPORT REQUIRED | This README provides all 28 requested report categories with evidence. |
