import SwiftUI
import UIKit

struct PerksView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall

    private var restaurantPerks: [Perk] { catalog.perks.filter { !$0.isOnline } }
    private var brandPerks: [Perk] { catalog.perks.filter(\.isOnline) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("TLLV Premium", systemImage: "crown.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(headerText)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        if !account.canRedeemPerks {
                            Button {
                                showPaywall(.perks)
                            } label: {
                                Text(account.membership == .trial ? "View Membership" : "Upgrade to Premium")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if !restaurantPerks.isEmpty {
                    Section("Restaurant Offers") {
                        ForEach(restaurantPerks) { perk in
                            NavigationLink(value: perk) { PerkRow(perk: perk) }
                        }
                    }
                }
                if !brandPerks.isEmpty {
                    Section("Brand Offers") {
                        ForEach(brandPerks) { perk in
                            NavigationLink(value: perk) { PerkRow(perk: perk) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if catalog.perks.isEmpty {
                    if catalog.isRefreshing {
                        ProgressView()
                    } else {
                        ContentUnavailableView("No Perks Right Now", systemImage: "tag", description: Text("Pull to refresh, or check back soon."))
                    }
                }
            }
            .navigationTitle("Perks")
            .refreshable {
                await catalog.refresh()
                await account.refresh()
            }
            .contentDestinations()
        }
    }
}

extension PerksView {
    fileprivate var headerText: String {
        if account.canRedeemPerks {
            return "Your member offers. Open a perk when you’re at the venue or ready to check out."
        }
        if account.membership == .trial {
            return "Browse current offers during your trial. Redeem them once your paid membership begins. Depending on the offer and your bill, one visit could cover a month of Premium."
        }
        return "Exclusive restaurant and brand discounts for Premium members. Depending on the offer and your bill, one visit could cover a month of Premium."
    }
}

struct PerkRow: View {
    let perk: Perk
    @Environment(CatalogStore.self) private var catalog

    var body: some View {
        let venue = catalog.venue(for: perk)
        HStack(spacing: 12) {
            RemoteImage(url: perk.imageURL ?? venue?.image, symbol: "tag.fill")
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(perk.venueName).font(.headline)
                if let venue {
                    Text(perk.venueIDs.count > 1 ? "\(perk.venueIDs.count) locations · \(venue.cardLabel ?? venue.cuisine.first ?? "")" : venue.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(perk.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 2)
    }
}

struct PerkDetailView: View {
    let perk: Perk
    @Environment(CatalogStore.self) private var catalog
    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall
    @State private var showingUnlocked = false

    var body: some View {
        let venue = catalog.venue(for: perk)
        List {
            Section {
                RemoteImage(url: perk.imageURL ?? venue?.image, symbol: "tag.fill")
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                VStack(alignment: .leading, spacing: 6) {
                    Text(perk.venueName).font(.headline).foregroundStyle(.secondary)
                    Text(perk.title).font(.title.bold())
                    if let description = perk.description {
                        Text(description).font(.body)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Terms") {
                LabeledContent("Where", value: perk.isOnline ? "Online" : "In person")
                if let days = perk.validDaysText {
                    LabeledContent("Valid on", value: days)
                }
                if let pence = perk.minimumSpendPence, pence > 0 {
                    LabeledContent("Minimum spend", value: (Double(pence) / 100).formatted(.currency(code: "GBP")))
                }
                if let until = perk.validUntil {
                    LabeledContent("Ends", value: until.tllvShort)
                }
                if let limit = perk.usageLimit {
                    LabeledContent("Use", value: limit == "unlimited" ? "Unlimited" : limit.capitalized)
                }
            }

            Section {
                Button {
                    if account.isEntitled(to: .perks) { showingUnlocked = true } else { showPaywall(.perks) }
                } label: {
                    Label(account.canRedeemPerks ? "Use This Perk" : "Unlock with Premium",
                          systemImage: account.canRedeemPerks ? "tag.fill" : "lock.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text(account.membership == .trial && !account.canRedeemPerks
                     ? "Perks become redeemable when your paid membership starts."
                     : "Perks are available to paid TLLV Premium members.")
            }

            if let venue {
                Section("Restaurant") {
                    NavigationLink(value: venue) { PlaceRow(place: venue) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(perk.venueName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingUnlocked) {
            UnlockedPerkSheet(perk: perk)
        }
    }
}

/// The member's view of a perk: how to use it, the code, and redeem-at-venue.
/// Uses the website's own unlock and redeem endpoints, so usage limits match.
struct UnlockedPerkSheet: View {
    let perk: Perk
    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var unlocked: AccountStore.UnlockedPerk?
    @State private var redemption: AccountStore.Redemption?
    @State private var errorMessage: String?
    @State private var confirmRedeem = false
    @State private var isRedeeming = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if let redemption {
                    redeemedView(redemption)
                } else if let unlocked {
                    unlockedView(unlocked)
                } else if let errorMessage {
                    ContentUnavailableView("Couldn’t Open Perk", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                } else {
                    ProgressView("Loading perk…")
                }
            }
            .navigationTitle(perk.venueName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .inAppBrowser()
        .task {
            do { unlocked = try await account.unlock(perk) } catch { errorMessage = error.localizedDescription }
        }
        .interactiveDismissDisabled(isRedeeming)
    }

    private func unlockedView(_ perk: AccountStore.UnlockedPerk) -> some View {
        let inPerson = perk.perkType == "in_person"
        return List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("TLLV Premium Perk", systemImage: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    Text(perk.title).font(.title.bold())
                    Text(perk.venueName).font(.headline).foregroundStyle(.secondary)
                    if let description = perk.description { Text(description) }
                }
                .padding(.vertical, 4)
            }
            Section("How to Use It") {
                Text(inPerson
                     ? "Once you’re at the venue and a staff member is ready, tap Redeem at Venue and show them the screen."
                     : "Copy the code if one is shown, then use the website button below and apply the offer at checkout.")
            }
            if let code = perk.promoCode {
                Section("Code") {
                    Button {
                        UIPasteboard.general.string = code
                        copied = true
                    } label: {
                        HStack {
                            Text(code).font(.title2.monospaced().bold()).foregroundStyle(.primary)
                            Spacer()
                            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    }
                    .sensoryFeedback(.success, trigger: copied)
                }
            }
            if let url = perk.url {
                Section {
                    Button { openURL(url) } label: { Label(inPerson ? "Book a Table" : "Go to Website", systemImage: "arrow.up.forward.square") }
                }
            }
            if inPerson {
                Section {
                    if let reason = perk.alreadyUsedReason {
                        Label(reason, systemImage: "checkmark.seal").foregroundStyle(.secondary)
                    } else {
                        Button {
                            confirmRedeem = true
                        } label: {
                            Group {
                                if isRedeeming { ProgressView() } else { Text("Redeem at Venue") }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isRedeeming)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                } footer: {
                    if perk.alreadyUsedReason == nil {
                        Text("Only tap redeem when you are at the venue and a staff member is ready.")
                    }
                }
                .confirmationDialog("Redeem now?", isPresented: $confirmRedeem, titleVisibility: .visible) {
                    Button("Redeem at Venue") { redeem(perk.id) }
                } message: {
                    Text("Make sure a staff member can see your screen.")
                }
            }
            if let errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func redeemedView(_ redemption: AccountStore.Redemption) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            Text("Perk redeemed").font(.largeTitle.bold())
            Text(perk.title).font(.title3.weight(.semibold))
            Text(perk.venueName).foregroundStyle(.secondary)
            if let reference = redemption.reference {
                Text(reference).font(.title2.monospaced().bold())
            }
            Text((redemption.redeemedAt ?? .now).formatted(date: .abbreviated, time: .shortened))
                .font(.headline)
                .monospacedDigit()
            Text("Show this screen to a member of staff.")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("BrandBackground").opacity(0.5))
    }

    private func redeem(_ id: String) {
        isRedeeming = true
        errorMessage = nil
        Task {
            do { redemption = try await account.redeem(id) } catch { errorMessage = error.localizedDescription }
            isRedeeming = false
        }
    }
}

extension URL {
    func appendingFragment(_ fragment: String) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.fragment = fragment
        return components?.url ?? self
    }
}
