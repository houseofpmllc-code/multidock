import AppKit

class DockWindow: NSPanel {
    private let targetScreen: NSScreen
    private var pinnedItems: [DockItem] = []
    private var runningItems: [DockItem] = []
    private var orientation: String = "bottom"
    private var iconSize: CGFloat = 52

    private var backgroundView: NSVisualEffectView!
    private var stackView: NSStackView!

    private let itemSpacing: CGFloat = 6

    init(screen: NSScreen, pinnedItems: [DockItem], runningItems: [DockItem], orientation: String, iconSize: CGFloat) {
        self.targetScreen = screen
        self.pinnedItems = pinnedItems
        self.runningItems = runningItems
        self.orientation = orientation
        self.iconSize = iconSize

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configure()
        buildContent()
        updateFrame()
    }

    private func configure() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .init(Int(CGWindowLevelForKey(.dockWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isMovable = false
        acceptsMouseMovedEvents = true
    }

    private func buildContent() {
        let isVertical = (orientation == "left" || orientation == "right")

        backgroundView = NSVisualEffectView()
        backgroundView.material = .hudWindow
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 18
        backgroundView.layer?.masksToBounds = true
        contentView = backgroundView

        stackView = NSStackView()
        stackView.orientation = isVertical ? .vertical : .horizontal
        stackView.alignment = isVertical ? .centerX : .centerY
        stackView.spacing = itemSpacing
        let pad = sidePadding(for: iconSize)
        stackView.edgeInsets = NSEdgeInsets(top: pad, left: pad, bottom: pad, right: pad)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor),
        ])

        populateItems()
    }

    private func populateItems() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let effSize = effectiveIconSize()

        for item in pinnedItems {
            stackView.addArrangedSubview(DockItemButton(item: item, iconSize: effSize))
        }

        if !runningItems.isEmpty {
            stackView.addArrangedSubview(makeSeparator())
            for item in runningItems {
                stackView.addArrangedSubview(DockItemButton(item: item, iconSize: effSize))
            }
        }
    }

    private func makeSeparator() -> NSView {
        let isVertical = (orientation == "left" || orientation == "right")
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        if isVertical {
            sep.widthAnchor.constraint(equalToConstant: iconSize * 0.6).isActive = true
            sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
        } else {
            sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
            sep.heightAnchor.constraint(equalToConstant: iconSize * 0.6).isActive = true
        }
        return sep
    }

    private func allItems() -> [DockItem] { pinnedItems + runningItems }

    /// Computes the effective icon size, shrinking if needed to fit within the screen
    private func effectiveIconSize() -> CGFloat {
        let sf = targetScreen.frame
        let isVertical = (orientation == "left" || orientation == "right")
        let minIconSize: CGFloat = 18
        let available = (isVertical ? sf.height : sf.width) - 80

        var size = iconSize
        // Each slot: icon + spacing. Separator counts as 1px + spacing.
        while size > minIconSize {
            let slotSize = size + itemSpacing
            let sepSize: CGFloat = runningItems.isEmpty ? 0 : (1 + itemSpacing)
            let needed = CGFloat(pinnedItems.count + runningItems.count) * slotSize + sepSize + 2 * sidePadding(for: size)
            if needed <= available { break }
            size -= 2
        }
        return max(size, minIconSize)
    }

    private func sidePadding(for size: CGFloat) -> CGFloat { size * 0.25 }

    private func updateFrame() {
        let sf = targetScreen.frame
        let isVertical = (orientation == "left" || orientation == "right")
        let effSize = effectiveIconSize()
        let effPadding = sidePadding(for: effSize)
        let separatorSlots: CGFloat = runningItems.isEmpty ? 0 : 1
        let frame: NSRect

        if isVertical {
            let slotH = effSize + 7 + itemSpacing
            let contentLength = CGFloat(pinnedItems.count + runningItems.count) * slotH + separatorSlots * (1 + itemSpacing) + 2 * effPadding
            let h = min(contentLength, sf.height - 80)
            let w = effSize + 28
            let x = (orientation == "left") ? sf.minX : sf.maxX - w
            let y = sf.midY - h / 2
            frame = NSRect(x: x, y: y, width: w, height: h)
        } else {
            let slotW = effSize + itemSpacing
            let contentLength = CGFloat(pinnedItems.count + runningItems.count) * slotW + separatorSlots * (1 + itemSpacing) + 2 * effPadding
            let w = min(contentLength, sf.width - 40)
            let h = effSize + 28
            let x = sf.midX - w / 2
            let y = sf.minY
            frame = NSRect(x: x, y: y, width: w, height: h)
        }

        setFrame(frame, display: true)
    }

    func show() { orderFrontRegardless() }

    func update(pinnedItems: [DockItem], runningItems: [DockItem], orientation: String, iconSize: CGFloat) {
        let rebuildNeeded = self.orientation != orientation || self.iconSize != iconSize
        self.pinnedItems = pinnedItems
        self.runningItems = runningItems
        self.orientation = orientation
        self.iconSize = iconSize

        if rebuildNeeded {
            buildContent()
        } else {
            populateItems()
        }
        updateFrame()
    }
}
