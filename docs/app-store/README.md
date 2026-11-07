# App Store listing

What's entered in [App Store Connect](https://appstoreconnect.apple.com) for **One or Many** (app ID 6831969881,
bundle ID `io.github.davidlago.OneOrMany`). Keep it in step with the app and [docs/SPEC.md](../SPEC.md).

The text fields live in [listing.json](listing.json): name, subtitle, URLs, copyright, categories, keywords,
promotional text, description and the App Review notes. `scripts/app-store-metadata.swift` sends them to App Store
Connect with the API key, together with the screenshots, for the version being prepared:

```bash
swift scripts/app-store-metadata.swift ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8 <key ID> <issuer ID>
```

## Screenshots

`scripts/screenshots.sh` takes them from the iPhone 18 Pro simulator (1206 × 2622) into `iphone-6.3/`, the
"iPhone with Dynamic Island (medium display)" set that App Store Connect scales for every iPhone. A Debug build runs
in screenshot mode (`OneOrMany/App/ScreenshotMode.swift`): sample progress in memory, the status bar at 9:41, one
frozen moment per scene. In order: a card mid-swipe toward MANY, a miss with the correction swipe, a streak of 10,
the round summary, Home, the Journey map, Stats.

`DEVICE="iPhone 18 Pro Max" OUT=docs/app-store/iphone scripts/screenshots.sh` makes the optional 6.9-inch set
(1320 × 2868).

## App information (set by the script)

| Field | Value |
|---|---|
| Name | One or Many |
| Subtitle | Is or are? Swipe it fast |
| Category | Education; secondary Games (Word, Educational) |
| Privacy policy URL | https://davidlago.github.io/singular-or-plural/privacy.html |
| Support URL | https://davidlago.github.io/singular-or-plural/support.html |
| Marketing URL | https://davidlago.github.io/singular-or-plural/ |
| Copyright | 2026 Dave Lago |

The subtitle can only change with a new version.

## Set on the website

The API can't set these, so they're entered in App Store Connect by hand:

| Field | Value |
|---|---|
| Age rating | 4+: every question answered None or No (no web access, no user-generated content shared with others, no ads, no purchases) |
| Kids Category | Not opted in. The app suits children, but the Kids Category adds requirements (parental gates and more) that it doesn't need: it has no links, purchases or ads |
| Content rights | Doesn't contain, show or access third-party content |
| Price | Free, all territories |
| App Privacy | **Data Not Collected** |
| App Review contact | your name, phone and email |
| Sign-in required | No |

**Why "Data Not Collected":** the app has no networking code at all. Answers, scores, the Parent corner PIN and added
sentences are stored only on the device (SwiftData and UserDefaults in the app's container). Nothing leaves the phone,
so nothing is "collected" in Apple's sense. No tracking, no ads, no analytics. Export compliance:
`ITSAppUsesNonExemptEncryption = NO`.

## Version text

Promotional text, keywords and description: see [listing.json](listing.json). Promotional text can change at any
time without review; the description and keywords change with a new version.

## Submitting

1. Tag a release (`git tag v1.0.0 && git push origin v1.0.0`): CI uploads that version to TestFlight.
2. When the build has processed, run the metadata script (it also selects the newest processed build for the
   version), then check the website-only fields above.
3. In App Store Connect ▸ the version ▸ **Add for Review**, then **Submit to App Review**.
