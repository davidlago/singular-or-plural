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

## Header and search results (creative assets)

`scripts/make-creative-assets.swift` draws them into `creative/` (opaque PNGs, key content centered):

- `header.png`, 3840 × 1646 (21:9), product page header: a card mid-swipe between Solo with "is" and the Crew
  with "are".
- `search.png`, 3840 × 2560 (3:2), search results: "Is or are? Swipe it fast." next to two real screenshots (it
  reads `iphone-6.3/`, so run `scripts/screenshots.sh` first).

They're uploaded to the **Asset Library** and sit in a draft submission. Apple only takes a standalone asset
submission once the app has a live version, so after 1.0.0 is released: Asset Library ▸ Draft Submissions ▸
**Submit for Review**. Once they're approved: the live version ▸ Header and Search Results ▸ Header (then Search
Results) ▸ **Browse Assets**, pick the asset, **Publish**. No new app version is needed. They show on iOS 27 and
later.

## App information (set by the script)

| Field | Value |
|---|---|
| Name | One or Many |
| Subtitle | Is or are? Swipe it fast |
| Category | Education; secondary Games (Word) |
| Privacy policy URL | https://davidlago.github.io/singular-or-plural/privacy.html |
| Support URL | https://davidlago.github.io/singular-or-plural/support.html |
| Marketing URL | https://davidlago.github.io/singular-or-plural/ |
| Copyright | 2026 Dave Lago |

The subtitle can only change with a new version.

## Set on the website

The API can't set these, so they're entered in App Store Connect by hand:

| Field | Value |
|---|---|
| Age rating | 4+ (calculated). In-App Controls: Parental Controls **Yes** (the PIN-protected Parent corner lets a parent monitor progress and turn topics off), Age Assurance No. Every other question None or No: no web access, no user-generated content shared with others, no social features or chat, no ads, no gambling, contests or loot boxes |
| Age category override | Not Applicable (not "Made for Kids") |
| Kids Category | Not opted in. The app suits children, but the Kids Category adds requirements (parental gates and more) that it doesn't need: it has no links, purchases or ads |
| Korea | The Republic of Korea asks games for a Rating Classification Number (App Information ▸ Age Ratings ▸ Add RCN). Without one the app may not appear there |
| Content rights | Doesn't contain, show or access third-party content |
| Price | Free ($0.00), base country United States, all 175 countries or regions, available on release |
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

## History

- **1.0.0** (build 202611071307, uploaded by CI from the `v1.0.0` tag): submitted for review 2026-11-07, released
  automatically once approved. App Review contact copied from Dave's Music Library's listing.
