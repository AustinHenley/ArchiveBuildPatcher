import Foundation

struct ArchiveService {
    private let fileManager = FileManager.default

    func inspectArchive(at archiveURL: URL) throws -> ArchiveInfo {
        guard archiveURL.pathExtension.lowercased() == "xcarchive" else {
            throw ArchivePatcherError.notArchive
        }

        let applicationsURL = archiveURL
            .appendingPathComponent("Products", isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: applicationsURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ArchivePatcherError.applicationsFolderMissing
        }

        let appURLs = try fileManager.contentsOfDirectory(
            at: applicationsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension.lowercased() == "app" }

        guard !appURLs.isEmpty else {
            throw ArchivePatcherError.appNotFound
        }

        guard appURLs.count == 1, let appURL = appURLs.first else {
            throw ArchivePatcherError.multipleAppsFound(appURLs.map(\.lastPathComponent))
        }

        let plistURL = appURL.appendingPathComponent("Info.plist")
        let plist = try readPlist(at: plistURL).dictionary

        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent

        let version = (plist["CFBundleShortVersionString"] as? String) ?? "—"
        let bundleVersion = (plist["CFBundleVersion"] as? String) ?? "—"
        let machineBuild = plist["BuildMachineOSBuild"] as? String

        return ArchiveInfo(
            archiveURL: archiveURL,
            appURL: appURL,
            plistURL: plistURL,
            displayName: displayName,
            version: version,
            bundleVersion: bundleVersion,
            currentBuildMachineOSBuild: machineBuild
        )
    }

    func backupArchive(_ archiveURL: URL) throws -> URL {
        let parent = archiveURL.deletingLastPathComponent()
        let base = archiveURL.deletingPathExtension().lastPathComponent
        let backupURL = parent.appendingPathComponent("\(base).backup.xcarchive", isDirectory: true)

        guard !fileManager.fileExists(atPath: backupURL.path) else {
            throw ArchivePatcherError.backupAlreadyExists(backupURL)
        }

        try fileManager.copyItem(at: archiveURL, to: backupURL)
        return backupURL
    }

    func patchBuildMachineOSBuild(plistURL: URL, newBuild: String) throws {
        let result = try readPlist(at: plistURL)
        var dictionary = result.dictionary
        dictionary["BuildMachineOSBuild"] = newBuild

        let data = try PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: result.format,
            options: 0
        )

        try data.write(to: plistURL, options: .atomic)
    }

    private func readPlist(at url: URL) throws -> (dictionary: [String: Any], format: PropertyListSerialization.PropertyListFormat) {
        let data = try Data(contentsOf: url)
        var format = PropertyListSerialization.PropertyListFormat.binary
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format)

        guard let dictionary = plist as? [String: Any] else {
            throw ArchivePatcherError.invalidPlist
        }

        return (dictionary, format)
    }
}
