# Original before / after screenshots

Baseline `e24575c135ca599a6775bd66e385d3b8033b7e92`. Candidate `e2571ea7507ac1e9103b818fc178e189802a5461`. Same bundled-font capture harness; real widgets and fictional data. Click an image for its original pixels. Narrow navigation scrolls horizontally at large text size.

| Surface | Before | After |
|---|---|---|
| login-ckb-393-s1.0-d3.0 | ![Before](before/login-ckb-393-s1.0-d3.0.png) | ![After](after/login-ckb-393-s1.0-d3.0.png) |
| signup-ckb-393-s1.0-d3.0 | ![Before](before/signup-ckb-393-s1.0-d3.0.png) | ![After](after/signup-ckb-393-s1.0-d3.0.png) |
| forgot-ckb-393-s1.0-d3.0 | ![Before](before/forgot-ckb-393-s1.0-d3.0.png) | ![After](after/forgot-ckb-393-s1.0-d3.0.png) |
| otp-ckb-393-s1.0-d3.0 | ![Before](before/otp-ckb-393-s1.0-d3.0.png) | ![After](after/otp-ckb-393-s1.0-d3.0.png) |
| home-ckb-393-s1.0-d3.0 | ![Before](before/home-ckb-393-s1.0-d3.0.png) | ![After](after/home-ckb-393-s1.0-d3.0.png) |
| deposit-ckb-393-s1.0-d3.0 | ![Before](before/deposit-ckb-393-s1.0-d3.0.png) | ![After](after/deposit-ckb-393-s1.0-d3.0.png) |
| profile-ckb-393-s1.0-d3.0 | ![Before](before/profile-ckb-393-s1.0-d3.0.png) | ![After](after/profile-ckb-393-s1.0-d3.0.png) |
| navigation-ckb-393-s1.0-d3.0 | ![Before](before/navigation-ckb-393-s1.0-d3.0.png) | ![After](after/navigation-ckb-393-s1.0-d3.0.png) |
| login-ckb-280-s2.0-d2.0 | ![Before](before/login-ckb-280-s2.0-d2.0.png) | ![After](after/login-ckb-280-s2.0-d2.0.png) |
| signup-ckb-280-s2.0-d2.0 | ![Before](before/signup-ckb-280-s2.0-d2.0.png) | ![After](after/signup-ckb-280-s2.0-d2.0.png) |
| home-ckb-280-s2.0-d2.0 | ![Before](before/home-ckb-280-s2.0-d2.0.png) | ![After](after/home-ckb-280-s2.0-d2.0.png) |
| deposit-ckb-280-s2.0-d2.0 | ![Before](before/deposit-ckb-280-s2.0-d2.0.png) | ![After](after/deposit-ckb-280-s2.0-d2.0.png) |
| profile-ckb-280-s2.0-d2.0 | ![Before](before/profile-ckb-280-s2.0-d2.0.png) | ![After](after/profile-ckb-280-s2.0-d2.0.png) |
| login-ar-280-s2.0-d2.0 | ![Before](before/login-ar-280-s2.0-d2.0.png) | ![After](after/login-ar-280-s2.0-d2.0.png) |
| login-kmr-280-s2.0-d2.0 | ![Before](before/login-kmr-280-s2.0-d2.0.png) | ![After](after/login-kmr-280-s2.0-d2.0.png) |
| deposit-ckb-393-s1.0-d3.0-bottom | ![Before](before/deposit-ckb-393-s1.0-d3.0-bottom.png) | ![After](after/deposit-ckb-393-s1.0-d3.0-bottom.png) |
| profile-ckb-393-s1.0-d3.0-bottom | ![Before](before/profile-ckb-393-s1.0-d3.0-bottom.png) | ![After](after/profile-ckb-393-s1.0-d3.0-bottom.png) |
| signup-ckb-280-s2.0-d2.0-bottom | ![Before](before/signup-ckb-280-s2.0-d2.0-bottom.png) | ![After](after/signup-ckb-280-s2.0-d2.0-bottom.png) |
| home-ckb-280-s2.0-d2.0-bottom | ![Before](before/home-ckb-280-s2.0-d2.0-bottom.png) | ![After](after/home-ckb-280-s2.0-d2.0-bottom.png) |

## Overlapping feedback

Both styles use overlapping layers. Only the front message accepts interaction. Create Ad grants each newly visible front message its own five-second reading period.

| General error | Create Ad validation |
|---|---|
| ![Errors](after/error-stack-393.png) | ![Create Ad](after/ad-validation-stack.png) |

![Large-text error](after/error-stack-280.png)

## Actual Android examples

These are unmodified emulator debug screenshots; the debug ribbon is retained. Flutter-surface phone captures exclude the OS keyboard surface, while typed input and controller values are checked by the native test. At 2× text a focused phone field scrolls horizontally to its caret; the stored normalized number remains complete.

| Home — phone | Payment marks — phone | Profile — phone |
|---|---|---|
| ![Native Home](native/phone-home-scale-1.0.png) | ![Native deposit](native/phone-deposit-scale-1.0.png) | ![Native Profile](native/phone-profile-scale-1.0.png) |

| Narrow phone entry, 2× text | Tablet navigation, 2× text — raw ADB capture |
|---|---|
| ![Native phone field](native/narrow-auth-phone-scale-2.0.png) | ![Tablet navigation](native/tablet-chrome-native-scale-2.0-adb.png) |

[All 111 native screenshots indexed by original dimensions and SHA-256](native-image-index.json) · [Measured device and interaction observations](native-measurements.json).
