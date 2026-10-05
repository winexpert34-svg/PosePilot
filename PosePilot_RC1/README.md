# PosePilot 1.0 RC1
**Your Personal AI Photographer**

Creator: Dmitrijs Zigilijs

This release-candidate source combines the camera, local ML Kit pose stream,
30-pose library, PoseMatcher, stability gate, Ghost overlay, AI Photographer
session engine, persistent gallery service, preferences and a premium entitlement
boundary.

## What is real in this source
- Camera preview and photo capture code
- ML Kit streaming pose detector integration
- Normalized pose-frame/matching logic
- 30 target poses
- Stability-gated Perfect state
- Auto/manual capture flow
- AI session progression
- Ghost overlay
- Persistent shot-path store
- Preferences and entitlement abstractions
- Core unit tests

## What still cannot be certified here
This environment has no Flutter/Dart SDK, Android toolchain, Xcode, signing
certificates or physical devices. Therefore this archive is **not** claimed to
be a tested APK/IPA or App Store/Play Store release.

See `docs/STORE_RELEASE_GATES.md`.
