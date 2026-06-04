import AppKit
import ApplicationServices
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate {
    var dockWindows: [DockWindow] = []
    var statusItem: NSStatusItem?
    var refreshTimer: Timer?

    var iconSize: CGFloat {
        get {
            let v = UserDefaults.standard.double(forKey: "iconSize")
            return v > 0 ? CGFloat(v) : 52
        }
        set { UserDefaults.standard.set(Double(newValue), forKey: "iconSize") }
    }

    /// Screen indices (into NSScreen.screens) where MultiDock should appear.
    /// nil = auto (all non-primary screens). Stored as array of UInt32 display IDs.
    var enabledDisplayIDs: Set<UInt32> {
        get {
            let arr = UserDefaults.standard.array(forKey: "enabledDisplayIDs") as? [Int] ?? []
            return arr.isEmpty ? [] : Set(arr.map { UInt32($0) })
        }
        set {
            UserDefaults.standard.set(newValue.map { Int($0) }, forKey: "enabledDisplayIDs")
        }
    }

    var isAutoMode: Bool {
        get { UserDefaults.standard.object(forKey: "enabledDisplayIDs") == nil ||
              (UserDefaults.standard.array(forKey: "enabledDisplayIDs") as? [Int])?.isEmpty == true }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        requestAccessibilityIfNeeded()
        setupStatusBar()
        setupDockWindows()

        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "MultiDock")
        }
        statusItem?.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let header = NSMenuItem(title: "MultiDock", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        // --- Displays submenu ---
        let displaysMenu = NSMenu()

        // "Auto" option
        let autoItem = NSMenuItem(title: "Auto (all secondary monitors)", action: #selector(setDisplayAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = isAutoMode ? .on : .off
        displaysMenu.addItem(autoItem)
        displaysMenu.addItem(.separator())

        let currentIDs = enabledDisplayIDs

        for (i, screen) in NSScreen.screens.enumerated() {
            let displayID = screen.displayID
            let name = screen.localizedName.isEmpty ? "Display \(i + 1)" : screen.localizedName

            let item = NSMenuItem(title: name, action: #selector(toggleDisplay(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(displayID)
            item.state = isAutoMode ? (i > 0 ? .on : .off) : (currentIDs.contains(displayID) ? .on : .off)
            displaysMenu.addItem(item)
        }

        let displaysItem = NSMenuItem(title: "Show on Display", action: nil, keyEquivalent: "")
        displaysItem.submenu = displaysMenu
        menu.addItem(displaysItem)

        menu.addItem(.separator())

        // --- Icon size submenu ---
        let sizeMenu = NSMenu()
        let sizes: [(String, CGFloat)] = [("Small (36px)", 36), ("Medium (52px)", 52), ("Large (64px)", 64), ("Extra Large (80px)", 80)]
        for (label, size) in sizes {
            let item = NSMenuItem(title: label, action: #selector(setSize(_:)), keyEquivalent: "")
            item.target = self
            item.tag = Int(size)
            item.state = (abs(iconSize - size) < 1) ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Icon Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshAll), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit MultiDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc private func setDisplayAuto() {
        // Clear saved IDs → auto mode
        UserDefaults.standard.removeObject(forKey: "enabledDisplayIDs")
        statusItem?.menu = buildMenu()
        setupDockWindows()
    }

    @objc private func toggleDisplay(_ sender: NSMenuItem) {
        let displayID = UInt32(sender.tag)
        var ids = enabledDisplayIDs

        // If switching from auto mode, seed with all current secondary displays
        if isAutoMode {
            ids = Set(Array(NSScreen.screens.dropFirst()).map { $0.displayID })
        }

        if ids.contains(displayID) {
            ids.remove(displayID)
        } else {
            ids.insert(displayID)
        }

        enabledDisplayIDs = ids
        statusItem?.menu = buildMenu()
        setupDockWindows()
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        iconSize = CGFloat(sender.tag)
        statusItem?.menu = buildMenu()
        setupDockWindows()
    }

    /// Returns which screens MultiDock should appear on
    private func targetScreens() -> [NSScreen] {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return [] }

        if isAutoMode {
            return Array(screens.dropFirst())
        } else {
            let ids = enabledDisplayIDs
            if ids.isEmpty { return [] } // nothing selected = hide MultiDock
            return screens.filter { ids.contains($0.displayID) }
        }
    }

    private func currentItems() -> (pinned: [DockItem], running: [DockItem]) {
        let pinned = DockReader.readItems()
        let running = DockReader.runningOnlyItems(excluding: pinned)
        return (pinned, running)
    }

    func setupDockWindows() {
        dockWindows.forEach { $0.close() }
        dockWindows = []

        let screens = targetScreens()
        guard !screens.isEmpty else { return }

        let (pinned, running) = currentItems()
        let orientation = DockReader.orientation()

        for screen in screens {
            let window = DockWindow(
                screen: screen,
                pinnedItems: pinned,
                runningItems: running,
                orientation: orientation,
                iconSize: iconSize
            )
            window.show()
            dockWindows.append(window)
        }
    }

    private func requestAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @objc func screensChanged() {
        statusItem?.menu = buildMenu()
        setupDockWindows()
    }

    @objc func refreshAll() {
        let (pinned, running) = currentItems()
        let orientation = DockReader.orientation()
        for window in dockWindows {
            window.update(pinnedItems: pinned, runningItems: running, orientation: orientation, iconSize: iconSize)
        }
    }
}

// MARK: - NSScreen display ID helper
extension NSScreen {
    var displayID: UInt32 {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? UInt32) ?? 0
    }
}
