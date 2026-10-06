import AppKit
import SwiftUI

@main
struct ArchiveBuildPatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The app is intentionally menu-bar-only. AppDelegate owns the status item
        // and a non-transient NSPopover so Finder drag sessions cannot dismiss it.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let model = ArchivePatcherModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()

        Task {
            await model.refreshLatestReleaseIfNeeded()
        }
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        let image = NSImage(systemSymbolName: "hammer.circle", accessibilityDescription: "Archive Build Patcher")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "Archive Build Patcher"
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func configurePopover() {
        let rootView = MenuBarView()
            .environmentObject(model)
            .frame(width: 380)

        popover.contentViewController = NSHostingController(rootView: rootView)
        popover.contentSize = NSSize(width: 380, height: 520)

        // Critical for drag/drop: transient MenuBarExtra windows close when the drag
        // moves focus back to Finder. applicationDefined keeps this popover alive
        // until we explicitly close it.
        popover.behavior = .applicationDefined
        popover.animates = true
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
