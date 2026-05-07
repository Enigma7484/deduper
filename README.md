# PhotoCurator AI

PhotoCurator AI is a Flutter app for private, on-device duplicate and similar photo cleanup. It is designed as a monetizable iOS-first product with a free scan tier and Pro upgrade surface.

## Product USPs

- On-device photo hashing, so the library does not need to leave the phone.
- Smart keeper recommendations based on resolution, file size, and recency.
- Review queue with confidence, estimated storage savings, and keeper-first UX.
- Pro-tier gates for larger scans and batch cleanup.
- iOS-ready Photos permissions and native delete confirmation via `photo_manager`.

## Run on a Mac

1. Install Flutter and Xcode.
2. Unzip the project and run `flutter pub get`.
3. Run `flutter run -d ios` for Simulator or a connected iPhone.
4. For App Store work, open `ios/Runner.xcworkspace` in Xcode and set your bundle id, signing team, app icon, and StoreKit products.

## Monetization Next Steps

- Replace the demo Pro unlock in `lib/screens/home_screen.dart` with StoreKit 2, RevenueCat, or your preferred purchase SDK.
- Create subscription products such as monthly Pro, annual Pro, and lifetime unlock.
- Add App Store screenshots from the demo data path before shipping.
