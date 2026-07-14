# PhotoCurator AI

PhotoCurator AI is a Flutter app for private, on-device photo cleanup. The in-app product is branded as Curate and is designed as a monetizable iOS-first product with a free scan tier and Pro cleanup tools.

The current build supports focused scans for similar photos, screenshots, and large photos; recent or album-based scopes; resumable sessions; visual review and zoom; native delete confirmation; demo data; and Pro gating. StoreKit/RevenueCat and final store assets remain release work.

## Product USPs

- On-device photo hashing, so the library does not need to leave the phone.
- Smart keeper recommendations based on resolution, file size, and recency.
- Compare-and-zoom duplicate review with keeper recommendations.
- Screenshot and large-photo review with deliberate selection and storage totals.
- Persisted cleanup sessions and cancellable scan progress.
- Pro-tier gates for larger scans and batch cleanup.
- iOS-ready Photos permissions and native delete confirmation via `photo_manager`.
- Privacy-first positioning for the current storage-cleanup / AI-assisted organization market.

## Run and Bundle on a Mac

1. Install Flutter and Xcode, then run `flutter doctor`.
2. Unzip the project and run `flutter pub get`.
3. Run `flutter run -d ios` for Simulator or a connected iPhone.
4. Run `flutter test` before each bundle.
5. Build iOS with `flutter build ipa --release`, or open `ios/Runner.xcworkspace` in Xcode to archive and upload.
6. For App Store work, set your signing team, app icon, screenshots, privacy labels, and StoreKit products.

See `RELEASE_CHECKLIST.md` for the remaining store and signing steps.

For developer testing with Pro enabled, run:

```sh
flutter run --release --dart-define=DEV_PRO_UNLOCK=true -d <device-id>
```

## Monetization Next Steps

- Replace the demo Pro unlock in `lib/screens/home_screen.dart` with StoreKit 2, RevenueCat, or your preferred purchase SDK.
- Create subscription products such as monthly Pro, annual Pro, and lifetime unlock.
- Add App Store screenshots from the demo data path before shipping.
