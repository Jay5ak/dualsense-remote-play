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

// MARK: - Menu Bar Icon View

struct MenuBarIconView: View {
    @ObservedObject var model: ControllerModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: model.isConnected ? "gamecontroller.fill" : "gamecontroller")
                .foregroundColor(iconColor)
                .opacity(model.isCharging ? model.breathingOpacity : 1.0)
            
            if let battery = model.batteryPercentage {
                Text("\(battery)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
        }
    }

    private var iconColor: Color {
        if model.isPaused {
            return .red
        } else if model.isConnected {
            return .green
        } else {
            return .primary
        }
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
    @Published var batteryPercentage: Int? = nil
    @Published var isCharging: Bool = false
    @Published var breathingOpacity: Double = 1.0
    @Published var controllerName: String = ""
    @Published var isRemotePlayRunning: Bool = false

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
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Actions

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
            // When paused, do not supervise or open Remote Play
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
                // Controller was disconnected
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
        // Look through connected GCControllers for matching battery info
        let targetController = gcController ?? GCController.controllers().first(where: {
            isDualSenseName($0.vendorName ?? "")
        })

        if let battery = targetController?.battery {
            let level = battery.batteryLevel // Float: 0.0 ... 1.0 (or -1.0 if unknown)
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

        // Moderate non-blocking timer: updates every 0.1s to smoothly transition opacity between 0.4 and 1.0
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
            }
        }
    }

    private func stopBreathingEffect() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        breathingOpacity = 1.0
    }

    // MARK: - Low Battery Notification

    private func checkLowBatteryNotification(percent: Int) {
        if percent <= 20 {
            if !didNotifyLowBattery {
                sendLowBatteryNotification(percent: percent)
                didNotifyLowBattery = true
            }
        } else {
            // Battery climbed back above 20%, allow notifying again if it drops
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
            trigger: nil // deliver immediately
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

        // First check if an instance is already running
        for bundleID in remotePlayBundleIDs {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if !running.isEmpty {
                isRemotePlayRunning = true
                return
            }
        }

        // Find PS Remote Play URL on system
        var appURL: URL?
        for bundleID in remotePlayBundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                appURL = url
                break
            }
        }

        // If not found by bundle ID, search default Applications directory
        if appURL == nil {
            let candidatePaths = [
                "/Applications/PS Remote Play.app",
                "/Applications/Remote Play.app",
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
            // Not installed on system, keep app running safely
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

        // Also check by localized name if bundle ID match didn't catch a custom instance
        let allApps = NSWorkspace.shared.runningApplications
        for app in allApps {
            if let name = app.localizedName, (name == "PS Remote Play" || name == "RemotePlay") {
                app.terminate()
            }
        }

        isRemotePlayRunning = false
    }
}
