# PosePilot 1.0 — Store release gates

The source package is an RC, not a signed store binary.

Required outside this environment:
- Generate/refresh Flutter Android and iOS host projects with the installed Flutter SDK.
- Run `flutter pub get`, `flutter analyze`, `flutter test`.
- Test ML Kit pose streaming on supported Android devices.
- Test camera orientation/mirroring and Vision/ML Kit behavior on iPhone.
- Replace local entitlement stub with StoreKit 2 and Google Play Billing plus verification.
- Add App Store privacy manifest and Play Data Safety declarations.
- Configure signing, bundle/application IDs, icons, screenshots and store metadata.
- Run crash, thermal, battery, accessibility and low-light tests.
- Validate Intimate Mode age gate before enabling that feature publicly.

Release acceptance:
1. Camera opens reliably after permission grant/denial/regrant.
2. Pose analysis remains responsive during a 20-shot session.
3. Perfect requires stable high-confidence matching.
4. Auto shutter fires once per target pose.
5. Gallery survives app restart.
6. No continuous raw-video upload.
7. Purchases restore correctly on both stores.
