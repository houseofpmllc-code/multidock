import AppKit
import ApplicationServices

class DockItemButton: NSView {
    private let item: DockItem
    private let iconSize: CGFloat
    private let imageView: NSImageView
    private let runningDot: NSView
    private var trackingArea: NSTrackingArea?

    init(item: DockItem, iconSize: CGFloat) {
        self.item = item
        self.iconSize = iconSize

        imageView = NSImageView(frame: NSRect(x: 0, y: 5, width: iconSize, height: iconSize))
        imageView.image = item.icon
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = false
        imageView.wantsLayer = true

        runningDot = NSView(frame: NSRect(x: 0, y: 0, width: 5, height: 5))
        runningDot.wantsLayer = true
        runningDot.layer?.cornerRadius = 2.5
        runningDot.layer?.backgroundColor = NSColor.white.cgColor

        super.init(frame: NSRect(x: 0, y: 0, width: iconSize, height: iconSize + 7))
        wantsLayer = true

        addSubview(imageView)
        addSubview(runningDot)

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: iconSize).isActive = true
        heightAnchor.constraint(equalToConstant: iconSize + 7).isActive = true

        // Center the dot
        runningDot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            runningDot.centerXAnchor.constraint(equalTo: centerXAnchor),
            runningDot.bottomAnchor.constraint(equalTo: bottomAnchor),
            runningDot.widthAnchor.constraint(equalToConstant: 5),
            runningDot.heightAnchor.constraint(equalToConstant: 5),
        ])

        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
        ])

        toolTip = item.name
        updateRunningState()

        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appsChanged),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appsChanged),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(appsChanged),
            name: NSWorkspace.didActivateApplicationNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func appsChanged() {
        DispatchQueue.main.async { [weak self] in self?.updateRunningState() }
    }

    private func updateRunningState() {
        runningDot.isHidden = !item.isRunning
    }

    // MARK: - Right-click context menu

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = buildMenu() else { return }
        // Let macOS auto-position — it flips the menu above the dock automatically
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? { nil } // handled by rightMouseDown

    private func buildMenu() -> NSMenu? {
        let menu = NSMenu()

        // Header
        let header = NSMenuItem(title: item.name, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if item.isRunning {
            // Show All Windows
            let showAll = NSMenuItem(title: "Show All Windows", action: #selector(showAllWindows), keyEquivalent: "")
            showAll.target = self
            menu.addItem(showAll)
            menu.addItem(.separator())
        }

        // Options submenu
        let optionsMenu = NSMenu()

        if !item.isRunning {
            let openItem = NSMenuItem(title: "Open", action: #selector(launchOrFocus), keyEquivalent: "")
            openItem.target = self
            optionsMenu.addItem(openItem)
            optionsMenu.addItem(.separator())
        }

        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = isOpenAtLogin() ? .on : .off
        optionsMenu.addItem(loginItem)

        optionsMenu.addItem(.separator())

        let finderItem = NSMenuItem(title: "Show in Finder", action: #selector(showInFinder), keyEquivalent: "")
        finderItem.target = self
        optionsMenu.addItem(finderItem)

        let options = NSMenuItem(title: "Options", action: nil, keyEquivalent: "")
        options.submenu = optionsMenu
        menu.addItem(options)

        if item.isRunning {
            menu.addItem(.separator())

            let hideItem = NSMenuItem(title: "Hide", action: #selector(hideApp), keyEquivalent: "")
            hideItem.target = self
            menu.addItem(hideItem)

            menu.addItem(.separator())

            let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
            quitItem.target = self
            menu.addItem(quitItem)

            let forceQuit = NSMenuItem(title: "Force Quit", action: #selector(forceQuitApp), keyEquivalent: "")
            forceQuit.target = self
            menu.addItem(forceQuit)
        }

        return menu
    }

    @objc private func showAllWindows() {
        let app = item.runningApp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            app?.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
    }

    @objc private func hideApp() {
        item.runningApp?.hide()
    }

    @objc private func quitApp() {
        item.runningApp?.terminate()
    }

    @objc private func forceQuitApp() {
        item.runningApp?.forceTerminate()
    }

    @objc private func showInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func isOpenAtLogin() -> Bool {
        // Check if app is in login items via SMAppService-style check
        let loginItems = UserDefaults(suiteName: "loginwindow")?.array(forKey: "AutoLaunchedApplicationDictionary") as? [[String: Any]] ?? []
        return loginItems.contains { ($0["Path"] as? String)?.contains(item.name) == true }
    }

    @objc private func toggleOpenAtLogin() {
        // Open Login Items preference pane for the user to manage
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
    }

    // MARK: - Click handling

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = trackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            imageView.animator().alphaValue = 0.85
        }
        imageView.layer?.setAffineTransform(CGAffineTransform(scaleX: 1.12, y: 1.12))
    }

    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            imageView.animator().alphaValue = 1.0
        }
        imageView.layer?.setAffineTransform(.identity)
    }

    override func mouseDown(with event: NSEvent) {
        imageView.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.9, y: 0.9))
    }

    override func mouseUp(with event: NSEvent) {
        imageView.layer?.setAffineTransform(.identity)
        let loc = convert(event.locationInWindow, from: nil)
        if bounds.contains(loc) {
            launchOrFocus()
        }
    }

    @objc func launchOrFocus() {
        if let running = item.runningApp, DockReader.hasWindows(pid: running.processIdentifier) {
            // App is running and has windows — bring them to front
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                running.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
                if AXIsProcessTrusted() {
                    let axApp = AXUIElementCreateApplication(running.processIdentifier)
                    var windowsRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                       let windows = windowsRef as? [AXUIElement] {
                        for window in windows {
                            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
                        }
                    }
                }
            }
        } else {
            // Not running, or running but no windows — open fresh
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: item.url, configuration: cfg) { _, _ in }
        }
    }
}
