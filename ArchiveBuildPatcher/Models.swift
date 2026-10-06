import Foundation

struct MacOSRelease: Equatable {
    let productVersion: String
    let build: String
    let postingDate: Date?
}

struct ArchiveInfo: Equatable {
    let archiveURL: URL
    let appURL: URL
    let plistURL: URL
    let displayName: String
    let version: String
    let bundleVersion: String
    let currentBuildMachineOSBuild: String?
}

enum ArchivePatcherError: LocalizedError {
    case notArchive
    case applicationsFolderMissing
    case appNotFound
    case multipleAppsFound([String])
    case invalidPlist
    case noPublicReleaseFound
    case invalidResponse
    case backupAlreadyExists(URL)

    var errorDescription: String? {
        switch self {
        case .notArchive:
            return "Please drop an .xcarchive bundle."
        case .applicationsFolderMissing:
            return "The archive does not contain Products/Applications."
        case .appNotFound:
            return "No .app bundle was found in Products/Applications."
        case .multipleAppsFound(let names):
            return "More than one app bundle was found: \(names.joined(separator: ", "))."
        case .invalidPlist:
            return "The app's Info.plist could not be read as a property list."
        case .noPublicReleaseFound:
            return "Apple's response did not contain a public macOS release."
        case .invalidResponse:
            return "Apple's software release service returned an unexpected response."
        case .backupAlreadyExists(let url):
            return "A backup already exists at \(url.path). Remove or rename it first."
        }
    }
}
