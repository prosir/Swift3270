import AppKit
import SwiftUI

struct Swift3270LaunchView: View {
    @StateObject private var updateChecker = UpdateChecker()
    @State private var progress = 0.0
    @State private var isReady = false
    @State private var didStart = false
    @State private var isInstalling = false

    var body: some View {
        ZStack {
            if isReady {
                ContentView()
                    .frame(minWidth: 1280, minHeight: 850)
                    .transition(.opacity)
            } else {
                launchScreen
                    .frame(width: 560, height: 360)
                    .transition(.opacity)
            }
        }
        .background(WindowSizeController(isReady: isReady))
        .background(LaunchColors.background)
        .task {
            await runStartupSequence()
        }
        .preferredColorScheme(.dark)
    }

    private var launchScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Swift3270")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(LaunchColors.primaryText)

                    Text("3270 terminal for macOS")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(LaunchColors.secondaryText)
                }
            }

            if let update = updateChecker.availableUpdate {
                updatePanel(update)
                    .padding(.top, 22)
            } else {
                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(progress < 0.25 ? "Checking for updates…" : (progress >= 1 ? "Ready" : "Starting…"))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .monospacedDigit()
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LaunchColors.secondaryText)

                    progressBar(progress)
                }
            }

            HStack {
                Text("Secure mainframe access")
                Spacer()
                Text("Version \(currentVersion)")
            }
            .font(.system(size: 10, weight: .regular))
            .foregroundStyle(LaunchColors.mutedText)
            .padding(.top, 18)
        }
        .padding(32)
        .background(LaunchColors.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(LaunchColors.accent)
                .frame(height: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Swift3270 wordt gestart")
        .accessibilityValue("\(Int(progress * 100)) procent")
    }

    private func updatePanel(_ update: AppUpdate) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update available · \(update.version)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LaunchColors.primaryText)
                    Text(update.title)
                        .font(.system(size: 11))
                        .foregroundStyle(LaunchColors.secondaryText)
                }
                Spacer()
            }

            ScrollView {
                Text(update.changelog.isEmpty ? "No release notes provided." : update.changelog)
                    .font(.system(size: 11))
                    .foregroundStyle(LaunchColors.secondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 76)

            if isInstalling {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(updateChecker.installStatus)
                        Spacer()
                        Text("\(Int(updateChecker.installProgress * 100))%")
                            .monospacedDigit()
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(LaunchColors.secondaryText)
                    progressBar(updateChecker.installProgress)
                }
            } else if let error = updateChecker.installError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(LaunchColors.errorText)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Button("Later") {
                    updateChecker.availableUpdate = nil
                    Task { await finishStartup() }
                }
                .disabled(isInstalling)

                Spacer()

                if update.canInstall {
                    Button("Install update") {
                        isInstalling = true
                        Task {
                            await updateChecker.install(update)
                            if updateChecker.installError != nil {
                                isInstalling = false
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LaunchColors.accent)
                    .disabled(isInstalling)
                } else {
                    Button("Open GitHub") {
                        NSWorkspace.shared.open(update.url)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(LaunchColors.accent)
                }
            }
            .controlSize(.small)
        }
    }

    private func progressBar(_ value: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LaunchColors.track)

                Rectangle()
                    .fill(LaunchColors.accent)
                    .frame(width: max(0, geometry.size.width * value))
            }
        }
        .frame(height: 3)
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
    }

    @MainActor
    private func runStartupSequence() async {
        guard !didStart else { return }
        didStart = true

        progress = 0.08
        await updateChecker.checkForUpdates()
        progress = 0.24
        if updateChecker.availableUpdate != nil {
            return
        }

        await finishStartup()
    }

    @MainActor
    private func finishStartup() async {
        while progress < 1 {
            try? await Task.sleep(for: .milliseconds(22))
            withAnimation(.linear(duration: 0.05)) {
                progress = min(1, progress + 0.02)
            }
        }

        try? await Task.sleep(for: .milliseconds(180))
        withAnimation(.easeInOut(duration: 0.18)) {
            isReady = true
        }
    }
}

private struct WindowSizeController: NSViewRepresentable {
    let isReady: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            resizeWindow(for: view, coordinator: context.coordinator, animated: false)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            resizeWindow(for: view, coordinator: context.coordinator, animated: isReady)
        }
    }

    private func resizeWindow(for view: NSView, coordinator: Coordinator, animated: Bool) {
        guard coordinator.lastReadyState != isReady, let window = view.window else { return }
        coordinator.lastReadyState = isReady

        let targetSize = isReady ? NSSize(width: 1280, height: 850) : NSSize(width: 560, height: 360)
        let currentFrame = window.frame
        let targetOrigin = NSPoint(
            x: currentFrame.midX - targetSize.width / 2,
            y: currentFrame.midY - targetSize.height / 2
        )
        window.setFrame(NSRect(origin: targetOrigin, size: targetSize), display: true, animate: animated)
        window.minSize = isReady ? targetSize : NSSize(width: 560, height: 360)
        window.center()
    }

    final class Coordinator {
        var lastReadyState: Bool?
    }
}

private enum LaunchColors {
    static let background = Color(red: 0.043, green: 0.051, blue: 0.068)
    static let track = Color.white.opacity(0.12)
    static var accent: Color { AppAccentTheme.currentAccent }
    static let primaryText = Color(red: 0.950, green: 0.965, blue: 0.990)
    static let secondaryText = Color(red: 0.690, green: 0.730, blue: 0.800)
    static let mutedText = Color(red: 0.470, green: 0.510, blue: 0.580)
    static let errorText = Color(red: 1.000, green: 0.430, blue: 0.430)
}
