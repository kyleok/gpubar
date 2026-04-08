import AppKit
import SwiftUI

enum ClusterMenuSelection: Equatable, Hashable {
    case overview
    case cluster(String)

    var storageValue: String {
        switch self {
        case .overview:
            return "overview"
        case let .cluster(clusterID):
            return "cluster:\(clusterID.lowercased())"
        }
    }

    static func from(storageValue: String) -> ClusterMenuSelection? {
        if storageValue == "overview" {
            return .overview
        }
        if storageValue.hasPrefix("cluster:") {
            return .cluster(String(storageValue.dropFirst("cluster:".count)))
        }
        return nil
    }
}

struct ClusterSwitcherItem: Hashable {
    let selection: ClusterMenuSelection
    let title: String
    let image: NSImage
    let accentColor: NSColor
    let availabilityPercent: Double?
}

struct ClusterSwitcherRepresentable: NSViewRepresentable {
    let items: [ClusterSwitcherItem]
    let selected: ClusterMenuSelection
    let width: CGFloat
    let showsIcons: Bool
    let onSelect: (ClusterMenuSelection) -> Void

    func makeNSView(context: Context) -> ClusterSwitcherView {
        ClusterSwitcherView(
            items: self.items,
            selected: self.selected,
            width: self.width,
            showsIcons: self.showsIcons,
            onSelect: self.onSelect)
    }

    func updateNSView(_ nsView: ClusterSwitcherView, context: Context) {}
}

final class PaddedToggleButton: NSButton {
    var contentPadding = NSEdgeInsets(top: 4, left: 7, bottom: 4, right: 7) {
        didSet {
            if oldValue.top != self.contentPadding.top ||
                oldValue.left != self.contentPadding.left ||
                oldValue.bottom != self.contentPadding.bottom ||
                oldValue.right != self.contentPadding.right
            {
                self.invalidateIntrinsicContentSize()
            }
        }
    }

    override var intrinsicContentSize: NSSize {
        let size = super.intrinsicContentSize
        return NSSize(
            width: size.width + self.contentPadding.left + self.contentPadding.right,
            height: size.height + self.contentPadding.top + self.contentPadding.bottom)
    }
}

final class InlineIconToggleButton: NSButton {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    private var paddingConstraints: [NSLayoutConstraint] = []
    private var iconSizeConstraints: [NSLayoutConstraint] = []
    private var isConfiguring = false

    var contentPadding = NSEdgeInsets(top: 4, left: 7, bottom: 4, right: 7) {
        didSet {
            self.paddingConstraints.first { $0.firstAttribute == .top }?.constant = self.contentPadding.top
            self.paddingConstraints.first { $0.firstAttribute == .leading }?.constant = self.contentPadding.left
            self.paddingConstraints.first { $0.firstAttribute == .trailing }?.constant = -self.contentPadding.right
            self.paddingConstraints.first { $0.firstAttribute == .bottom }?.constant = -(self.contentPadding.bottom + 4)
            if !self.isConfiguring { self.invalidateIntrinsicContentSize() }
        }
    }

    override var title: String {
        get { "" }
        set {
            super.title = ""
            super.alternateTitle = ""
            super.attributedTitle = NSAttributedString(string: "")
            super.attributedAlternateTitle = NSAttributedString(string: "")
            self.titleField.stringValue = newValue
            if !self.isConfiguring { self.invalidateIntrinsicContentSize() }
        }
    }

    override var image: NSImage? {
        get { nil }
        set {
            super.image = nil
            super.alternateImage = nil
            self.iconView.image = newValue
            if !self.isConfiguring { self.invalidateIntrinsicContentSize() }
        }
    }

    func setContentTintColor(_ color: NSColor?) {
        self.iconView.contentTintColor = color
        self.titleField.textColor = color
    }

    func setTitleFontSize(_ size: CGFloat) {
        self.titleField.font = NSFont.systemFont(ofSize: size)
    }

    override var intrinsicContentSize: NSSize {
        let size = self.stack.fittingSize
        return NSSize(
            width: size.width + self.contentPadding.left + self.contentPadding.right,
            height: size.height + self.contentPadding.top + self.contentPadding.bottom)
    }

    init(title: String, image: NSImage, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        self.isConfiguring = true
        self.configure()
        self.title = title
        self.image = image
        self.isConfiguring = false
        self.invalidateIntrinsicContentSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func configure() {
        self.bezelStyle = .regularSquare
        self.isBordered = false
        self.setButtonType(.toggle)
        self.controlSize = .small
        self.wantsLayer = true

        self.iconView.imageScaling = .scaleNone
        self.iconView.translatesAutoresizingMaskIntoConstraints = false
        self.titleField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        self.titleField.alignment = .left
        self.titleField.lineBreakMode = .byTruncatingTail
        self.titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        self.titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        self.setContentTintColor(NSColor.secondaryLabelColor)

        self.stack.orientation = .horizontal
        self.stack.alignment = .centerY
        self.stack.spacing = 1
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.stack.addArrangedSubview(self.iconView)
        self.stack.addArrangedSubview(self.titleField)
        self.addSubview(self.stack)

        let iconWidth = self.iconView.widthAnchor.constraint(equalToConstant: 16)
        let iconHeight = self.iconView.heightAnchor.constraint(equalToConstant: 16)
        self.iconSizeConstraints = [iconWidth, iconHeight]

        let top = self.stack.topAnchor.constraint(equalTo: self.topAnchor, constant: self.contentPadding.top)
        let leading = self.stack.leadingAnchor.constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: self.contentPadding.left)
        let trailing = self.stack.trailingAnchor.constraint(lessThanOrEqualTo: self.trailingAnchor, constant: -self.contentPadding.right)
        let centerX = self.stack.centerXAnchor.constraint(equalTo: self.centerXAnchor)
        centerX.priority = .defaultHigh
        let bottom = self.stack.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor, constant: -(self.contentPadding.bottom + 4))
        self.paddingConstraints = [top, leading, trailing, bottom, centerX]

        NSLayoutConstraint.activate(self.paddingConstraints + self.iconSizeConstraints)
    }
}

final class StackedToggleButton: NSButton {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    private var paddingConstraints: [NSLayoutConstraint] = []
    private var iconSizeConstraints: [NSLayoutConstraint] = []
    private var isConfiguring = false

    var contentPadding = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4) {
        didSet {
            self.paddingConstraints.first { $0.firstAttribute == .top }?.constant = self.contentPadding.top
            self.paddingConstraints.first { $0.firstAttribute == .leading }?.constant = self.contentPadding.left
            self.paddingConstraints.first { $0.firstAttribute == .trailing }?.constant = -self.contentPadding.right
            self.paddingConstraints.first { $0.firstAttribute == .bottom }?.constant = -self.contentPadding.bottom
            if !self.isConfiguring { self.invalidateIntrinsicContentSize() }
        }
    }

    override var title: String {
        get { "" }
        set {
            super.title = ""
            super.alternateTitle = ""
            super.attributedTitle = NSAttributedString(string: "")
            super.attributedAlternateTitle = NSAttributedString(string: "")
            self.titleField.stringValue = newValue
            if !self.isConfiguring { self.invalidateIntrinsicContentSize() }
        }
    }

    override var image: NSImage? {
        get { nil }
        set {
            super.image = nil
            super.alternateImage = nil
            self.iconView.image = newValue
            if !self.isConfiguring { self.invalidateIntrinsicContentSize() }
        }
    }

    func setContentTintColor(_ color: NSColor?) {
        self.iconView.contentTintColor = color
        self.titleField.textColor = color
    }

    func setTitleFontSize(_ size: CGFloat) {
        self.titleField.font = NSFont.systemFont(ofSize: size)
    }

    func setAllowsTwoLineTitle(_ allow: Bool) {
        let hasWhitespace = self.titleField.stringValue.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
        let shouldWrap = allow && hasWhitespace
        self.titleField.maximumNumberOfLines = shouldWrap ? 2 : 1
        self.titleField.usesSingleLineMode = !shouldWrap
        self.titleField.lineBreakMode = shouldWrap ? .byWordWrapping : .byTruncatingTail
    }

    override var intrinsicContentSize: NSSize {
        let size = self.stack.fittingSize
        return NSSize(
            width: size.width + self.contentPadding.left + self.contentPadding.right,
            height: size.height + self.contentPadding.top + self.contentPadding.bottom)
    }

    init(title: String, image: NSImage, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.target = target
        self.action = action
        self.isConfiguring = true
        self.configure()
        self.title = title
        self.image = image
        self.isConfiguring = false
        self.invalidateIntrinsicContentSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func configure() {
        self.bezelStyle = .regularSquare
        self.isBordered = false
        self.setButtonType(.toggle)
        self.controlSize = .small
        self.wantsLayer = true

        self.iconView.imageScaling = .scaleNone
        self.iconView.translatesAutoresizingMaskIntoConstraints = false
        self.titleField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize - 2)
        self.titleField.alignment = .center
        self.titleField.lineBreakMode = .byTruncatingTail
        self.titleField.maximumNumberOfLines = 1
        self.titleField.usesSingleLineMode = true
        self.setContentTintColor(NSColor.secondaryLabelColor)

        self.stack.orientation = .vertical
        self.stack.alignment = .centerX
        self.stack.spacing = 0
        self.stack.translatesAutoresizingMaskIntoConstraints = false
        self.stack.addArrangedSubview(self.iconView)
        self.stack.addArrangedSubview(self.titleField)
        self.addSubview(self.stack)

        let iconWidth = self.iconView.widthAnchor.constraint(equalToConstant: 16)
        let iconHeight = self.iconView.heightAnchor.constraint(equalToConstant: 16)
        self.iconSizeConstraints = [iconWidth, iconHeight]

        let top = self.stack.topAnchor.constraint(equalTo: self.topAnchor, constant: self.contentPadding.top)
        let leading = self.stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: self.contentPadding.left)
        let trailing = self.stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -self.contentPadding.right)
        let bottom = self.stack.bottomAnchor.constraint(lessThanOrEqualTo: self.bottomAnchor, constant: -(self.contentPadding.bottom + 4))
        self.paddingConstraints = [top, leading, trailing, bottom]

        NSLayoutConstraint.activate(self.paddingConstraints + self.iconSizeConstraints)
    }
}

final class ClusterSwitcherView: NSView {
    private struct Segment {
        let selection: ClusterMenuSelection
        let image: NSImage
        let title: String
        let accentColor: NSColor
        let availabilityPercent: Double?
    }

    private struct WeeklyIndicator {
        let track: NSView
        let fill: NSView
    }

    private let segments: [Segment]
    private let onSelect: (ClusterMenuSelection) -> Void
    private let showsIcons: Bool
    private var buttons: [NSButton] = []
    private var weeklyIndicators: [ObjectIdentifier: WeeklyIndicator] = [:]
    private var hoverTrackingArea: NSTrackingArea?
    private var segmentWidths: [CGFloat] = []
    private let selectedBackground = NSColor.controlAccentColor.cgColor
    private let unselectedBackground = NSColor.clear.cgColor
    private let selectedTextColor = NSColor.white
    private let unselectedTextColor = NSColor.secondaryLabelColor
    private let stackedIcons: Bool
    private let rowCount: Int
    private let rowSpacing: CGFloat
    private let rowHeight: CGFloat
    private var preferredWidth: CGFloat = 0
    private var hoveredButtonTag: Int?
    private let lightModeOverlayLayer = CALayer()

    init(
        items: [ClusterSwitcherItem],
        selected: ClusterMenuSelection?,
        width: CGFloat,
        showsIcons: Bool,
        onSelect: @escaping (ClusterMenuSelection) -> Void)
    {
        let minimumGap: CGFloat = 1
        self.segments = items.map { item in
            item.image.isTemplate = true
            item.image.size = NSSize(width: 16, height: 16)
            return Segment(
                selection: item.selection,
                image: item.image,
                title: item.title,
                accentColor: item.accentColor,
                availabilityPercent: item.availabilityPercent)
        }
        self.onSelect = onSelect
        self.showsIcons = showsIcons
        self.stackedIcons = showsIcons && self.segments.count > 3
        let initialOuterPadding = Self.switcherOuterPadding(for: width, count: self.segments.count, minimumGap: minimumGap)
        let initialMaxAllowedSegmentWidth = Self.maxAllowedUniformSegmentWidth(
            for: width,
            count: self.segments.count,
            outerPadding: initialOuterPadding,
            minimumGap: minimumGap)
        self.rowCount = Self.switcherRowCount(
            width: width,
            count: self.segments.count,
            maxAllowedSegmentWidth: initialMaxAllowedSegmentWidth,
            stackedIcons: self.stackedIcons)
        self.rowSpacing = self.stackedIcons ? 4 : 2
        self.rowHeight = self.stackedIcons && self.rowCount >= 3 ? 40 : (self.stackedIcons ? 36 : 30)
        let height = Self.preferredHeight(
            itemCount: self.segments.count,
            width: width,
            showsIcons: showsIcons)
        self.preferredWidth = width
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        Self.clearButtonWidthCache()
        self.wantsLayer = true
        self.layer?.masksToBounds = false
        self.lightModeOverlayLayer.masksToBounds = false
        self.layer?.insertSublayer(self.lightModeOverlayLayer, at: 0)
        self.updateLightModeStyling()

        let layoutCount = Self.layoutCount(for: self.segments.count, rows: self.rowCount)
        let outerPadding = Self.switcherOuterPadding(for: width, count: layoutCount, minimumGap: minimumGap)
        let maxAllowedSegmentWidth = Self.maxAllowedUniformSegmentWidth(
            for: width,
            count: layoutCount,
            outerPadding: outerPadding,
            minimumGap: minimumGap)

        for (index, segment) in self.segments.enumerated() {
            let button = self.makeButton(index: index, segment: segment, selected: selected)
            self.addSubview(button)
        }

        let uniformWidth: CGFloat
        if self.rowCount > 1 || !self.stackedIcons {
            uniformWidth = self.applyUniformSegmentWidth(maxAllowedWidth: maxAllowedSegmentWidth)
            if uniformWidth > 0 {
                self.segmentWidths = Array(repeating: uniformWidth, count: self.buttons.count)
            }
        } else {
            self.segmentWidths = self.applyNonUniformSegmentWidths(
                totalWidth: width,
                outerPadding: outerPadding,
                minimumGap: minimumGap)
            uniformWidth = 0
        }

        self.applyLayout(outerPadding: outerPadding, minimumGap: minimumGap, uniformWidth: uniformWidth)
        self.updateButtonStyles()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: self.preferredWidth, height: self.frame.size.height)
    }

    override func layout() {
        super.layout()
        self.lightModeOverlayLayer.frame = self.bounds
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        self.updateLightModeStyling()
        self.updateButtonStyles()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        self.window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            self.removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil)
        self.addTrackingArea(trackingArea)
        self.hoverTrackingArea = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        let location = self.convert(event.locationInWindow, from: nil)
        let hoveredTag = self.buttons.first(where: { $0.frame.contains(location) })?.tag
        guard hoveredTag != self.hoveredButtonTag else { return }
        self.hoveredButtonTag = hoveredTag
        self.updateButtonStyles()
    }

    override func mouseExited(with event: NSEvent) {
        guard self.hoveredButtonTag != nil else { return }
        self.hoveredButtonTag = nil
        self.updateButtonStyles()
    }

    @objc private func handleSelection(_ sender: NSButton) {
        let index = sender.tag
        guard self.segments.indices.contains(index) else { return }
        for (buttonIndex, button) in self.buttons.enumerated() {
            button.state = buttonIndex == index ? .on : .off
        }
        self.updateButtonStyles()
        self.onSelect(self.segments[index].selection)
    }

    private func makeButton(index: Int, segment: Segment, selected: ClusterMenuSelection?) -> NSButton {
        let button: NSButton
        if self.stackedIcons {
            let stacked = StackedToggleButton(
                title: segment.title,
                image: segment.image,
                target: self,
                action: #selector(self.handleSelection(_:)))
            stacked.setAllowsTwoLineTitle(self.rowCount >= 3)
            if self.rowCount >= 4 {
                stacked.setTitleFontSize(NSFont.smallSystemFontSize - 3)
            }
            button = stacked
        } else if self.showsIcons {
            let inline = InlineIconToggleButton(
                title: segment.title,
                image: segment.image,
                target: self,
                action: #selector(self.handleSelection(_:)))
            button = inline
        } else {
            button = PaddedToggleButton(title: segment.title, target: self, action: #selector(self.handleSelection(_:)))
        }

        button.tag = index
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        button.setButtonType(.toggle)
        button.contentTintColor = self.unselectedTextColor
        button.alignment = .center
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.state = selected == segment.selection ? .on : .off
        button.translatesAutoresizingMaskIntoConstraints = false
        self.buttons.append(button)
        self.addAvailabilityIndicator(to: button, segment: segment)
        return button
    }

    private func applyLayout(outerPadding: CGFloat, minimumGap: CGFloat, uniformWidth: CGFloat) {
        if self.rowCount > 1 {
            self.applyMultiRowLayout(
                rowCount: self.rowCount,
                outerPadding: outerPadding,
                minimumGap: minimumGap,
                uniformWidth: uniformWidth)
            return
        }

        if self.buttons.count >= 2 {
            let widths = self.segmentWidths.isEmpty ? self.buttons.map { ceil($0.fittingSize.width) } : self.segmentWidths
            let availableWidth = max(0, self.preferredWidth - outerPadding * 2)
            let gaps = max(1, widths.count - 1)
            let computedGap = gaps > 0 ? max(minimumGap, (availableWidth - widths.reduce(0, +)) / CGFloat(gaps)) : 0
            let rowContainer = NSView()
            rowContainer.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(rowContainer)

            NSLayoutConstraint.activate([
                rowContainer.topAnchor.constraint(equalTo: self.topAnchor),
                rowContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
                rowContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: outerPadding),
                rowContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -outerPadding),
            ])

            var xOffset: CGFloat = 0
            for (index, button) in self.buttons.enumerated() {
                let width = index < widths.count ? widths[index] : 0
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: rowContainer.leadingAnchor, constant: xOffset),
                    button.centerYAnchor.constraint(equalTo: rowContainer.centerYAnchor),
                ])
                xOffset += width + computedGap
            }
            return
        }

        if let first = self.buttons.first {
            NSLayoutConstraint.activate([
                first.centerXAnchor.constraint(equalTo: self.centerXAnchor),
                first.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            ])
        }
    }

    private func applyMultiRowLayout(rowCount: Int, outerPadding: CGFloat, minimumGap: CGFloat, uniformWidth: CGFloat) {
        let rows = Self.splitRows(for: self.buttons, rowCount: rowCount)
        let columns = rows.map(\.count).max() ?? 0
        let availableWidth = max(0, self.preferredWidth - outerPadding * 2)
        let gaps = max(1, columns - 1)
        let totalWidth = uniformWidth * CGFloat(columns)
        let computedGap = gaps > 0 ? max(minimumGap, (availableWidth - totalWidth) / CGFloat(gaps)) : 0
        let gridContainer = NSView()
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(gridContainer)

        NSLayoutConstraint.activate([
            gridContainer.topAnchor.constraint(equalTo: self.topAnchor),
            gridContainer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            gridContainer.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: outerPadding),
            gridContainer.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -outerPadding),
        ])

        var rowViews: [NSView] = []
        for _ in 0..<rowCount {
            let row = NSView()
            row.translatesAutoresizingMaskIntoConstraints = false
            gridContainer.addSubview(row)
            rowViews.append(row)
        }

        var rowConstraints: [NSLayoutConstraint] = []
        for (index, row) in rowViews.enumerated() {
            rowConstraints.append(row.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor))
            rowConstraints.append(row.trailingAnchor.constraint(equalTo: gridContainer.trailingAnchor))
            rowConstraints.append(row.heightAnchor.constraint(equalToConstant: self.rowHeight))
            if index == 0 {
                rowConstraints.append(row.topAnchor.constraint(equalTo: gridContainer.topAnchor))
            } else {
                rowConstraints.append(row.topAnchor.constraint(equalTo: rowViews[index - 1].bottomAnchor, constant: self.rowSpacing))
            }
            if index == rowViews.count - 1 {
                rowConstraints.append(row.bottomAnchor.constraint(equalTo: gridContainer.bottomAnchor))
            }
        }
        NSLayoutConstraint.activate(rowConstraints)

        for (rowIndex, rowButtons) in rows.enumerated() {
            guard rowIndex < rowViews.count else { continue }
            let rowView = rowViews[rowIndex]
            for (columnIndex, button) in rowButtons.enumerated() {
                let xOffset = CGFloat(columnIndex) * (uniformWidth + computedGap)
                NSLayoutConstraint.activate([
                    button.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor, constant: xOffset),
                    button.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                ])
            }
        }
    }

    private func updateButtonStyles() {
        for button in self.buttons {
            let isSelected = button.state == .on
            let isHovered = self.hoveredButtonTag == button.tag
            button.contentTintColor = isSelected ? self.selectedTextColor : self.unselectedTextColor
            button.layer?.backgroundColor = if isSelected {
                self.selectedBackground
            } else if isHovered {
                self.hoverPlateColor()
            } else {
                self.unselectedBackground
            }
            self.updateAvailabilityIndicatorVisibility(for: button)
            (button as? StackedToggleButton)?.setContentTintColor(button.contentTintColor)
            (button as? InlineIconToggleButton)?.setContentTintColor(button.contentTintColor)
        }
    }

    private func addAvailabilityIndicator(to view: NSView, segment: Segment) {
        guard let availabilityPercent = segment.availabilityPercent else { return }

        let track = NSView()
        track.wantsLayer = true
        track.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.22).cgColor
        track.layer?.cornerRadius = 2
        track.layer?.masksToBounds = true
        track.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(track)

        let fill = NSView()
        fill.wantsLayer = true
        fill.layer?.backgroundColor = segment.accentColor.cgColor
        fill.layer?.cornerRadius = 2
        fill.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(fill)

        let ratio = CGFloat(max(0, min(1, availabilityPercent / 100)))

        NSLayoutConstraint.activate([
            track.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            track.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -6),
            track.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -1),
            track.heightAnchor.constraint(equalToConstant: 4),
            fill.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            fill.topAnchor.constraint(equalTo: track.topAnchor),
            fill.bottomAnchor.constraint(equalTo: track.bottomAnchor),
        ])
        fill.widthAnchor.constraint(equalTo: track.widthAnchor, multiplier: ratio).isActive = true

        self.weeklyIndicators[ObjectIdentifier(view)] = WeeklyIndicator(track: track, fill: fill)
        self.updateAvailabilityIndicatorVisibility(for: view)
    }

    private func updateAvailabilityIndicatorVisibility(for view: NSView) {
        guard let indicator = self.weeklyIndicators[ObjectIdentifier(view)] else { return }
        let isSelected = (view as? NSButton)?.state == .on
        indicator.track.isHidden = isSelected
        indicator.fill.isHidden = isSelected
    }

    private func isLightMode() -> Bool {
        self.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
    }

    private func updateLightModeStyling() {
        guard self.isLightMode() else {
            self.lightModeOverlayLayer.backgroundColor = nil
            return
        }
        self.lightModeOverlayLayer.backgroundColor = NSColor.black.withAlphaComponent(0.035).cgColor
    }

    private func hoverPlateColor() -> CGColor {
        if self.isLightMode() {
            return NSColor.black.withAlphaComponent(0.095).cgColor
        }
        return NSColor.labelColor.withAlphaComponent(0.06).cgColor
    }

    private static var buttonWidthCache: [ObjectIdentifier: CGFloat] = [:]

    private static func maxToggleWidth(for button: NSButton) -> CGFloat {
        let buttonID = ObjectIdentifier(button)
        if let cached = buttonWidthCache[buttonID] {
            return cached
        }

        let originalState = button.state
        defer { button.state = originalState }

        button.state = .off
        button.layoutSubtreeIfNeeded()
        let offWidth = button.fittingSize.width

        button.state = .on
        button.layoutSubtreeIfNeeded()
        let onWidth = button.fittingSize.width

        let maxWidth = max(offWidth, onWidth)
        buttonWidthCache[buttonID] = maxWidth
        return maxWidth
    }

    private static func clearButtonWidthCache() {
        buttonWidthCache.removeAll()
    }

    private func applyUniformSegmentWidth(maxAllowedWidth: CGFloat) -> CGFloat {
        guard !self.buttons.isEmpty else { return 0 }

        var desiredWidths: [CGFloat] = []
        desiredWidths.reserveCapacity(self.buttons.count)

        for (index, button) in self.buttons.enumerated() {
            if self.stackedIcons, self.segments.indices.contains(index) {
                let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                let titleWidth = ceil((self.segments[index].title as NSString).size(withAttributes: [.font: font]).width)
                desiredWidths.append(ceil(titleWidth + 9))
            } else {
                desiredWidths.append(ceil(Self.maxToggleWidth(for: button)))
            }
        }

        let maxDesired = desiredWidths.max() ?? 0
        let evenMaxDesired = maxDesired.truncatingRemainder(dividingBy: 2) == 0 ? maxDesired : maxDesired + 1
        let evenMaxAllowed = maxAllowedWidth > 0
            ? (maxAllowedWidth.truncatingRemainder(dividingBy: 2) == 0 ? maxAllowedWidth : maxAllowedWidth - 1)
            : 0
        let finalWidth = evenMaxAllowed > 0 ? min(evenMaxDesired, evenMaxAllowed) : evenMaxDesired

        if finalWidth > 0 {
            for button in self.buttons {
                button.widthAnchor.constraint(equalToConstant: finalWidth).isActive = true
            }
        }
        return finalWidth
    }

    @discardableResult
    private func applyNonUniformSegmentWidths(totalWidth: CGFloat, outerPadding: CGFloat, minimumGap: CGFloat) -> [CGFloat] {
        guard !self.buttons.isEmpty else { return [] }

        let count = self.buttons.count
        let available = totalWidth - outerPadding * 2 - minimumGap * CGFloat(max(0, count - 1))
        guard available > 0 else { return [] }

        func evenFloor(_ value: CGFloat) -> CGFloat {
            var rounded = floor(value)
            if Int(rounded) % 2 != 0 { rounded -= 1 }
            return rounded
        }

        let desired = self.buttons.map { ceil(Self.maxToggleWidth(for: $0)) }
        let desiredSum = desired.reduce(0, +)
        let average = floor(available / CGFloat(count))
        let minWidth = max(24, min(40, average))

        var widths: [CGFloat]
        if desiredSum <= available {
            widths = desired
        } else {
            let totalCapacity = max(0, desiredSum - minWidth * CGFloat(count))
            if totalCapacity <= 0 {
                widths = Array(repeating: available / CGFloat(count), count: count)
            } else {
                let overflow = desiredSum - available
                widths = desired.map { desiredWidth in
                    let capacity = max(0, desiredWidth - minWidth)
                    let shrink = overflow * (capacity / totalCapacity)
                    return desiredWidth - shrink
                }
            }
        }

        widths = widths.map { max(minWidth, evenFloor($0)) }
        var used = widths.reduce(0, +)

        while available - used >= 2 {
            if let best = widths.indices
                .filter({ desired[$0] - widths[$0] >= 2 })
                .max(by: { desired[$0] - widths[$0] < desired[$1] - widths[$1] })
            {
                widths[best] += 2
                used += 2
                continue
            }

            guard let best = widths.indices.min(by: { widths[$0] < widths[$1] }) else { break }
            widths[best] += 2
            used += 2
        }

        for (index, button) in self.buttons.enumerated() where index < widths.count {
            button.widthAnchor.constraint(equalToConstant: widths[index]).isActive = true
        }

        return widths
    }

    static func preferredHeight(itemCount: Int, width: CGFloat, showsIcons: Bool) -> CGFloat {
        let stackedIcons = showsIcons && itemCount > 3
        let minimumGap: CGFloat = 1
        let initialOuterPadding = Self.switcherOuterPadding(for: width, count: itemCount, minimumGap: minimumGap)
        let initialMaxAllowedSegmentWidth = Self.maxAllowedUniformSegmentWidth(
            for: width,
            count: itemCount,
            outerPadding: initialOuterPadding,
            minimumGap: minimumGap)
        let rowCount = Self.switcherRowCount(
            width: width,
            count: itemCount,
            maxAllowedSegmentWidth: initialMaxAllowedSegmentWidth,
            stackedIcons: stackedIcons)
        let rowSpacing: CGFloat = stackedIcons ? 4 : 2
        let rowHeight: CGFloat = stackedIcons && rowCount >= 3 ? 40 : (stackedIcons ? 36 : 30)
        let totalRowHeight = rowHeight * CGFloat(rowCount)
        let totalSpacing = rowSpacing * CGFloat(max(0, rowCount - 1))
        return totalRowHeight + totalSpacing
    }

    private static func switcherRowCount(width: CGFloat, count: Int, maxAllowedSegmentWidth: CGFloat, stackedIcons: Bool) -> Int {
        guard count > 1 else { return 1 }
        let maxRows = min(4, count)
        let fourRowThreshold = 15
        let minimumComfortableAverage: CGFloat = stackedIcons ? 50 : 54
        if count >= fourRowThreshold { return maxRows }
        if maxAllowedSegmentWidth >= minimumComfortableAverage { return 1 }

        for rows in 2...maxRows {
            let perRow = self.layoutCount(for: count, rows: rows)
            let outerPadding = self.switcherOuterPadding(for: width, count: perRow, minimumGap: 1)
            let allowedWidth = self.maxAllowedUniformSegmentWidth(
                for: width,
                count: perRow,
                outerPadding: outerPadding,
                minimumGap: 1)
            if allowedWidth >= minimumComfortableAverage { return rows }
        }
        return maxRows
    }

    private static func layoutCount(for count: Int, rows: Int) -> Int {
        guard rows > 0 else { return count }
        return Int(ceil(Double(count) / Double(rows)))
    }

    private static func splitRows(for buttons: [NSButton], rowCount: Int) -> [[NSButton]] {
        guard rowCount > 1 else { return [buttons] }
        let base = buttons.count / rowCount
        let extra = buttons.count % rowCount
        var rows: [[NSButton]] = []
        var start = 0
        for index in 0..<rowCount {
            let size = base + (index < extra ? 1 : 0)
            if size == 0 {
                rows.append([])
                continue
            }
            let end = min(buttons.count, start + size)
            rows.append(Array(buttons[start..<end]))
            start = end
        }
        return rows
    }

    private static func switcherOuterPadding(for width: CGFloat, count: Int, minimumGap: CGFloat) -> CGFloat {
        let preferred: CGFloat = 16
        let reduced: CGFloat = 10
        let minimal: CGFloat = 6

        func averageButtonWidth(outerPadding: CGFloat) -> CGFloat {
            let available = width - outerPadding * 2 - minimumGap * CGFloat(max(0, count - 1))
            guard count > 0 else { return 0 }
            return available / CGFloat(count)
        }

        let minimumComfortableAverage: CGFloat = count >= 5 ? 50 : 54

        if averageButtonWidth(outerPadding: preferred) >= minimumComfortableAverage { return preferred }
        if averageButtonWidth(outerPadding: reduced) >= minimumComfortableAverage { return reduced }
        return minimal
    }

    private static func maxAllowedUniformSegmentWidth(
        for totalWidth: CGFloat,
        count: Int,
        outerPadding: CGFloat,
        minimumGap: CGFloat) -> CGFloat
    {
        guard count > 0 else { return 0 }
        let available = totalWidth - outerPadding * 2 - minimumGap * CGFloat(max(0, count - 1))
        guard available > 0 else { return 0 }
        return floor(available / CGFloat(count))
    }
}
