import SwiftUI

// MARK: - Presenting the paywall from anywhere

struct ShowPaywallAction {
    var handler: (PremiumFeature) -> Void = { _ in }
    func callAsFunction(_ feature: PremiumFeature) { handler(feature) }
}

private struct ShowPaywallKey: EnvironmentKey {
    static let defaultValue = ShowPaywallAction()
}

extension EnvironmentValues {
    var showPaywall: ShowPaywallAction {
        get { self[ShowPaywallKey.self] }
        set { self[ShowPaywallKey.self] = newValue }
    }
}

/// Hosts the Premium sheet and the in-app browser for a view hierarchy.
/// Apply once at the root and once inside each sheet.
struct AppHosts: ViewModifier {
    @State private var feature: PremiumFeature?

    func body(content: Content) -> some View {
        content
            .environment(\.showPaywall, ShowPaywallAction { feature = $0 })
            .sheet(item: $feature) { feature in
                PaywallView(feature: feature)
            }
            .inAppBrowser()
    }
}

extension View {
    func appHosts() -> some View { modifier(AppHosts()) }
}

// MARK: - Paywall

struct PaywallView: View {
    let feature: PremiumFeature

    @Environment(AccountStore.self) private var account
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showingSignIn = false

    private let benefits: [(symbol: String, title: String, detail: String)] = [
        ("tag.fill", "Exclusive perks", "Restaurant and brand offers for paid Premium members."),
        ("map.fill", "Your interactive London map", "Explore nearby places and filter by hundreds of tags."),
        ("book.fill", "Clare’s guides & orders", "Every curated guide, plus what Clare orders at each place."),
        ("heart.fill", "Faves & lists", "Save, organise and share places.")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: feature.symbol)
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 88, height: 88)
                            .background(Color("BrandBackground"), in: Circle())
                        Text("TLLV PREMIUM")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(feature.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(trialMessage)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(benefits, id: \.title) { benefit in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: benefit.symbol)
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(benefit.title).font(.headline)
                                    Text(benefit.detail).font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Text("One restaurant discount could save you more than the £3.99 monthly membership.")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        openURL(upgradeURL)
                    } label: {
                        Text(primaryTitle).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text(priceNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if !account.isSignedIn {
                        Button("Already a member? Sign In") { showingSignIn = true }
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSignIn) {
                SignInView()
            }
            .onChange(of: account.isEntitled(to: feature)) { _, entitled in
                if entitled { dismiss() }
            }
        }
        .inAppBrowser()
    }

    private var trialMessage: String {
        if feature == .perks && account.membership == .trial {
            return "Your trial includes Premium maps, filters, guides, favourites and planning. Restaurant and brand perks become redeemable when your paid membership starts."
        }
        return feature.message
    }

    private var primaryTitle: String {
        if account.membership == .trial { return "View Membership" }
        return account.trialEligible ? "Start Your 7-Day Free Trial" : "View Premium Options"
    }

    private var priceNote: String {
        let base = account.trialEligible
            ? "7 days free, then £3.99/month or £39.99/year, depending on your plan."
            : "£3.99/month or £39.99/year."
        return base + " Renews automatically unless cancelled. Cancel any time."
    }

    private var upgradeURL: URL {
        if account.membership == .trial { return Site.baseURL.appendingFragment("profile") }
        if account.isSignedIn { return Site.baseURL.appendingFragment("upgrade") }
        var components = URLComponents(url: Site.baseURL.appendingPathComponent("account.html"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "mode", value: "signup"), URLQueryItem(name: "return_to", value: "/#upgrade")]
        return components.url!
    }
}

// MARK: - Sign in

struct SignInView: View {
    @Environment(AccountStore.self) private var account
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sign in with your TLLV account")
                            .font(.title3.bold())
                        Text("Use the same email and password as thelittlelondonvegan.com.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                } footer: {
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Button("Forgot Password?") {
                        openURL(accountURL(mode: "forgot"))
                    }
                    Button("Create an Account") {
                        openURL(accountURL(mode: "signup"))
                    }
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Sign In", action: signIn)
                            .disabled(email.isEmpty || password.isEmpty)
                    }
                }
            }
            .onAppear { focus = .email }
        }
        .inAppBrowser()
        .interactiveDismissDisabled(isWorking)
    }

    private func accountURL(mode: String) -> URL {
        var components = URLComponents(url: Site.baseURL.appendingPathComponent("account.html"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "mode", value: mode)]
        return components.url!
    }

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        Task {
            do {
                try await account.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
                await catalog.refresh()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }
}

// MARK: - Account

struct AccountView: View {
    @Environment(AccountStore.self) private var account
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.showPaywall) private var showPaywall
    @State private var showingSignIn = false
    @State private var confirmSignOut = false

    var body: some View {
        List {
            if account.isSignedIn {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name ?? "Your account").font(.headline)
                            if let email = account.email {
                                Text(email).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    LabeledContent("Membership") {
                        Text(account.isOwner ? "Owner" : account.membership.label)
                            .foregroundStyle(account.isMember ? Color.accentColor : Color.secondary)
                            .fontWeight(.semibold)
                    }
                    if !account.isMember {
                        Button("Upgrade to Premium") { showPaywall(.interactiveMap) }
                    }
                    Button("Manage Membership") { openURL(Site.baseURL.appendingFragment("profile")) }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your account").font(.title3.bold())
                        Text("Sign in to access your account and membership. You can browse the free guide without one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    Button("Sign In") { showingSignIn = true }
                        .fontWeight(.semibold)
                    Button("See Premium Benefits") { showPaywall(.interactiveMap) }
                }
            }

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About TLLV", systemImage: "info.circle")
                }
            }

            if account.isSignedIn {
                Section {
                    Button("Sign Out", role: .destructive) { confirmSignOut = true }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .refreshable { await account.refresh() }
        .sheet(isPresented: $showingSignIn) { SignInView() }
        .confirmationDialog("Sign out of TLLV?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await account.signOut()
                    await catalog.refresh()
                }
            }
        }
    }
}

// MARK: - Inline locked state

/// Shown in place of Premium content, like the website's "Unlock" panels.
struct PremiumLockedView: View {
    let feature: PremiumFeature
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    @Environment(AccountStore.self) private var account
    @Environment(\.showPaywall) private var showPaywall

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("TLLV Premium", systemImage: "crown.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text(feature.title).font(.title2.bold())
            Text(feature.message).font(.subheadline).foregroundStyle(.secondary)
            Button {
                showPaywall(feature)
            } label: {
                Text(account.trialEligible && account.membership != .trial ? "Start Your 7-Day Free Trial" : "View Premium Options")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// A small lock badge for Premium rows and cards.
struct PremiumBadge: View {
    var body: some View {
        Label("Premium", systemImage: "lock.fill")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: Capsule())
    }
}
