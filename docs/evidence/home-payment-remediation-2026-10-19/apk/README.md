# APK verification — Proxo 1.0.11

Passed validation of `Proxo-1.0.11-complete-ui.apk`, built by successful Verify ProxoLink run **39391606925**, artifact **12250317662**.

Source commit: `ade200a23732cb5029087e1a6ccac0036f1161b9`  
Source and CI merge tree: `35ed6cc439c5e431a474085e04395e014bc94b13` ([tree proof](../ci-source-proof.json)).

| Check | Result |
| --- | --- |
| Package / version | `com.proxo.proxoapp` / `1.0.11+11` |
| Size | 93,142,023 bytes |
| Android minimum / target SDK | 24 / 36 |
| APK signature | Valid, APK Signature Scheme v2 |
| Release debugging | `android:debuggable` disabled |
| Bundled project assets | All 185 byte-identical to the exact source commit |
| New SVG controls | All four required icons present |
| Page previews | All 12 PNG thumbnails present |
| Notification / splash | Four native brand resources retained; two PNGs pixel-identical to source |
| Private page templates | No bundled template directory or known private template markers |
| Native test hooks | Known fixture classes, channels and markers absent from DEX / manifest |
| Synthetic staging configuration | All three known markers absent from every uncompressed APK member, including native libraries and Dart AOT |
| ZIP integrity | Passed |

APK SHA-256:

```text
65d805e69d09eddf24bfc5c449972fed0274c9c63095ae7c8795d3d962e2eda7
```

GitHub artifact ZIP SHA-256, verified before extraction:

```text
de8d7a4a70b12092c7d5e541e9998d17849e4f0cd7b2c87fd5b6944653d543cb
```

## Signing compatibility

This release-mode APK has a valid **Android Debug** signing certificate:

```text
0c4f0aeb6ba5965626e2275b90cedabec8680d572d48eca8e421649a5155d04b
```

It differs from the previously delivered 1.0.9 APK certificate (`3144bab4cbae464f194dd01ff2ce29b42e854395ced26811b02c8aaf66c1b728`). Android therefore cannot install this APK as an in-place update over that earlier APK. A production update requires the established signing key. This verification did not install, resign or modify the APK.

## Evidence and limits

- [Machine-readable verification and complete asset inventory](apk-verification.json)
- [Signature verification output](signature.txt)
- [Package metadata](badging.txt)
- [Decoded Android manifest](manifest.txt)
- [42 passing native UI scenarios](../native/README.md)

The archive scans check the listed exact markers; they do not prove the absence of every possible secret or arbitrary unwanted code. Runtime evidence comes from the separate profile-mode native workflow using the same product source. The delivered release APK was inspected as an archive, not exercised on a physical device.
