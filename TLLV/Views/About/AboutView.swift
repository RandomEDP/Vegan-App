import SwiftUI

struct AboutView: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    /// True when shown as a sheet (adds a Done button).
    var showsDone = false
    @State private var showingNewsletter = false
    @State private var expandedTestimonial: String?

    private let socials: [(String, String, String)] = [
        ("Instagram", "camera", "https://www.instagram.com/thelittlelondonvegan/"),
        ("TikTok", "music.note", "https://www.tiktok.com/@thelittlelondonvegan"),
        ("YouTube", "play.rectangle", "https://www.youtube.com/@thelittlelondonvegan"),
        ("Facebook", "person.2", "https://www.facebook.com/thelittlelondonvegan/")
    ]

    private let legal: [(String, String)] = [
        ("Help & Contact", "#help"),
        ("Privacy Policy", "/privacy"),
        ("Terms", "/terms"),
        ("Cookies", "/cookies"),
        ("Accessibility", "/accessibility")
    ]

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    RemoteImage(url: Site.resolveURL("/assets/ima-latest-clare.webp"), symbol: "person.fill")
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                    Text(catalog.siteContent.aboutTitle)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)

                if !catalog.siteContent.aboutBody.isEmpty {
                    Text(catalog.siteContent.aboutBody.markdownAttributed)
                        .font(.body)
                        .padding(.vertical, 4)
                }
            }

            if !catalog.siteContent.testimonials.isEmpty {
                Section("What Restaurants Say") {
                    ForEach(catalog.siteContent.testimonials) { testimonial in
                        Button {
                            withAnimation { expandedTestimonial = expandedTestimonial == testimonial.id ? nil : testimonial.id }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("“\(expandedTestimonial == testimonial.id ? testimonial.full : testimonial.preview)”")
                                    .font(.body.italic())
                                    .foregroundStyle(.primary)
                                Text(catalog.place(named: testimonial.id) ?? testimonial.id.replacingOccurrences(of: "-", with: " ").capitalized)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section {
                Button {
                    if let url = URL(string: "https://www.youtube.com/@thelittlelondonvegan") { openURL(url) }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Last Orders", systemImage: "mic.fill").font(.headline)
                        Text("Clare chats to the people behind our food scene to find out the highs, lows and things nobody knows.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Behind the Food Scene")
            }

            Section {
                Button {
                    showingNewsletter = true
                } label: {
                    Label("Subscribe to the Newsletter", systemImage: "envelope")
                }
                ForEach(socials, id: \.0) { social in
                    Button {
                        if let url = URL(string: social.2) { openURL(url) }
                    } label: {
                        Label(social.0, systemImage: social.1)
                    }
                }
                Button {
                    openURL(Site.baseURL)
                } label: {
                    Label("thelittlelondonvegan.com", systemImage: "safari")
                }
            } header: {
                Text("Follow TLLV")
            }

            Section {
                ForEach(legal, id: \.0) { item in
                    Button(item.0) {
                        let url = item.1.hasPrefix("#")
                            ? Site.baseURL.appendingFragment(String(item.1.dropFirst()))
                            : Site.baseURL.appending(path: item.1)
                        openURL(url)
                    }
                    .foregroundStyle(.primary)
                }
            } footer: {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingNewsletter) {
            NewsletterSheet()
        }
    }
}

extension CatalogStore {
    /// Testimonial ids are slugs such as "tofu-vegan"; find the matching restaurant name.
    func place(named slug: String) -> String? {
        let target = slug.replacingOccurrences(of: "-", with: " ").lowercased()
        return restaurants.first { $0.name.lowercased().hasPrefix(target) }?.name
    }
}

// MARK: - Newsletter

struct NewsletterSheet: View {
    @Environment(CatalogStore.self) private var catalog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var email = ""
    @State private var consent = false
    @State private var isSending = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @FocusState private var emailFocused: Bool

    private var isValid: Bool {
        consent && email.contains("@") && email.contains(".")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "envelope.open.fill")
                            .font(.largeTitle)
                            .foregroundStyle(Color.accentColor)
                        Text("The Little London Vegan newsletter")
                            .font(.title3.bold())
                        Text("New openings, closures, menus, reviews & more.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                if let resultMessage {
                    Section {
                        Label(resultMessage, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                } else {
                    Section {
                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($emailFocused)
                        Toggle("Email me the TLLV newsletter", isOn: $consent)
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I consent to tracking of email opens and link clicks to help improve the newsletter. Unsubscribe anytime.")
                            Button("Privacy Policy") { openURL(Site.baseURL.appending(path: "privacy")) }
                                .font(.footnote)
                        }
                    }

                    if let errorMessage {
                        Section {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Newsletter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(resultMessage == nil ? "Cancel" : "Done") { dismiss() }
                }
                if resultMessage == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSending {
                            ProgressView()
                        } else {
                            Button("Subscribe", action: subscribe)
                                .disabled(!isValid)
                        }
                    }
                }
            }
            .onAppear { emailFocused = true }
        }
        .inAppBrowser()
        .presentationDetents([.medium, .large])
    }

    private func subscribe() {
        isSending = true
        errorMessage = nil
        Task {
            do {
                let result = try await catalog.subscribeToNewsletter(email: email.trimmingCharacters(in: .whitespaces))
                resultMessage = result.message
            } catch {
                errorMessage = "Something went wrong. Please try again."
            }
            isSending = false
        }
    }
}
