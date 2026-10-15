import SwiftUI
import AppKit
import GameController
import IOBluetooth
import UserNotifications

// MARK: - App Entry Point

@main
struct DualSenseRemotePlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var controllerModel = ControllerModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: controllerModel)
        } label: {
            MenuBarIconView(model: controllerModel)
        }
        .menuBarExtraStyle(.menu)
    }
}

// MARK: - Application Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure menu bar utility doesn't show in the Dock or window cycle
        NSApp.setActivationPolicy(.accessory)
        
        // Request notification authorization on launch for low battery alerts
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("[DualSenseRemotePlay] Notification auth error: %@", error.localizedDescription)
            }
        }
        
        // Start controller monitoring
        ControllerModel.shared.startMonitoring()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        ControllerModel.shared.stopMonitoring()
    }
}

// MARK: - Subtle Notch Border Overlay Manager

@MainActor
final class SubtleNotchOverlayManager {
    static let shared = SubtleNotchOverlayManager()

    private var overlayPanels: [NSPanel] = []
    private var borderViews: [SubtleNotchView] = []
    private var animationTimer: Timer?
    private var animationProgress: CGFloat = 1.0 // 0.0 -> 1.0
    private var currentActiveColor: NSColor? = nil
    private var isAnimating = false
    private var isDisappearing = false

    private init() {}

    func transition(to color: NSColor?) {
        guard let targetColor = color else {
            // Turning off: animate light beams retracting/vanishing
            if currentActiveColor != nil {
                startAnimation(to: currentActiveColor ?? .white, isHiding: true)
            } else {
                hide()
            }
            return
        }

        // Turning on or changing color
        let colorChanged = (currentActiveColor?.cgColor != targetColor.cgColor)
        if overlayPanels.isEmpty || colorChanged {
            startAnimation(to: targetColor, isHiding: false)
        } else {
            // Steady state update (e.g. breathing opacity update)
            currentActiveColor = targetColor
            for view in borderViews {
                view.strokeColor = targetColor
                view.needsDisplay = true
            }
        }
    }

    private func startAnimation(to color: NSColor, isHiding: Bool) {
        currentActiveColor = color
        isDisappearing = isHiding
        setupPanelsIfNeeded()

        animationTimer?.invalidate()
        animationProgress = isHiding ? 1.0 : 0.0
        isAnimating = true

        let stepDuration = 0.016 // ~60fps
        let totalSteps: CGFloat = 28.0 // ~0.45s animation duration
        let delta = 1.0 / totalSteps

        animationTimer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isDisappearing {
                    self.animationProgress -= delta
                    if self.animationProgress <= 0.0 {
                        self.animationProgress = 0.0
                        self.animationTimer?.invalidate()
                        self.animationTimer = nil
                        self.isAnimating = false
                        self.currentActiveColor = nil
                        self.hide()
                        return
                    }
                } else {
                    self.animationProgress += delta
                    if self.animationProgress >= 1.0 {
                        self.animationProgress = 1.0
                        self.animationTimer?.invalidate()
                        self.animationTimer = nil
                        self.isAnimating = false
                    }
                }

                for view in self.borderViews {
                    view.strokeColor = self.currentActiveColor ?? color
                    view.progress = self.animationProgress
                    view.isMeeting = (self.animationProgress >= 0.88 && !self.isDisappearing)
                    view.needsDisplay = true
                }
            }
        }
    }

    private func setupPanelsIfNeeded() {
        let screens = NSScreen.screens
        var notchTargets: [(NSScreen, NSRect)] = []

        for screen in screens {
            if screen.safeAreaInsets.top > 0,
               let leftArea = screen.auxiliaryTopLeftArea,
               let rightArea = screen.auxiliaryTopRightArea {
                let notchWidth = screen.frame.width - leftArea.width - rightArea.width
                let notchHeight = screen.safeAreaInsets.top
                let originX = screen.frame.origin.x + leftArea.width
                let originY = screen.frame.origin.y + screen.frame.height - notchHeight
                if notchWidth > 0 && notchHeight > 0 {
                    notchTargets.append((screen, NSRect(x: originX, y: originY, width: notchWidth, height: notchHeight)))
                }
            }
        }

        guard !notchTargets.isEmpty else { return }

        if overlayPanels.count != notchTargets.count {
            hide()
            for _ in notchTargets {
                let panel = NSPanel(
                    contentRect: .zero,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.level = .popUpMenu
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = false
                panel.ignoresMouseEvents = true
                panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
                overlayPanels.append(panel)
            }
        }

        borderViews.removeAll()
        for (index, item) in notchTargets.enumerated() {
            let (_, notchRect) = item
            let panel = overlayPanels[index]
            let padding: CGFloat = 6.0
            let windowRect = NSRect(
                x: notchRect.minX - padding,
                y: notchRect.minY - padding,
                width: notchRect.width + (padding * 2),
                height: notchRect.height + padding
            )
            panel.setFrame(windowRect, display: true)

            let borderView = SubtleNotchView(
                notchWidth: notchRect.width,
                notchHeight: notchRect.height,
                padding: padding,
                strokeColor: currentActiveColor ?? .white
            )
            borderView.progress = animationProgress
            borderViews.append(borderView)
            panel.contentView = borderView

            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        }
    }

    func hide() {
        animationTimer?.invalidate()
        animationTimer = nil
        for panel in overlayPanels {
            panel.orderOut(nil)
        }
        overlayPanels.removeAll()
        borderViews.removeAll()
        currentActiveColor = nil
    }
}

private final class SubtleNotchView: NSView {
    var notchWidth: CGFloat
    var notchHeight: CGFloat
    var padding: CGFloat
    var strokeColor: NSColor
    var progress: CGFloat = 1.0
    var isMeeting: Bool = false

    override var isFlipped: Bool { true }

    init(notchWidth: CGFloat, notchHeight: CGFloat, padding: CGFloat, strokeColor: NSColor) {
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.padding = padding
        self.strokeColor = strokeColor
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext, progress > 0.01 else { return }

        let leftX = padding
        let rightX = padding + notchWidth
        let bottomY = notchHeight
        let cornerRadius: CGFloat = 10.0
        let earRadius: CGFloat = 6.0
        let centerX = padding + (notchWidth / 2.0)

        // Symmetrical paths: Left side travels from top-left to bottom-center
        // Right side travels from top-right to bottom-center
        let leftPath = CGMutablePath()
        leftPath.move(to: CGPoint(x: leftX - earRadius, y: 0))
        leftPath.addQuadCurve(to: CGPoint(x: leftX, y: earRadius), control: CGPoint(x: leftX, y: 0))
        leftPath.addLine(to: CGPoint(x: leftX, y: bottomY - cornerRadius))
        leftPath.addQuadCurve(to: CGPoint(x: leftX + cornerRadius, y: bottomY), control: CGPoint(x: leftX, y: bottomY))
        leftPath.addLine(to: CGPoint(x: centerX, y: bottomY))

        let rightPath = CGMutablePath()
        rightPath.move(to: CGPoint(x: rightX + earRadius, y: 0))
        rightPath.addQuadCurve(to: CGPoint(x: rightX, y: earRadius), control: CGPoint(x: rightX, y: 0))
        rightPath.addLine(to: CGPoint(x: rightX, y: bottomY - cornerRadius))
        rightPath.addQuadCurve(to: CGPoint(x: rightX - cornerRadius, y: bottomY), control: CGPoint(x: rightX, y: bottomY))
        rightPath.addLine(to: CGPoint(x: centerX, y: bottomY))

        // Total approximate length of one half perimeter:
        // ear (~10) + vertical side (~28) + corner (~15) + bottom half (~90) = ~145
        let halfLength: CGFloat = 145.0
        let currentDrawnLength = halfLength * min(1.0, max(0.0, progress))
        let remainingLength = max(0.0, halfLength - currentDrawnLength)

        // Use dash phase so the line grows smoothly from the top downwards
        let dashes: [CGFloat] = [currentDrawnLength, remainingLength + 50.0]

        let lineWidth: CGFloat = isMeeting ? 2.2 : 1.5
        let glowBlur: CGFloat = isMeeting ? 7.0 : 4.0

        for path in [leftPath, rightPath] {
            // 1. Soft glowing outer light beam
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: glowBlur, color: strokeColor.withAlphaComponent(isMeeting ? 0.90 : 0.45).cgColor)
            ctx.addPath(path)
            ctx.setLineDash(phase: 0.0, lengths: dashes)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(strokeColor.withAlphaComponent(0.65).cgColor)
            ctx.strokePath()
            ctx.restoreGState()

            // 2. Crisp core hairline
            ctx.saveGState()
            ctx.addPath(path)
            ctx.setLineDash(phase: 0.0, lengths: dashes)
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(strokeColor.withAlphaComponent(0.95).cgColor)
            ctx.strokePath()
            ctx.restoreGState()
        }

        // 3. Convergence spark/burst effect at the bottom center when the two light beams meet
        if isMeeting {
            let sparkRadius: CGFloat = 3.5
            let sparkCenter = CGPoint(x: centerX, y: bottomY)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 8.0, color: strokeColor.cgColor)
            ctx.setFillColor(strokeColor.withAlphaComponent(0.95).cgColor)
            ctx.fillEllipse(in: CGRect(x: sparkCenter.x - sparkRadius,
                                       y: sparkCenter.y - sparkRadius,
                                       width: sparkRadius * 2,
                                       height: sparkRadius * 2))
            ctx.restoreGState()
        }
    }
}

// MARK: - Menu Bar Icon Non-Template Renderer & View

enum MenuBarIconRenderer {
    static func renderImage(connected: Bool, isPaused: Bool, percent: Int?, color: NSColor) -> NSImage {
        let symbolName = connected ? "gamecontroller.fill" : "gamecontroller"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        let symSize = symbol?.size ?? NSSize(width: 18, height: 13)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color
        ]
        let text = percent.map { "\($0)%" }
        let textSize = text.map { ($0 as NSString).size(withAttributes: attrs) } ?? .zero
        let gap: CGFloat = text == nil ? 0 : 4
        let height: CGFloat = 18
        let totalWidth = ceil(symSize.width + gap + textSize.width)

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { _ in
            if let symbol {
                let tinted = NSImage(size: symSize, flipped: false) { r in
                    symbol.draw(in: r)
                    color.set()
                    r.fill(using: .sourceIn)
                    return true
                }
                tinted.draw(in: NSRect(x: 0, y: (height - symSize.height) / 2,
                                       width: symSize.width, height: symSize.height))
            }
            if let text {
                let y = (height - textSize.height) / 2
                (text as NSString).draw(at: NSPoint(x: symSize.width + gap, y: y), withAttributes: attrs)
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}

struct MenuBarIconView: View {
    @ObservedObject var model: ControllerModel

    var body: some View {
        let color = model.currentColor
        Image(nsImage: MenuBarIconRenderer.renderImage(
            connected: model.isConnected,
            isPaused: model.isPaused,
            percent: model.isConnected ? model.batteryPercentage : nil,
            color: color
        ))
    }
}

// MARK: - Menu Content View

struct MenuView: View {
    @ObservedObject var model: ControllerModel

    var body: some View {
        VStack {
            // Pause / Resume toggle button
            Button {
                model.togglePause()
            } label: {
                if model.isPaused {
                    Text("Link: Paused — Resume link")
                } else {
                    Text("Link: Active — Pause link")
                }
            }

            // Notch Light on/off toggle button
            Button {
                model.toggleNotchLight()
            } label: {
                if model.isNotchLightEnabled {
                    Text("Luz del Notch: Encendida (Apagar)")
                } else {
                    Text("Luz del Notch: Apagada (Encender)")
                }
            }

            Divider()

            // Status display
            if model.isPaused {
                Text("Status: Paused")
            } else if model.isConnected {
                let name = model.controllerName.isEmpty ? "DualSense" : model.controllerName
                if let battery = model.batteryPercentage {
                    Text("\(name) Connected (\(battery)%\(model.isCharging ? " - Charging" : ""))")
                } else {
                    Text("\(name) Connected")
                }
            } else {
                Text("DualSense Disconnected")
            }

            if model.isRemotePlayRunning {
                Text("PS Remote Play: Running")
            }

            Divider()

            // Quit button
            Button("Cerrar app") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// MARK: - Controller & Remote Play Observable Model

@MainActor
final class ControllerModel: ObservableObject {
    static let shared = ControllerModel()

    // Published UI properties
    @Published var isConnected: Bool = false
    @Published var isPaused: Bool = false
    @Published var isNotchLightEnabled: Bool = true
    @Published var batteryPercentage: Int? = nil
    @Published var isCharging: Bool = false
    @Published var breathingOpacity: Double = 1.0
    @Published var controllerName: String = ""
    @Published var isRemotePlayRunning: Bool = false

    var currentColor: NSColor {
        if isPaused {
            return .systemRed
        } else if isConnected {
            let alpha = (isCharging && !isPaused) ? breathingOpacity : 1.0
            return NSColor.systemGreen.withAlphaComponent(alpha)
        } else {
            return .white
        }
    }

    // Known Remote Play bundle IDs
    private let remotePlayBundleIDs = [
        "com.playstation.RemotePlay",
        "com.sie.psremoteplay",
        "com.playstation.PSRemotePlay",
        "com.playstation.remoteplay"
    ]

    // Internal state tracking
    private var monitorTimer: Timer?
    private var breathingTimer: Timer?
    private var breathingGoingDown = true
    private var didNotifyLowBattery = false
    private var isLaunchingRemotePlay = false

    private init() {}

    // MARK: - Public Lifecycle

    func startMonitoring() {
        // Monitor GameController notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGCControllerDidConnect),
            name: .GCControllerDidConnect,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGCControllerDidDisconnect),
            name: .GCControllerDidDisconnect,
            object: nil
        )

        // Periodic poll every 2 seconds for Bluetooth/USB controller status and Remote Play state
        monitorTimer?.invalidate()
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkControllerState()
            }
        }

        // Run an immediate check
        checkControllerState()
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        stopBreathingEffect()
        SubtleNotchOverlayManager.shared.hide()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

    func toggleNotchLight() {
        isNotchLightEnabled.toggle()
        updateNotchOverlay()
    }

    func togglePause() {
        if isPaused {
            // Resume link
            isPaused = false
            checkControllerState()
        } else {
            // Pause link
            isPaused = true
            stopBreathingEffect()
            // Close PS Remote Play when link is paused to release controller for Steam/native games
            closePSRemotePlay()
            isRemotePlayRunning = false
            updateNotchOverlay()
        }
    }

    // MARK: - Notification Handlers

    @objc private func handleGCControllerDidConnect(_ notification: Notification) {
        Task { @MainActor in
            self.checkControllerState()
        }
    }

    @objc private func handleGCControllerDidDisconnect(_ notification: Notification) {
        Task { @MainActor in
            self.checkControllerState()
        }
    }

    // MARK: - Controller Detection & State Update

    func checkControllerState() {
        updateRemotePlayRunningStatus()

        guard !isPaused else {
            updateNotchOverlay()
            return
        }

        let detected = detectDualSense()
        let previouslyConnected = isConnected

        if detected.isConnected {
            isConnected = true
            controllerName = detected.name
            updateBattery(from: detected.gcController)

            // Auto-launch PS Remote Play if not already open
            if !previouslyConnected || !isRemotePlayRunning {
                openPSRemotePlayIfNeeded()
            }
        } else {
            // Disconnected
            if previouslyConnected {
                isConnected = false
                batteryPercentage = nil
                isCharging = false
                controllerName = ""
                didNotifyLowBattery = false
                stopBreathingEffect()
                closePSRemotePlay()
            } else {
                isConnected = false
                batteryPercentage = nil
                isCharging = false
                controllerName = ""
                stopBreathingEffect()
            }
        }

        updateNotchOverlay()
    }

    private func updateNotchOverlay() {
        if isNotchLightEnabled && (isConnected || isPaused) {
            SubtleNotchOverlayManager.shared.transition(to: currentColor)
        } else {
            SubtleNotchOverlayManager.shared.transition(to: nil)
        }
    }

    private struct DetectionResult {
        let isConnected: Bool
        let name: String
        let gcController: GCController?
    }

    private func detectDualSense() -> DetectionResult {
        // 1. Check GCController (both USB and Bluetooth supported by Apple GameController framework)
        let controllers = GCController.controllers()
        for controller in controllers {
            let name = controller.vendorName ?? ""
            if isDualSenseName(name) {
                return DetectionResult(isConnected: true, name: name, gcController: controller)
            }
        }

        // 2. Check paired and connected Bluetooth devices via IOBluetooth
        if let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for device in pairedDevices {
                if device.isConnected() {
                    let name = device.nameOrAddress ?? ""
                    if isDualSenseName(name) {
                        return DetectionResult(isConnected: true, name: name, gcController: nil)
                    }
                }
            }
        }

        return DetectionResult(isConnected: false, name: "", gcController: nil)
    }

    private func isDualSenseName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("dualsense") ||
               (lower.contains("wireless controller") && (lower.contains("sony") || lower.contains("playstation") || !lower.contains("xbox")))
    }

    // MARK: - Battery & Charging Logic

    private func updateBattery(from gcController: GCController?) {
        let targetController = gcController ?? GCController.controllers().first(where: {
            isDualSenseName($0.vendorName ?? "")
        })

        if let battery = targetController?.battery {
            let level = battery.batteryLevel
            if level >= 0.0 {
                let percent = Int((level * 100.0).rounded())
                self.batteryPercentage = max(0, min(100, percent))
                checkLowBatteryNotification(percent: self.batteryPercentage!)
            } else {
                self.batteryPercentage = nil
            }

            let charging = (battery.batteryState == .charging)
            if charging != self.isCharging {
                self.isCharging = charging
                if charging {
                    startBreathingEffect()
                } else {
                    stopBreathingEffect()
                }
            }
        } else {
            self.batteryPercentage = nil
            if self.isCharging {
                self.isCharging = false
                stopBreathingEffect()
            }
        }
    }

    // MARK: - Breathing Effect for Charging

    private func startBreathingEffect() {
        guard breathingTimer == nil else { return }
        breathingOpacity = 1.0
        breathingGoingDown = true

        breathingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.isCharging else { return }
                let step: Double = 0.06
                if self.breathingGoingDown {
                    self.breathingOpacity -= step
                    if self.breathingOpacity <= 0.4 {
                        self.breathingOpacity = 0.4
                        self.breathingGoingDown = false
                    }
                } else {
                    self.breathingOpacity += step
                    if self.breathingOpacity >= 1.0 {
                        self.breathingOpacity = 1.0
                        self.breathingGoingDown = true
                    }
                }
                self.updateNotchOverlay()
            }
        }
    }

    private func stopBreathingEffect() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        breathingOpacity = 1.0
        updateNotchOverlay()
    }

    // MARK: - Low Battery Notification

    private func checkLowBatteryNotification(percent: Int) {
        if percent <= 20 {
            if !didNotifyLowBattery {
                sendLowBatteryNotification(percent: percent)
                didNotifyLowBattery = true
            }
        } else {
            didNotifyLowBattery = false
        }
    }

    private func sendLowBatteryNotification(percent: Int) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Batería baja"
        content.body = "El control DualSense tiene \(percent)% de batería."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "com.dualsense.remoteplay.lowbattery",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                NSLog("[DualSenseRemotePlay] Failed to deliver notification: %@", error.localizedDescription)
            }
        }
    }

    // MARK: - PS Remote Play Lifecycle Management

    private func updateRemotePlayRunningStatus() {
        for bundleID in remotePlayBundleIDs {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if !running.isEmpty {
                isRemotePlayRunning = true
                return
            }
        }
        isRemotePlayRunning = false
    }

    private func openPSRemotePlayIfNeeded() {
        guard !isLaunchingRemotePlay else { return }

        for bundleID in remotePlayBundleIDs {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if !running.isEmpty {
                isRemotePlayRunning = true
                return
            }
        }

        var appURL: URL?
        for bundleID in remotePlayBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                appURL = url
                break
            }
        }

        if appURL == nil {
            let candidatePaths = [
                "/Applications/PS Remote Play.app",
                "/Applications/Remote Play.app",
                "/Applications/RemotePlay.app",
                NSHomeDirectory() + "/Applications/PS Remote Play.app"
            ]
            for path in candidatePaths {
                if FileManager.default.fileExists(atPath: path) {
                    appURL = URL(fileURLWithPath: path)
                    break
                }
            }
        }

        guard let targetURL = appURL else {
            NSLog("[DualSenseRemotePlay] PS Remote Play is not installed or could not be found.")
            return
        }

        isLaunchingRemotePlay = true
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: targetURL, configuration: configuration) { [weak self] runningApp, error in
            Task { @MainActor [weak self] in
                self?.isLaunchingRemotePlay = false
                if let error = error {
                    NSLog("[DualSenseRemotePlay] Error opening PS Remote Play: %@", error.localizedDescription)
                } else if runningApp != nil {
                    self?.isRemotePlayRunning = true
                }
            }
        }
    }

    private func closePSRemotePlay() {
        for bundleID in remotePlayBundleIDs {
            let instances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            for app in instances {
                app.terminate()
            }
        }

        let allApps = NSWorkspace.shared.runningApplications
        for app in allApps {
            if let name = app.localizedName, (name == "PS Remote Play" || name == "RemotePlay") {
                app.terminate()
            }
        }

        isRemotePlayRunning = false
    }
}
