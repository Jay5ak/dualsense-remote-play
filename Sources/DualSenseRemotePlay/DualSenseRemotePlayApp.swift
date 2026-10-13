import AppKit
import IOBluetooth
import SwiftUI

@main
struct DualSenseRemotePlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            Button(model.isPaused ? "Resume Link" : "Pause Link") {
                model.togglePause()
            }

            Divider()

            Button("Cerrar app") {
                NSApp.terminate(nil)
            }
        } label: {
            StatusIcon(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct StatusIcon: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Image(
            systemName: model.isConnected
                ? "gamecontroller.fill"
                : "gamecontroller"
        )
        .foregroundStyle(
            model.isPaused
                ? Color.red
                : (model.isConnected ? Color.white : Color.gray)
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DualSenseMonitor()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        AppModel.shared.onPauseChanged = { [weak self] isPaused in
            self?.monitor.setPaused(isPaused)
        }

        monitor.onStateChange = { state in
            DispatchQueue.main.async {
                switch state {
                case .searching:
                    AppModel.shared.isConnected = false
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
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var isConnected = false
    @Published var isPaused = false

    var onPauseChanged: ((Bool) -> Void)?

    func togglePause() {
        isPaused.toggle()
        onPauseChanged?(isPaused)
    }
}

enum MonitorState {
    case searching
    case connected
    case remotePlayMissing
}

final class DualSenseMonitor {
    var onStateChange: ((MonitorState) -> Void)?

    private var timer: Timer?
    private var wasConnected = false
    private var isPaused = false

    private let remotePlayIDs = [
        "com.playstation.RemotePlay",
        "com.sie.psremoteplay",
        "com.playstation.PSRemotePlay",
        "com.playstation.remoteplay"
    ]

    func start() {
        timer?.invalidate()
        checkConnection()

        timer = Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: true
        ) { [weak self] _ in
            self?.checkConnection()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused

        if !paused {
            wasConnected = false
            checkConnection()
        }
    }

    private func checkConnection() {
        let devices = IOBluetoothDevice.pairedDevices()
            as? [IOBluetoothDevice] ?? []

        let connected = devices.contains {
            $0.isConnected() &&
            ($0.name ?? "").localizedCaseInsensitiveContains(
                "DualSense Wireless Controller"
            )
        }

        if isPaused {
            wasConnected = connected
            onStateChange?(connected ? .connected : .searching)
            return
        }

        guard connected else {
            if wasConnected {
                wasConnected = false
                closeRemotePlay()
            }

            onStateChange?(.searching)
            return
        }

        if !wasConnected {
            wasConnected = true
            openRemotePlay()
        }
    }

    private func openRemotePlay() {
        let workspace = NSWorkspace.shared

        guard let url = remotePlayIDs.compactMap({
            workspace.urlForApplication(withBundleIdentifier: $0)
        }).first else {
            onStateChange?(.remotePlayMissing)
            return
        }

        workspace.openApplication(
            at: url,
            configuration: .init()
        ) { [weak self] _, error in
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
}
