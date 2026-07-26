import AppKit
import Combine
import CodexQuotaCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem?
    private var menuPanel: NSPanel?
    private var menuHostingController: NSHostingController<MenuPopoverView>?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var settingsWindow: NSWindow?
    private var floatingController: FloatingWindowController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        terminateOtherRunningCopies()
        NSApp.setActivationPolicy(.accessory)

        floatingController = FloatingWindowController(state: state)
        configureStatusItem()
        configureMenuPanel()
        bindState()
        state.refreshLocalCodexUsage()
        floatingController?.syncWindows(rebuild: true)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        updateStatusTitle()
    }

    private func configureMenuPanel() {
        let controller = NSHostingController(rootView: MenuPopoverView(state: state))
        controller.view.wantsLayer = true
        controller.view.autoresizingMask = [.width, .height]
        controller.view.layer?.cornerRadius = 30
        controller.view.layer?.cornerCurve = .continuous
        controller.view.layer?.masksToBounds = true
        controller.view.layer?.backgroundColor = NSColor.clear.cgColor
        menuHostingController = controller

        let panel = MenuPanel()
        panel.isReleasedWhenClosed = false
        panel.contentViewController = controller
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.cornerRadius = 30
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true
        menuPanel = panel

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self,
                  let panel = self.menuPanel,
                  panel.isVisible,
                  event.window !== panel,
                  event.window !== self.statusItem?.button?.window else {
                return event
            }
            self.closeMenuPanel()
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closeMenuPanel()
        }
    }

    private func bindState() {
        NotificationCenter.default.publisher(for: .codexQuotaOpenSettings)
            .sink { [weak self] _ in self?.openSettings() }
            .store(in: &cancellables)

        state.$settings
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusTitle()
                    self?.floatingController?.syncWindows(rebuild: true)
                }
            }
            .store(in: &cancellables)

        state.$snapshot
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusTitle()
                    self?.floatingController?.refreshVisibleWindows()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusTitle() {
        guard let button = statusItem?.button else { return }
        guard state.settings.activeModes.contains(.menuBar) else {
            button.title = ""
            button.image = menuBarIcon()
            button.imagePosition = .imageOnly
            return
        }

        var parts: [String] = []
        if state.settings.menuBarShowsFiveHour {
            parts.append("5h \(state.snapshot.fiveHourValueText)")
        }
        if state.settings.menuBarShowsWeekly {
            parts.append("W \(state.snapshot.weeklyValueText)")
        }
        if state.settings.menuBarShowsReset {
            parts.append("R \(state.snapshot.resetValueText)")
        }
        if parts.isEmpty {
            button.title = ""
            button.image = menuBarIcon()
            button.imagePosition = .imageOnly
        } else {
            button.image = nil
            button.imagePosition = .noImage
            button.title = parts.joined(separator: " · ")
        }
    }

    private func menuBarIcon() -> NSImage? {
        let image = NSImage(named: "AppIcon") ?? Bundle.main.url(forResource: "AppIcon", withExtension: "icns").flatMap(NSImage.init(contentsOf:))
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        return image
    }

    @objc private func togglePopover() {
        guard menuPanel != nil else { return }
        if menuPanel?.isVisible == true {
            closeMenuPanel()
        } else {
            state.refreshCodexUsage()
            showMenuPanel()
        }
    }

    private func showMenuPanel() {
        guard let button = statusItem?.button,
              let buttonWindow = button.window,
              let panel = menuPanel,
              let controller = menuHostingController else {
            return
        }

        controller.rootView = MenuPopoverView(state: state)
        controller.view.layoutSubtreeIfNeeded()
        let fittingSize = controller.view.fittingSize
        let size = NSSize(
            width: max(380, fittingSize.width),
            height: max(296, fittingSize.height)
        )
        controller.view.frame = NSRect(origin: .zero, size: size)
        panel.setContentSize(size)
        panel.contentView?.frame = NSRect(origin: .zero, size: size)
        controller.view.layoutSubtreeIfNeeded()

        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRect = buttonWindow.convertToScreen(buttonRectInWindow)
        let screen = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let preferredX = buttonRect.midX - size.width / 2
        let x = min(max(preferredX, screen.minX + 8), screen.maxX - size.width - 8)
        let y = buttonRect.minY - size.height - 8
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
    }

    private func closeMenuPanel() {
        menuPanel?.orderOut(nil)
    }

    @objc func openSettings() {
        floatingController?.syncWindows(rebuild: true)
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 720),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.center()
            window.title = "Codex 用量设置"
            window.contentViewController = NSHostingController(rootView: SettingsView(state: state))
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }

    deinit {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }

    private func terminateOtherRunningCopies() {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let currentBundleIdentifier = Bundle.main.bundleIdentifier

        for app in NSWorkspace.shared.runningApplications where app.processIdentifier != currentPID {
            let sameBundle = currentBundleIdentifier != nil && app.bundleIdentifier == currentBundleIdentifier
            let sameProductName = app.localizedName == "Codex 用量" || app.localizedName == "Codex 额度"
            let sameExecutableName = app.executableURL?.lastPathComponent == "CodexQuotaApp"

            if sameBundle || sameProductName || sameExecutableName {
                if !app.terminate() {
                    app.forceTerminate()
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if !app.isTerminated {
                            app.forceTerminate()
                        }
                    }
                }
            }
        }
    }
}

final class MenuPanel: NSPanel {
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

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

let mainMenu = NSMenu()
let appMenuItem = NSMenuItem()
mainMenu.addItem(appMenuItem)
NSApp.mainMenu = mainMenu

let appMenu = NSMenu()
appMenu.addItem(withTitle: "设置", action: #selector(AppDelegate.openSettings), keyEquivalent: ",").target = delegate
appMenu.addItem(.separator())
appMenu.addItem(withTitle: "退出", action: #selector(AppDelegate.quit), keyEquivalent: "q").target = delegate
appMenuItem.submenu = appMenu

NSApplication.shared.run()
