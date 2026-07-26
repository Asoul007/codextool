import AppKit
import CodexQuotaCore
import SwiftUI

final class FloatingWindowController: NSObject, NSWindowDelegate {
    private let state: AppState
    private var panels: [DisplayMode: NSPanel] = [:]
    private var hostingControllers: [DisplayMode: NSHostingController<AnyView>] = [:]
    private var renderSignatures: [DisplayMode: String] = [:]
    private var snapWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]

    init(state: AppState) {
        self.state = state
    }

    func syncWindows(rebuild: Bool = false) {
        let supportedFloatingModes = Set(DisplayMode.configurableCases.filter { $0 != .menuBar })
        let desiredModes = Set(state.settings.activeModes.filter { supportedFloatingModes.contains($0) })
        let hiddenModeTitles = Set(DisplayMode.allCases
            .filter { $0 != .menuBar && !desiredModes.contains($0) }
            .map(\.label))

        if rebuild {
            closeAllFloatingWindows()
        }

        for mode in DisplayMode.configurableCases where mode != .menuBar {
            if desiredModes.contains(mode) {
                show(mode)
            } else {
                close(mode)
            }
        }

        for mode in Array(panels.keys) where !supportedFloatingModes.contains(mode) {
            close(mode)
        }

        for window in NSApp.windows where hiddenModeTitles.contains(window.title) {
            window.orderOut(nil)
            window.close()
        }

        for panel in panels.values {
            panel.level = state.settings.alwaysOnTop ? .floating : .normal
        }
    }

    func refreshVisibleWindows() {
        for (mode, controller) in hostingControllers {
            controller.rootView = AnyView(rootView(for: mode))
            panels[mode]?.contentView?.layer?.cornerRadius = cornerRadius(for: mode)
            panels[mode]?.setContentSize(contentSize(for: mode, hostingView: controller.view))
        }
    }

    private func show(_ mode: DisplayMode) {
        if let controller = hostingControllers[mode] {
            let signature = renderSignature(for: mode)
            if renderSignatures[mode] != signature {
                close(mode)
                show(mode)
                return
            }

            controller.rootView = AnyView(rootView(for: mode))
            if let panel = panels[mode] {
                panel.contentView?.layer?.cornerRadius = cornerRadius(for: mode)
                panel.setContentSize(contentSize(for: mode, hostingView: controller.view))
            }
            panels[mode]?.orderFrontRegardless()
            return
        }

        let panel = FloatingPanel()
        panel.isReleasedWhenClosed = false
        let hostingController = NSHostingController(rootView: AnyView(rootView(for: mode)))
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController
        panel.title = mode.label
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.cornerRadius = cornerRadius(for: mode)
        panel.contentView?.layer?.masksToBounds = true
        panel.hasShadow = false
        panel.level = state.settings.alwaysOnTop ? .floating : .normal
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.delegate = self
        panel.setContentSize(contentSize(for: mode, hostingView: hostingController.view))
        panel.setFrameOrigin(defaultOrigin(for: mode, size: panel.frame.size))
        panel.orderFrontRegardless()

        panels[mode] = panel
        hostingControllers[mode] = hostingController
        renderSignatures[mode] = renderSignature(for: mode)
    }

    private func rootView(for mode: DisplayMode) -> some View {
        view(for: mode)
            .background(Color.clear)
            .fixedSize()
    }

    private func close(_ mode: DisplayMode) {
        if let panel = panels[mode] {
            destroy(panel)
        }
        panels[mode] = nil
        hostingControllers[mode] = nil
        renderSignatures[mode] = nil

        for window in NSApp.windows where window.title == mode.label {
            destroy(window)
        }
    }

    private func closeAllFloatingWindows() {
        snapWorkItems.values.forEach { $0.cancel() }
        snapWorkItems.removeAll()

        for panel in Array(panels.values) {
            destroy(panel)
        }
        panels.removeAll()
        hostingControllers.removeAll()
        renderSignatures.removeAll()

        let floatingTitles = Set(DisplayMode.allCases.filter { $0 != .menuBar }.map(\.label))
        for window in NSApp.windows where floatingTitles.contains(window.title) {
            destroy(window)
        }
    }

    private func destroy(_ window: NSWindow) {
        snapWorkItems[ObjectIdentifier(window)]?.cancel()
        snapWorkItems[ObjectIdentifier(window)] = nil
        window.orderOut(nil)
        window.delegate = nil
        window.contentViewController = nil
        window.close()
    }

    private func view(for mode: DisplayMode) -> some View {
        Group {
            switch mode {
            case .floatingOrb:
                FloatingOrbView(state: state)
            case .floatingCapsule:
                FloatingCapsuleView(state: state)
            case .developerHUD:
                DeveloperHUDView(state: state)
            case .menuBar:
                EmptyView()
            }
        }
    }

    private func contentSize(for mode: DisplayMode, hostingView: NSView) -> NSSize {
        let fitting = hostingView.fittingSize
        switch mode {
        case .floatingOrb:
            let minimum: CGFloat = state.theme.id == "liquid_energy" ? 170 : 124
            return NSSize(width: max(minimum, fitting.width), height: max(minimum, fitting.height))
        case .floatingCapsule:
            return NSSize(width: max(462, fitting.width), height: max(64, fitting.height))
        case .developerHUD:
            let minimumWidth: CGFloat = state.theme.id == "liquid_energy" ? 620 : 710
            let minimumHeight: CGFloat = state.theme.id == "liquid_energy" ? 438 : 520
            return NSSize(width: max(minimumWidth, fitting.width), height: max(minimumHeight, fitting.height))
        case .menuBar:
            return .zero
        }
    }

    private func cornerRadius(for mode: DisplayMode) -> CGFloat {
        switch mode {
        case .floatingOrb: return state.theme.id == "liquid_energy" ? 85 : 62
        case .floatingCapsule: return 32
        case .developerHUD: return 36
        case .menuBar: return 0
        }
    }

    private func defaultOrigin(for mode: DisplayMode, size: NSSize) -> NSPoint {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        switch mode {
        case .floatingOrb:
            return NSPoint(x: screen.maxX - size.width - 36, y: screen.maxY - size.height - 36)
        case .floatingCapsule:
            return NSPoint(x: screen.maxX - size.width - 50, y: screen.maxY - size.height - 28)
        case .developerHUD:
            return NSPoint(x: screen.maxX - size.width - 50, y: screen.maxY - size.height - 48)
        case .menuBar:
            return .zero
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        scheduleSnap(for: panel)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedPanel = notification.object as? NSPanel else { return }
        snapWorkItems[ObjectIdentifier(closedPanel)]?.cancel()
        snapWorkItems[ObjectIdentifier(closedPanel)] = nil

        for (mode, panel) in panels where panel === closedPanel {
            panels[mode] = nil
            hostingControllers[mode] = nil
            renderSignatures[mode] = nil
        }
    }

    private func scheduleSnap(for panel: NSPanel) {
        guard state.settings.snapToEdge,
              let screen = panel.screen?.visibleFrame else {
            return
        }

        let id = ObjectIdentifier(panel)
        snapWorkItems[id]?.cancel()
        let frameAtMove = panel.frame

        let workItem = DispatchWorkItem { [weak self, weak panel] in
            guard let self,
                  let panel,
                  self.state.settings.snapToEdge,
                  panel.isVisible,
                  panel.frame == frameAtMove else {
                return
            }

            var frame = panel.frame
            let threshold: CGFloat = 90
            let left = abs(frame.minX - screen.minX)
            let right = abs(screen.maxX - frame.maxX)
            let top = abs(screen.maxY - frame.maxY)
            let bottom = abs(frame.minY - screen.minY)

            if min(left, right) < threshold {
                frame.origin.x = left <= right ? screen.minX : screen.maxX - frame.width
            }

            if min(top, bottom) < threshold {
                frame.origin.y = top <= bottom ? screen.maxY - frame.height : screen.minY
            }

            guard frame.origin != panel.frame.origin else { return }
            panel.setFrame(frame, display: true, animate: true)
        }

        snapWorkItems[id] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: workItem)
    }

    private func renderSignature(for mode: DisplayMode) -> String {
        [
            mode.rawValue,
            state.theme.id,
            state.theme.primaryColor,
            state.theme.secondaryColor,
            state.theme.successColor,
            state.theme.glassTint,
            state.settings.transparencyMode.rawValue,
            state.settings.menuBarShowsFiveHour ? "5h:1" : "5h:0",
            state.settings.menuBarShowsWeekly ? "w:1" : "w:0",
            state.settings.menuBarShowsReset ? "r:1" : "r:0"
        ].joined(separator: "|")
    }
}

final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
