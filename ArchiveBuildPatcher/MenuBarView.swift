import SwiftUI
import UniformTypeIdentifiers

struct MenuBarView: View {
    @EnvironmentObject private var model: ArchivePatcherModel
    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let info = model.archiveInfo {
                archiveDetails(info)
            } else {
                dropZone
            }

            Divider()
            publicReleaseSection

            if let error = model.errorMessage {
                messageBox(error, systemImage: "exclamationmark.triangle.fill")
            }

            if let success = model.successMessage {
                messageBox(success, systemImage: "checkmark.circle.fill")
            }

            if model.archiveInfo != nil {
                actions
            }

            Divider()

            HStack {
                Button("Quit") { NSApplication.shared.terminate(nil) }
                Spacer()
                if model.archiveInfo != nil {
                    Button("Clear") { model.clear() }
                }
            }
            .controlSize(.small)
        }
        .padding(16)
        .animation(.default, value: model.archiveInfo)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "hammer.circle.fill")
                .font(.system(size: 25))
            VStack(alignment: .leading, spacing: 1) {
                Text("Archive Build Patcher")
                    .font(.headline)
                Text("Patch BuildMachineOSBuild in an Xcode archive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
            .frame(height: 120)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 28))
                    Text("Drop .xcarchive here")
                        .font(.headline)
                    Text("The app inside Products/Applications will be detected automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 22)

                    Button("Choose Archive…") {
                        model.chooseArchive()
                    }
                    .controlSize(.small)
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                model.handleDroppedURL(url)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
    }

    @ViewBuilder
    private func archiveDetails(_ info: ArchiveInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.displayName)
                        .font(.headline)
                    Text("Version \(info.version) (\(info.bundleVersion))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(.secondary)
            }

            keyValue("Current BuildMachineOSBuild", info.currentBuildMachineOSBuild ?? "Not present")

            Text(info.archiveURL.lastPathComponent)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private var publicReleaseSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Latest public macOS")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if model.isLoadingRelease {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await model.refreshLatestReleaseIfNeeded(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh from Apple")
                }
            }

            if let release = model.latestRelease {
                HStack {
                    Text("macOS \(release.productVersion)")
                    Spacer()
                    Text(release.build)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                }
            } else if !model.isLoadingRelease {
                Text("No release data loaded yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Create full .xcarchive backup first", isOn: $model.createBackup)
                .font(.caption)

            Button {
                model.patch()
            } label: {
                HStack {
                    Spacer()
                    if model.isPatching {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "wrench.and.screwdriver.fill")
                    }
                    Text(model.isPatching ? "Patching…" : "Patch Archive")
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canPatch)

            if let info = model.archiveInfo,
               let release = model.latestRelease,
               info.currentBuildMachineOSBuild == release.build {
                Label("Archive already matches the latest public build.", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Reveal in Finder") { model.revealArchive() }
                Spacer()
                Button("Open Archive") { model.openArchive() }
            }
            .controlSize(.small)
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .textSelection(.enabled)
        }
    }

    private func messageBox(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
                .font(.caption)
        } icon: {
            Image(systemName: systemImage)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }
}
