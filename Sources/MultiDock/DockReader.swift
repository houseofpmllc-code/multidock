import AppKit
import CoreGraphics

struct DockItem: Equatable {
    let name: String
    let url: URL
    let icon: NSImage
    let bundleID: String?
    var isPinned: Bool = true  // false = running-only, not in dock

    static func == (lhs: DockItem, rhs: DockItem) -> Bool {
        lhs.url.standardized == rhs.url.standardized
    }

    var runningApp: NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            if let bid = bundleID, let rbid = $0.bundleIdentifier {
                return bid == rbid
            }
            guard let burl = $0.bundleURL else { return false }
            return burl.standardized.path == url.standardized.path
        }
    }

    var isRunning: Bool { runningApp != nil }
}

class DockReader {
    static func readItems() -> [DockItem] {
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")

        guard let plist = NSDictionary(contentsOf: plistURL),
              let persistentApps = plist["persistent-apps"] as? [[String: Any]] else {
            return []
        }

        var items: [DockItem] = []

        for app in persistentApps {
            let tileType = app["tile-type"] as? String ?? ""
            if tileType == "spacer-tile" || tileType == "small-spacer-tile" { continue }

            guard
                let tileData = app["tile-data"] as? [String: Any],
                let fileData = tileData["file-data"] as? [String: Any],
                let urlString = fileData["_CFURLString"] as? String,
                let url = URL(string: urlString)
            else { continue }

            let name = (tileData["file-label"] as? String) ?? url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let bundleID = Bundle(url: url)?.bundleIdentifier

            items.append(DockItem(name: name, url: url, icon: icon, bundleID: bundleID, isPinned: true))
        }

        return items
    }

    /// Running apps not already in the pinned dock list, that have visible windows
    static func runningOnlyItems(excluding pinned: [DockItem]) -> [DockItem] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleURL != nil }
            .compactMap { app -> DockItem? in
                guard let url = app.bundleURL else { return nil }
                // Skip if already in pinned list
                let alreadyPinned = pinned.contains {
                    if let bid = $0.bundleID, let rbid = app.bundleIdentifier { return bid == rbid }
                    return $0.url.standardized.path == url.standardized.path
                }
                if alreadyPinned { return nil }
                // Only show if it has actual visible windows
                if !hasWindows(pid: app.processIdentifier) { return nil }
                let name = app.localizedName ?? url.deletingPathExtension().lastPathComponent
                let icon = app.icon ?? NSWorkspace.shared.icon(forFile: url.path)
                return DockItem(name: name, url: url, icon: icon, bundleID: app.bundleIdentifier, isPinned: false)
            }
    }

    /// Returns true if the process has at least one normal on-screen window
    static func hasWindows(pid: pid_t) -> Bool {
        let options = CGWindowListOption([.excludeDesktopElements, .optionOnScreenOnly])
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }
        return list.contains {
            guard let ownerPid = $0[kCGWindowOwnerPID as String] as? Int32,
                  let layer = $0[kCGWindowLayer as String] as? Int,
                  let alpha = $0[kCGWindowAlpha as String] as? Double else { return false }
            return ownerPid == pid && layer == 0 && alpha > 0
        }
    }

    static func orientation() -> String {
        let plistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        let plist = NSDictionary(contentsOf: plistURL)
        return (plist?["orientation"] as? String) ?? "bottom"
    }
}
