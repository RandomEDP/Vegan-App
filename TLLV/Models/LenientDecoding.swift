import Foundation

/// The TLLV catalog is edited by hand in a CMS, so the same field can arrive as a
/// string, an array, a number or a boolean depending on the record. These helpers
/// decode each field defensively so one odd record never breaks the whole app.
extension KeyedDecodingContainer {
    func lenientString(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }

    func lenientStrings(_ key: Key) -> [String] {
        if let values = try? decodeIfPresent([String].self, forKey: key) {
            return values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let value = lenientString(key) {
            return value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }

    func lenientDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = lenientString(key) { return Double(value) }
        return nil
    }

    func lenientInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = lenientString(key) { return Int(value) }
        return nil
    }

    func lenientBool(_ key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = lenientString(key)?.lowercased() {
            if ["yes", "true", "1", "y"].contains(value) { return true }
            if ["no", "false", "0", "n"].contains(value) { return false }
        }
        return nil
    }

    func lenientURL(_ key: Key) -> URL? {
        Site.resolveURL(lenientString(key))
    }

    func lenientDate(_ key: Key) -> Date? {
        Site.parseDate(lenientString(key))
    }
}

enum Site {
    static let baseURL = URL(string: "https://thelittlelondonvegan.com")!

    /// One session for every request, sharing the site's sign-in cookies.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpCookieStorage = .shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        return URLSession(configuration: config)
    }()

    /// Turns site-relative paths ("/assets/x.jpg") and absolute strings into URLs.
    static func resolveURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("/") {
            return URL(string: raw, relativeTo: baseURL)?.absoluteURL
        }
        if let url = URL(string: raw), url.scheme != nil { return url }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded), url.scheme != nil {
            return url
        }
        return nil
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB_POSIX")
        formatter.timeZone = TimeZone(identifier: "Europe/London")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = isoFormatter.date(from: raw) { return date }
        return dayFormatter.date(from: String(raw.prefix(10)))
    }

    static let londonCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()
}

extension Date {
    /// "29 Oct 2026", matching the website.
    var tllvShort: String {
        formatted(.dateTime.day().month(.abbreviated).year())
    }
}
