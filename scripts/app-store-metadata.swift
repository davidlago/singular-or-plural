// Sends the App Store listing to App Store Connect for the version being prepared: the app information, the version's
// description, keywords and promotional text, the App Review notes, the screenshots, and the newest processed build of
// that version. It never submits anything for review.
//
//   swift scripts/app-store-metadata.swift <key.p8> <key ID> <issuer ID> [--no-screenshots]
//
// Reads docs/app-store/listing.json, the screenshots in docs/app-store/iphone-6.3 (and docs/app-store/iphone, if
// present), the bundle ID from Config/Signing.xcconfig and the version from Config/Version.xcconfig. The age rating,
// App Privacy, price and content rights are set on the website (docs/app-store/README.md).
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3 else { fail("usage: app-store-metadata.swift <key.p8> <key ID> <issuer ID> [--no-screenshots]") }
let keyPath = args[0], keyID = args[1], issuer = args[2]
let withScreenshots = !args.contains("--no-screenshots")

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
func file(_ path: String) -> URL { root.appendingPathComponent(path) }

func xcconfigValue(_ path: String, _ key: String) -> String {
    guard let text = try? String(contentsOf: file(path), encoding: .utf8) else { fail("can't read \(path)") }
    for line in text.split(separator: "\n") {
        let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, parts[0] == key { return parts[1] }
    }
    fail("no \(key) in \(path)")
}
let bundleID = xcconfigValue("Config/Signing.xcconfig", "APP_BUNDLE_ID")
let version = xcconfigValue("Config/Version.xcconfig", "MARKETING_VERSION")

guard let listingData = try? Data(contentsOf: file("docs/app-store/listing.json")),
      let listing = try? JSONSerialization.jsonObject(with: listingData) as? [String: Any] else {
    fail("can't read docs/app-store/listing.json")
}
func text(_ key: String) -> String {
    guard let value = listing[key] as? String else { fail("listing.json has no \(key)") }
    return value
}
let locale = text("locale")

// MARK: App Store Connect API

func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let token: String = {
    guard let pem = try? String(contentsOfFile: keyPath, encoding: .utf8),
          let key = try? P256.Signing.PrivateKey(pemRepresentation: pem) else { fail("can't read the API key \(keyPath)") }
    let now = Int(Date().timeIntervalSince1970)
    let header = try! JSONSerialization.data(withJSONObject: ["alg": "ES256", "kid": keyID, "typ": "JWT"])
    let claims = try! JSONSerialization.data(withJSONObject: ["iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"])
    let input = base64URL(header) + "." + base64URL(claims)
    let signature = try! key.signature(for: Data(input.utf8))
    return input + "." + base64URL(signature.rawRepresentation)
}()

/// Calls the API. Returns nil for 404 when `optional` is set; fails on any other error.
@discardableResult
func api(_ method: String, _ path: String, query: [String: String] = [:], body: [String: Any]? = nil,
         optional: Bool = false) async -> [String: Any]? {
    var components = URLComponents(string: "https://api.appstoreconnect.apple.com/v1/\(path)")!
    if !query.isEmpty { components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
    var request = URLRequest(url: components.url!)
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    if let body {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: body)
    }
    guard let (data, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else {
        fail("\(method) \(path): no response")
    }
    if optional, http.statusCode == 404 { return nil }
    guard (200..<300).contains(http.statusCode) else {
        fail("\(method) \(path): HTTP \(http.statusCode) \(String(decoding: data, as: UTF8.self))")
    }
    if data.isEmpty { return [:] }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
}

func items(_ response: [String: Any]?) -> [[String: Any]] { response?["data"] as? [[String: Any]] ?? [] }
func one(_ response: [String: Any]?) -> [String: Any]? { response?["data"] as? [String: Any] }
func attributes(_ item: [String: Any]) -> [String: Any] { item["attributes"] as? [String: Any] ?? [:] }
func id(_ item: [String: Any]) -> String { item["id"] as? String ?? "" }
func ref(_ type: String, _ id: String) -> [String: Any] { ["data": ["type": type, "id": id]] }

// MARK: The app and its information

guard let app = items(await api("GET", "apps", query: ["filter[bundleId]": bundleID])).first else {
    fail("no app with bundle ID \(bundleID) in App Store Connect")
}
let appID = id(app)
print("App: \(attributes(app)["name"] ?? "") (\(appID))")

let editableInfoStates: Set<String> = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "WAITING_FOR_REVIEW"]
let appInfos = items(await api("GET", "apps/\(appID)/appInfos"))
guard let appInfo = appInfos.first(where: { editableInfoStates.contains(attributes($0)["state"] as? String ?? attributes($0)["appStoreState"] as? String ?? "") })
        ?? appInfos.first else { fail("no app info") }
let appInfoID = id(appInfo)

var categories: [String: Any] = [
    "primaryCategory": ref("appCategories", text("primaryCategory")),
    "secondaryCategory": ref("appCategories", text("secondaryCategory")),
]
let subcategories = listing["secondarySubcategories"] as? [String] ?? []
if subcategories.count > 0 { categories["secondarySubcategoryOne"] = ref("appCategories", subcategories[0]) }
if subcategories.count > 1 { categories["secondarySubcategoryTwo"] = ref("appCategories", subcategories[1]) }
await api("PATCH", "appInfos/\(appInfoID)", body: ["data": ["type": "appInfos", "id": appInfoID, "relationships": categories]])
print("Categories: \(text("primaryCategory")), \(text("secondaryCategory")) \(subcategories)")

let infoLocalizations = items(await api("GET", "appInfos/\(appInfoID)/appInfoLocalizations"))
let infoAttributes: [String: Any] = ["name": text("name"), "subtitle": text("subtitle"), "privacyPolicyUrl": text("privacyPolicyUrl")]
if let localization = infoLocalizations.first(where: { attributes($0)["locale"] as? String == locale }) {
    await api("PATCH", "appInfoLocalizations/\(id(localization))",
              body: ["data": ["type": "appInfoLocalizations", "id": id(localization), "attributes": infoAttributes]])
} else {
    var attrs = infoAttributes
    attrs["locale"] = locale
    await api("POST", "appInfoLocalizations", body: ["data": ["type": "appInfoLocalizations", "attributes": attrs,
                                                                "relationships": ["appInfo": ref("appInfos", appInfoID)]]])
}
print("App information: name, subtitle, privacy policy URL")

// MARK: The version

let editableVersionStates: Set<String> = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY"]
let versions = items(await api("GET", "apps/\(appID)/appStoreVersions", query: ["filter[platform]": "IOS", "limit": "20"]))
var versionItem = versions.first { editableVersionStates.contains(attributes($0)["appStoreState"] as? String ?? "") }
if versionItem == nil {
    versionItem = one(await api("POST", "appStoreVersions", body: ["data": [
        "type": "appStoreVersions", "attributes": ["platform": "IOS", "versionString": version],
        "relationships": ["app": ref("apps", appID)],
    ]]))
}
guard let versionItem else { fail("couldn't find or create a version to edit") }
let versionID = id(versionItem)
await api("PATCH", "appStoreVersions/\(versionID)", body: ["data": [
    "type": "appStoreVersions", "id": versionID,
    "attributes": ["versionString": version, "copyright": text("copyright")],
]])
print("Version \(version): copyright")

let versionLocalizations = items(await api("GET", "appStoreVersions/\(versionID)/appStoreVersionLocalizations"))
let versionAttributes: [String: Any] = [
    "description": text("description"), "keywords": text("keywords"), "promotionalText": text("promotionalText"),
    "supportUrl": text("supportUrl"), "marketingUrl": text("marketingUrl"),
]
var versionLocalizationID: String
if let localization = versionLocalizations.first(where: { attributes($0)["locale"] as? String == locale }) {
    versionLocalizationID = id(localization)
    await api("PATCH", "appStoreVersionLocalizations/\(versionLocalizationID)", body: ["data": [
        "type": "appStoreVersionLocalizations", "id": versionLocalizationID, "attributes": versionAttributes,
    ]])
} else {
    var attrs = versionAttributes
    attrs["locale"] = locale
    let created = one(await api("POST", "appStoreVersionLocalizations", body: ["data": [
        "type": "appStoreVersionLocalizations", "attributes": attrs,
        "relationships": ["appStoreVersion": ref("appStoreVersions", versionID)],
    ]]))
    versionLocalizationID = id(created ?? [:])
}
print("Version text: description, keywords, promotional text, support and marketing URLs")

// MARK: Build

let builds = items(await api("GET", "builds", query: [
    "filter[app]": appID, "filter[preReleaseVersion.version]": version, "filter[processingState]": "VALID",
    "sort": "-uploadedDate", "limit": "1",
]))
if let build = builds.first {
    await api("PATCH", "appStoreVersions/\(versionID)/relationships/build", body: ref("builds", id(build)))
    print("Build: \(attributes(build)["version"] ?? id(build))")
} else {
    print("Build: none processed yet for \(version); run this again once TestFlight shows it")
}

// MARK: App Review notes

let reviewNotes: [String: Any] = ["notes": text("reviewNotes"), "demoAccountRequired": false]
if let detail = one(await api("GET", "appStoreVersions/\(versionID)/appStoreReviewDetail", optional: true)) {
    await api("PATCH", "appStoreReviewDetails/\(id(detail))", body: ["data": [
        "type": "appStoreReviewDetails", "id": id(detail), "attributes": reviewNotes,
    ]])
} else {
    await api("POST", "appStoreReviewDetails", body: ["data": [
        "type": "appStoreReviewDetails", "attributes": reviewNotes,
        "relationships": ["appStoreVersion": ref("appStoreVersions", versionID)],
    ]])
}
print("App Review: notes, no sign-in")

// MARK: Screenshots

func upload(folder: String, displayType: String) async {
    let dir = file(folder)
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path)
        .filter({ $0.hasSuffix(".png") }).sorted(), !names.isEmpty else { return }

    let sets = items(await api("GET", "appStoreVersionLocalizations/\(versionLocalizationID)/appScreenshotSets"))
    var setID: String
    if let existing = sets.first(where: { attributes($0)["screenshotDisplayType"] as? String == displayType }) {
        setID = id(existing)
        for shot in items(await api("GET", "appScreenshotSets/\(setID)/appScreenshots", query: ["limit": "20"])) {
            await api("DELETE", "appScreenshots/\(id(shot))")
        }
    } else {
        let created = one(await api("POST", "appScreenshotSets", body: ["data": [
            "type": "appScreenshotSets", "attributes": ["screenshotDisplayType": displayType],
            "relationships": ["appStoreVersionLocalization": ref("appStoreVersionLocalizations", versionLocalizationID)],
        ]]))
        setID = id(created ?? [:])
    }

    for name in names {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { fail("can't read \(folder)/\(name)") }
        guard let reserved = one(await api("POST", "appScreenshots", body: ["data": [
            "type": "appScreenshots", "attributes": ["fileName": name, "fileSize": data.count],
            "relationships": ["appScreenshotSet": ref("appScreenshotSets", setID)],
        ]])) else { fail("couldn't reserve \(name)") }
        let operations = attributes(reserved)["uploadOperations"] as? [[String: Any]] ?? []
        for operation in operations {
            guard let urlString = operation["url"] as? String, let url = URL(string: urlString),
                  let offset = operation["offset"] as? Int, let length = operation["length"] as? Int else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = operation["method"] as? String ?? "PUT"
            for header in operation["requestHeaders"] as? [[String: String]] ?? [] {
                if let name = header["name"], let value = header["value"] { request.setValue(value, forHTTPHeaderField: name) }
            }
            guard let (_, response) = try? await URLSession.shared.upload(for: request, from: data.subdata(in: offset..<(offset + length))),
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                fail("uploading \(name) failed")
            }
        }
        let checksum = Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        await api("PATCH", "appScreenshots/\(id(reserved))", body: ["data": [
            "type": "appScreenshots", "id": id(reserved), "attributes": ["uploaded": true, "sourceFileChecksum": checksum],
        ]])
        print("Screenshot \(displayType): \(name)")
    }
}

if withScreenshots {
    await upload(folder: "docs/app-store/iphone-6.3", displayType: "APP_IPHONE_61")
    await upload(folder: "docs/app-store/iphone", displayType: "APP_IPHONE_67")
}

print("Done. Check the website-only fields in docs/app-store/README.md before submitting.")
