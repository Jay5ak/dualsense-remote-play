import AppKit
import GameController
import IOBluetooth
import IOKit
import SwiftUI
import UserNotifications

@main
struct DualSenseRemotePlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            StatusIcon()
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuContent: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        Button(model.isPaused ? "Link: Paused — Resume link" : "Link: Active — Pause link") {
            AppDelegate.shared?.togglePause()
        }
        Button("Cerrar app") {
            NSApp.terminate(nil)
        }
    }
}

private struct StatusIcon: View {
    @ObservedObject private var model = AppModel.shared

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Image(systemName: model.isConnected ? "gamecontroller.fill" : "gamecontroller")
                    .symbolRenderingMode(.palette)
            }
            if let batteryLevel = model.batteryLevel {
                Text("\(batteryLevel)%")
                    .monospacedDigit()
            }
        }
        .foregroundStyle(
            model.isPaused
                ? Color.red
                : (model.isConnected ? Color.green.opacity(model.isCharging ? model.chargingOpacity : 1) : Color.white)
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?
    private let monitor = DualSenseMonitor()

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        monitor.onStateChange = { state in
            DispatchQueue.main.async {
                switch state {
                case .searching:
                    AppModel.shared.isConnected = false
                    AppModel.shared.batteryLevel = nil
                    AppModel.shared.isCharging = false
                    AppModel.shared.chargingOpacity = 1
                case .connected, .remotePlayMissing:
                    AppModel.shared.isConnected = true
                }
            }
        }

        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    @MainActor
    func togglePause() {
        monitor.setPaused(!AppModel.shared.isPaused)
        AppModel.shared.isPaused.toggle()
        if AppModel.shared.isPaused {
            AppModel.shared.isConnected = false
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var isConnected = false
    @Published var batteryLevel: Int?
    @Published var isCharging = false
    @Published var chargingOpacity = 1.0
    @Published var isPaused = false
}

enum MonitorState {
    case searching
    case connected
    case remotePlayMissing
}

final class DualSenseMonitor {
    var onStateChange: ((MonitorState) -> Void)?

    private var timer: Timer?
    private var chargingPulseTimer: Timer?
    private var chargingPulsePhase = 0.0
    private var isPaused = false
    private var wasConnected = false
    private var lowBatteryNotificationSent = false

    private let remotePlayIDs = [
        "com.playstation.RemotePlay",
        "com.sie.psremoteplay",
        "com.playstation.PSRemotePlay",
        "com.playstation.remoteplay"
    ]

    func start() {
        timer?.invalidate()
        checkConnection()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) {
            [weak self] _ in
            self?.checkConnection()
        }
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            wasConnected = false
            closeRemotePlay()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        chargingPulseTimer?.invalidate()
        chargingPulseTimer = nil
    }

    private func checkConnection() {
        guard !isPaused else { return }
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []

        let connected = devices.contains {
            $0.isConnected() && isSupportedController($0)
        }

        guard connected else {
            if wasConnected {
                wasConnected = false
                lowBatteryNotificationSent = false
                closeRemotePlay()
            }
            onStateChange?(.searching)
            return
        }

        if !wasConnected {
            wasConnected = true
            openRemotePlay()
        }

        updateBatteryLevelFromGameController()
    }

    private func isSupportedController(_ device: IOBluetoothDevice) -> Bool {
        let name = device.name ?? ""
        return name.localizedCaseInsensitiveContains("DualSense") &&
            name.localizedCaseInsensitiveContains("Wireless Controller")
    }

    private func openRemotePlay() {
        let workspace = NSWorkspace.shared

        guard let url = remotePlayIDs.compactMap({
            workspace.urlForApplication(withBundleIdentifier: $0)
        }).first else {
            onStateChange?(.remotePlayMissing)
            return
        }

        let bundleID = Bundle(url: url)?.bundleIdentifier
        if let bundleID,
           !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
            onStateChange?(.connected)
            return
        }

        workspace.openApplication(at: url, configuration: .init()) {
            [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    print("No se pudo abrir PS Remote Play: \(error)")
                    self.onStateChange?(.remotePlayMissing)
                } else {
                    self.onStateChange?(.connected)
                }
            }
        }
    }

    private func closeRemotePlay() {
        for bundleID in remotePlayIDs {
            NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .forEach { $0.terminate() }
        }
    }

    private func updateBatteryLevelFromGameController() {
        guard let controller = GCController.controllers().first(where: {
            ($0.vendorName ?? "").localizedCaseInsensitiveContains("DualSense") ||
            $0.productCategory.localizedCaseInsensitiveContains("ps5")
        }), let battery = controller.battery else { return }

        let level = Int((battery.batteryLevel * 100).rounded())
        DispatchQueue.main.async {
            AppModel.shared.batteryLevel = min(max(level, 0), 100)
            let isCharging = battery.batteryState == .charging
            AppModel.shared.isCharging = isCharging
            self.updateChargingPulse(isCharging: isCharging)
        }
    }

    @MainActor
    private func updateChargingPulse(isCharging: Bool) {
        if isCharging && chargingPulseTimer != nil {
            return
        }

        chargingPulseTimer?.invalidate()
        chargingPulseTimer = nil
        AppModel.shared.chargingOpacity = 1
        chargingPulsePhase = 0
        guard isCharging else { return }
        chargingPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            Task { @MainActor in
                self.chargingPulsePhase += 0.08 / 2.4 * 2 * .pi
                AppModel.shared.chargingOpacity = 0.35 + 0.65 * ((sin(self.chargingPulsePhase) + 1) / 2)
            }
        }
    }

    private func updateBatteryLevelFromRegistry() {
        var iterator = io_iterator_t()
        let matching = IOServiceMatching("IOHIDEventService")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }

        var level: Int?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let value = IORegistryEntryCreateCFProperty(service, "BatteryPercent" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                level = value
                IOObjectRelease(service)
                break
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)

        guard let level else { return }
        DispatchQueue.main.async {
            AppModel.shared.batteryLevel = level
        }

        if level <= 20 && !lowBatteryNotificationSent {
            lowBatteryNotificationSent = true
            let content = UNMutableNotificationContent()
            content.title = "Batería baja"
            content.body = "El control DualSense tiene \(level)% de batería."
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "dualsense-low-battery", content: content, trigger: nil)
            )
        } else if level > 20 {
            lowBatteryNotificationSent = false
        }
    }
}
