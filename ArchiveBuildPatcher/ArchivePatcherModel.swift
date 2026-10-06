import AppKit
import Foundation

@MainActor
final class ArchivePatcherModel: ObservableObject {
    @Published var archiveInfo: ArchiveInfo?
    @Published var latestRelease: MacOSRelease?
    @Published var isLoadingRelease = false
    @Published var isPatching = false
    @Published var createBackup = true
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var backupURL: URL?

    private let archiveService = ArchiveService()
    private let releaseService = AppleReleaseService()
    private var lastReleaseRefresh: Date?

    var canPatch: Bool {
        guard let archiveInfo, let latestRelease else { return false }
        return !isPatching && archiveInfo.currentBuildMachineOSBuild != latestRelease.build
    }

    func handleDroppedURL(_ url: URL) {
        errorMessage = nil
        successMessage = nil
        backupURL = nil

        do {
            archiveInfo = try archiveService.inspectArchive(at: url)
        } catch {
            archiveInfo = nil
            errorMessage = error.localizedDescription
        }

        Task { await refreshLatestReleaseIfNeeded(force: true) }
    }


    func chooseArchive() {
        let panel = NSOpenPanel()
        panel.title = "Choose Xcode Archive"
        panel.message = "Select the .xcarchive you want to inspect and patch."
        panel.prompt = "Choose Archive"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true
        panel.allowedFileTypes = ["xcarchive"]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        handleDroppedURL(url)
    }

    func refreshLatestReleaseIfNeeded(force: Bool = false) async {
        if !force,
           latestRelease != nil,
           let lastReleaseRefresh,
           Date().timeIntervalSince(lastReleaseRefresh) < 60 * 60 {
            return
        }

        isLoadingRelease = true
        defer { isLoadingRelease = false }

        do {
            latestRelease = try await releaseService.latestPublicMacOSRelease()
            lastReleaseRefresh = Date()
        } catch {
            errorMessage = "Could not fetch Apple's latest public macOS build: \(error.localizedDescription)"
        }
    }

    func patch() {
        guard let info = archiveInfo, let release = latestRelease else { return }

        isPatching = true
        errorMessage = nil
        successMessage = nil
        backupURL = nil

        Task {
            do {
                let backup: URL? = try await Task.detached(priority: .userInitiated) { [archiveService, createBackup = self.createBackup] in
                    if createBackup {
                        return try archiveService.backupArchive(info.archiveURL)
                    }
                    return nil
                }.value

                try archiveService.patchBuildMachineOSBuild(plistURL: info.plistURL, newBuild: release.build)
                backupURL = backup
                archiveInfo = try archiveService.inspectArchive(at: info.archiveURL)
                successMessage = "Patched BuildMachineOSBuild to \(release.build)."
            } catch {
                errorMessage = error.localizedDescription
            }

            isPatching = false
        }
    }

    func revealArchive() {
        guard let archiveInfo else { return }
        NSWorkspace.shared.activateFileViewerSelecting([archiveInfo.archiveURL])
    }

    func openArchive() {
        guard let archiveInfo else { return }
        NSWorkspace.shared.open(archiveInfo.archiveURL)
    }

    func clear() {
        archiveInfo = nil
        successMessage = nil
        errorMessage = nil
        backupURL = nil
    }
}
