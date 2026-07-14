# PhotoCurator AI Release Checklist

## Local Toolchain

- Install Flutter on the Mac and make sure `flutter` is on `PATH`.
- Install Xcode from the App Store, open it once, and accept any license prompts.
- Run `flutter doctor -v` from this repo until iOS toolchain issues are clear.
- Run `flutter pub get` and `flutter test`.

## iOS App Store Bundle

- Confirm bundle id: `com.photocuratorai.app`.
- Set the Apple Developer Team in `ios/Runner.xcworkspace`.
- Replace the default app icon with final PhotoCurator AI artwork.
- Add StoreKit products for monthly, annual, and lifetime Pro.
- Replace the release-disabled demo Pro unlock in `lib/screens/home_screen.dart` with StoreKit 2, RevenueCat, or another purchase SDK.
- Build with `flutter build ipa --release` or archive from Xcode.
- Complete App Store privacy nutrition labels around photo library access and on-device processing.

## Android Bundle

- Create a Play upload keystore outside the repo.
- Create `android/key.properties` locally with:

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

- Build with `flutter build appbundle --release`.

## Product Polish Before Paid Traffic

- Capture App Store screenshots from the demo data state and one real-device scan.
- Decide pricing copy for the Pro sheet before connecting purchase products.
- Add a short privacy policy page that states photo analysis happens on device.
- Test limited-library access, denied access, scan cancellation by leaving the screen, and native delete confirmation on a physical iPhone.

## Market Positioning Notes

- Lead with private, on-device cleanup. Current competing cleaners such as [PicDeDupe](https://apps.apple.com/ng/app/picdedupe-smart-photo-cleaner/id6764617074) and [PhotoDedup](https://apps.apple.com/kw/app/photodedup-duplicate-cleaner/id6756860088) both foreground on-device AI and privacy.
- Add screenshot, blurry-photo, and oversized-video cleanup next. These are common App Store promises in adjacent products such as [Photo Cleaner: Swipe Cleanup](https://apps.apple.com/us/app/photo-cleaner-swipe-cleanup/id6746700862).
- Consider a lifetime unlock alongside monthly and annual Pro. User sentiment around cleaner apps often pushes back against aggressive weekly subscriptions, so a simpler paid option can be a differentiator.
- Keep the AI language concrete: smart grouping, keeper recommendations, cleanup trends, and private insights. Broad mobile trend coverage in 2026 continues to emphasize on-device AI and trust-sensitive personalization.
