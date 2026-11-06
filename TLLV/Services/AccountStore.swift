import Foundation
import Observation

/// Features and who can use them. This mirrors the website's own `featureAccess`
/// table, so the app and thelittlelondonvegan.com lock exactly the same things.
enum PremiumFeature: String, Identifiable {
    case advancedFilters, nearMeNow, interactiveMap, favourites, claresOrders, editorialGuides, customLists
    /// Redeeming perks needs a *paid* membership (trial members can only browse them).
    case perks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .advancedFilters: "Unlock filters"
        case .nearMeNow: "Find places near you"
        case .interactiveMap: "Unlock the map"
        case .favourites: "Save your favourites"
        case .claresOrders: "See what Clare orders"
        case .editorialGuides: "Unlock Clare’s guides"
        case .customLists: "Make your own lists"
        case .perks: "Redeem Premium perks"
        }
    }

    var message: String {
        switch self {
        case .advancedFilters: "Narrow your search with hundreds of tags and filters, including dish search, with TLLV Premium."
        case .nearMeNow: "See what’s near you and open right now with TLLV Premium."
        case .interactiveMap: "The interactive map is part of TLLV Premium."
        case .favourites: "Save places you love with TLLV Premium."
        case .claresOrders: "Clare’s favourite dish at every restaurant is part of TLLV Premium."
        case .editorialGuides: "Clare’s curated London guides are part of TLLV Premium."
        case .customLists: "Save, organise and share places with TLLV Premium."
        case .perks: "Restaurant and brand perks are available to paid Premium members."
        }
    }

    var symbol: String {
        switch self {
        case .advancedFilters: "line.3.horizontal.decrease.circle"
        case .nearMeNow: "location"
        case .interactiveMap: "map"
        case .favourites: "heart"
        case .claresOrders: "fork.knife"
        case .editorialGuides: "book"
        case .customLists: "list.bullet.rectangle"
        case .perks: "tag"
        }
    }
}

enum Membership: String {
    case guest, free, trial, premium

    var label: String {
        switch self {
        case .guest: "Not signed in"
        case .free: "Free"
        case .trial: "Premium trial"
        case .premium: "Premium"
        }
    }
}

/// The signed-in TLLV account. Uses the website's own cookie-based session
/// (`/api/auth/login`, `/api/account`), so members sign in with the same
/// email and password they use on thelittlelondonvegan.com.
@MainActor
@Observable
final class AccountStore {
    private(set) var membership: Membership = .guest
    private(set) var isOwner = false
    private(set) var trialEligible = true
    private(set) var canRedeemPerks = false
    private(set) var name: String?
    private(set) var email: String?
    private(set) var isLoading = false

    private let membershipKey = "tllv.membership.v1"

    init() {
        // Show the last known state straight away; `refresh()` confirms it.
        if let saved = UserDefaults.standard.string(forKey: membershipKey), let value = Membership(rawValue: saved) {
            membership = value
        }
    }

    var isSignedIn: Bool { membership != .guest }

    /// Premium or trial, like the website's `member()`.
    var isMember: Bool { isOwner || membership == .premium || membership == .trial }

    func isEntitled(to feature: PremiumFeature) -> Bool {
        feature == .perks ? canRedeemPerks : isMember
    }

    // MARK: Session

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let json = try await request("api/account")
            apply(account: json)
            await refreshPerkEligibility()
        } catch AccountError.unauthorised {
            setSignedOut()
        } catch {
            // Offline: keep the last known membership.
        }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await request("api/auth/login", body: ["email": email, "password": password])
        await refresh()
        if !isSignedIn { throw AccountError.message("We couldn’t sign you in. Please try again.") }
    }

    func signOut() async {
        _ = try? await request("api/auth/logout", body: [:])
        for cookie in HTTPCookieStorage.shared.cookies(for: Site.baseURL) ?? [] {
            HTTPCookieStorage.shared.deleteCookie(cookie)
        }
        setSignedOut()
    }

    private func setSignedOut() {
        membership = .guest
        isOwner = false
        canRedeemPerks = false
        name = nil
        email = nil
        UserDefaults.standard.set(Membership.guest.rawValue, forKey: membershipKey)
    }

    private func apply(account: [String: Any]) {
        let raw = (account["membership"] as? String) ?? "free"
        membership = Membership(rawValue: raw) ?? .free
        if membership == .guest { membership = .free }
        isOwner = account["isOwner"] as? Bool ?? false
        trialEligible = account["trialEligible"] as? Bool ?? true
        let profile = (account["data"] as? [String: Any])?["profile"] as? [String: Any]
        name = (profile?["name"] as? String) ?? (account["name"] as? String)
        email = (account["email"] as? String) ?? (profile?["email"] as? String)
        UserDefaults.standard.set(membership.rawValue, forKey: membershipKey)
    }

    private func refreshPerkEligibility() async {
        if let json = try? await request("api/perks") {
            canRedeemPerks = json["canRedeem"] as? Bool ?? false
        }
    }

    // MARK: Perks (same endpoints as the website)

    struct UnlockedPerk {
        var id: String
        var title: String
        var venueName: String
        var description: String?
        var perkType: String
        var promoCode: String?
        var url: URL?
        var alreadyUsedReason: String?
    }

    struct Redemption {
        var reference: String?
        var redeemedAt: Date?
    }

    func unlock(_ perk: Perk) async throws -> UnlockedPerk {
        _ = try? await request("api/perks/\(perk.id)/view", body: ["source": "ios"])
        let json = try await request("api/perks/\(perk.id)/unlock", body: ["source": "ios"])
        let data = json["perk"] as? [String: Any] ?? [:]
        let usage = data["usage"] as? [String: Any]
        return UnlockedPerk(
            id: data["id"] as? String ?? perk.id,
            title: data["title"] as? String ?? perk.title,
            venueName: data["venueName"] as? String ?? perk.venueName,
            description: data["description"] as? String ?? perk.description,
            perkType: data["perkType"] as? String ?? perk.perkType,
            promoCode: (data["promoCode"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            url: Site.resolveURL(data["url"] as? String),
            alreadyUsedReason: (usage?["used"] as? Bool == true) ? (usage?["reason"] as? String ?? "You’ve already used this perk.") : nil
        )
    }

    func redeem(_ perkID: String) async throws -> Redemption {
        let json = try await request("api/perks/\(perkID)/redeem", body: ["idempotencyKey": UUID().uuidString, "source": "ios"])
        let redemption = json["redemption"] as? [String: Any] ?? [:]
        let reference = (redemption["code"] as? String) ?? (redemption["reference"] as? String) ?? (redemption["id"] as? String)
        return Redemption(reference: reference, redeemedAt: Site.parseDate(redemption["redeemedAt"] as? String ?? redemption["createdAt"] as? String) ?? .now)
    }

    // MARK: Networking

    enum AccountError: LocalizedError {
        case unauthorised
        case message(String)

        var errorDescription: String? {
            switch self {
            case .unauthorised: "Please sign in again."
            case .message(let text): text
            }
        }
    }

    private func request(_ path: String, body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: Site.baseURL.appendingPathComponent(path))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await Site.session.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw path == "api/auth/login" ? AccountError.message(json["error"] as? String ?? "Email or password not recognised.") : AccountError.unauthorised }
        guard (200..<300).contains(status) else {
            throw AccountError.message(json["error"] as? String ?? "Something went wrong. Please try again.")
        }
        return json
    }
}
