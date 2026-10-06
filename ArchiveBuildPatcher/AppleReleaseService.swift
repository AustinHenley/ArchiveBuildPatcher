import Foundation

struct AppleReleaseService {
    private let endpoint = URL(string: "https://gdmf.apple.com/v2/pmv")!

    func latestPublicMacOSRelease() async throws -> MacOSRelease {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ArchivePatcherError.invalidResponse
        }

        let object = try JSONSerialization.jsonObject(with: data)
        let dictionaries = collectDictionaries(from: object)

        let candidates = dictionaries.compactMap { dictionary -> MacOSRelease? in
            guard let version = stringValue(in: dictionary, keys: ["ProductVersion", "productVersion", "OSVersion", "osVersion"]),
                  let build = stringValue(in: dictionary, keys: ["Build", "build", "BuildVersion", "buildVersion"]) else {
                return nil
            }

            guard looksLikeMacOSRecord(dictionary) else { return nil }
            guard looksPublic(dictionary) else { return nil }

            let postingDate = dateValue(in: dictionary, keys: ["PostingDate", "postingDate", "ReleaseDate", "releaseDate"])
            return MacOSRelease(productVersion: version, build: build, postingDate: postingDate)
        }

        guard !candidates.isEmpty else {
            throw ArchivePatcherError.noPublicReleaseFound
        }

        // Prefer the highest macOS version, then posting date, then build string.
        return candidates.max { lhs, rhs in
            let versionComparison = lhs.productVersion.compare(rhs.productVersion, options: .numeric)
            if versionComparison != .orderedSame {
                return versionComparison == .orderedAscending
            }

            if let ld = lhs.postingDate, let rd = rhs.postingDate, ld != rd {
                return ld < rd
            }

            return lhs.build.compare(rhs.build, options: .numeric) == .orderedAscending
        }!
    }

    private func collectDictionaries(from value: Any) -> [[String: Any]] {
        var result: [[String: Any]] = []

        if let dictionary = value as? [String: Any] {
            result.append(dictionary)
            for child in dictionary.values {
                result.append(contentsOf: collectDictionaries(from: child))
            }
        } else if let array = value as? [Any] {
            for child in array {
                result.append(contentsOf: collectDictionaries(from: child))
            }
        }

        return result
    }

    private func stringValue(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func dateValue(in dictionary: [String: Any], keys: [String]) -> Date? {
        let formatters: [ISO8601DateFormatter] = {
            let a = ISO8601DateFormatter()
            a.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let b = ISO8601DateFormatter()
            b.formatOptions = [.withInternetDateTime]
            let c = ISO8601DateFormatter()
            c.formatOptions = [.withFullDate]
            return [a, b, c]
        }()

        for key in keys {
            guard let text = dictionary[key] as? String else { continue }
            for formatter in formatters {
                if let date = formatter.date(from: text) { return date }
            }
        }
        return nil
    }

    private func looksLikeMacOSRecord(_ dictionary: [String: Any]) -> Bool {
        let searchable = dictionary.map { "\($0.key)=\($0.value)" }.joined(separator: " ").lowercased()

        if searchable.contains("macos") || searchable.contains("mac os") {
            return true
        }

        // GDMF has historically grouped macOS assets under a macOS collection, but recursive
        // traversal loses the parent key. A desktop macOS build typically lacks iOS-family markers.
        let mobileMarkers = ["iphone", "ipad", "tvos", "watchos", "visionos", "audioos"]
        return !mobileMarkers.contains(where: searchable.contains)
    }

    private func looksPublic(_ dictionary: [String: Any]) -> Bool {
        let searchable = dictionary.map { "\($0.key)=\($0.value)" }.joined(separator: " ").lowercased()
        let prereleaseMarkers = ["beta", "seed", "developer", "preview", "rc"]
        return !prereleaseMarkers.contains(where: searchable.contains)
    }
}
