// --- MacSnow 1.1, Nov-2-2026 ---
// --- Began as functional Gemini slop (in the Brave browser lol) ---
// --- 1.0 was released on Oct 31, 1.1 includes a better GUI, MacOS 14+ support, snow refinements ---

import SwiftUI
import AppKit
import Combine
import CoreGraphics

// --- 1. SNOWFLAKE DATA MODEL ---

struct Snowflake: Identifiable {
    let id = UUID()
    var initialX: CGFloat
    var speedMultiplier: CGFloat
    var size: CGFloat
    var opacity: Double
    var swingWidth: CGFloat
    var swingSpeed: Double
    var type: Int
}

// --- 2. GLOBAL CONTROLLER STATE ---

class SnowSettings: ObservableObject {
    @Published var speedMultiplier: Double = 1.5
    @Published var sizeMultiplier: Double = 1.0
    @Published var isSnowing: Bool = true
    @Published var behindWindows: Bool = false
}

// --- 3. MAIN APPLICATION LIFECYCLE ---

@main
struct MacSnowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// --- 4. APP DELEGATE AND WINDOW MANAGEMENT ---

class AppDelegate: NSObject, NSApplicationDelegate {

    var snowWindows: [NSWindow] = []
    var controlWindow: NSWindow?

    var settingsObserver: AnyCancellable?
    var workspaceObserver: NSObjectProtocol?

    let settings = SnowSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Create transparent snow overlay for each monitor

        for screen in NSScreen.screens {

            let frame = screen.frame

            let snowWindow = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            snowWindow.isOpaque = false
            snowWindow.backgroundColor = .clear
            snowWindow.hasShadow = false

            snowWindow.level = .mainMenu + 1
            snowWindow.ignoresMouseEvents = true

            snowWindow.collectionBehavior = [
                .canJoinAllSpaces,
                .stationary,
                .ignoresCycle
            ]

            let contentView = NSHostingView(
                rootView: SnowCanvasView(
                    screenSize: frame.size,
                    settings: settings
                )
            )

            snowWindow.contentView = contentView
            snowWindow.makeKeyAndOrderFront(nil)

            snowWindows.append(snowWindow)
        }

        // Create control panel

        let controlBox = NSWindow(
            contentRect: NSRect(
                x: 150,
                y: 150,
                width: 320,
                height: 310
            ),
            styleMask: [
                .titled,
                .closable,
                .miniaturizable
            ],
            backing: .buffered,
            defer: false
        )

        controlBox.title = "MacSnow"
        controlBox.level = .floating
        controlBox.isReleasedWhenClosed = false

        let controlView = NSHostingView(
            rootView: ControlPanelView(settings: settings)
        )

        controlBox.contentView = controlView
        controlBox.center()
        controlBox.makeKeyAndOrderFront(nil)

        controlWindow = controlBox

        // Observe Behind App Windows setting

        settingsObserver = settings.$behindWindows.sink { [weak self] behind in

            DispatchQueue.main.async {
                self?.updateSnowWindowLevels(behind: behind)
            }
        }

        // Update snow layering when switching applications

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in

            guard let self = self else { return }

            self.updateSnowWindowLevels(
                behind: self.settings.behindWindows
            )
        }

        updateSnowWindowLevels(behind: settings.behindWindows)
    }

    // Position snow relative to the foreground application window

    func updateSnowWindowLevels(behind: Bool) {

        guard behind else {

            for window in snowWindows {
                window.level = .mainMenu + 1
                window.orderFront(nil)
            }

            return
        }

        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)

        let frontmostPID = NSWorkspace.shared.frontmostApplication?
            .processIdentifier

        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly],
            kCGNullWindowID
        ) as? [[String: Any]] ?? []

        // Find the frontmost ordinary application window.
        // Exclude MacSnow's own windows.

        let foregroundWindow = windowList.first { info in

            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? Int,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,
                ownerPID != ownPID
            else {
                return false
            }

            // Prefer the active application when it is not MacSnow.
            if let frontmostPID = frontmostPID,
               Int(frontmostPID) != ownPID {
                return ownerPID == Int(frontmostPID)
            }

            // When MacSnow is active, use the previous
            // frontmost external application window.

            return true
        }

        guard let windowNumber = foregroundWindow?[
            kCGWindowNumber as String
        ] as? Int else {
            return
        }

        // Place snow immediately below the foreground window

        for window in snowWindows {

            window.level = .normal

            window.order(
                .below,
                relativeTo: windowNumber
            )
        }
    }

    // Reopen control panel when Dock icon is clicked

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {

        controlWindow?.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        return true
    }

    deinit {
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

// --- 5. NATIVE MACOS CONTROL PANEL ---

struct ControlPanelView: View {

    @ObservedObject var settings: SnowSettings

    var body: some View {

        VStack(spacing: 15) {

            // Header

            HStack {

                Image(systemName: "snowflake")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {

                    Text("MacSnow")
                        .font(.title3.weight(.semibold))

                    Text("Customize your snowfall")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 5) {

                    Circle()
                        .fill(settings.isSnowing ? .green : .secondary)
                        .frame(width: 7, height: 7)

                    Text(settings.isSnowing ? "Active" : "Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Start / Pause Snowfall

            Button {
                settings.isSnowing.toggle()
            } label: {

                Label(
                    settings.isSnowing ? "Pause Snowfall" : "Resume Snowfall",
                    systemImage: settings.isSnowing ? "pause.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            // Behind App Windows

            Toggle(
                "Behind App Windows",
                isOn: $settings.behindWindows
            )
            .toggleStyle(.switch)

            // Snow Velocity

            VStack(alignment: .leading, spacing: 8) {

                HStack {

                    Label("Snow Velocity", systemImage: "wind")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text(
                        settings.speedMultiplier < 1.5 ? "Heavy" :
                        settings.speedMultiplier > 2.5 ? "Blizzard" : "Gentle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Slider(
                    value: $settings.speedMultiplier,
                    in: 2.0...15.0
                )
                .disabled(!settings.isSnowing)
            }

            // Snowflake Size

            VStack(alignment: .leading, spacing: 8) {

                HStack {

                    Label("Flake Size", systemImage: "snowflake")
                        .font(.subheadline.weight(.medium))

                    Spacer()

                    Text(
                        String(format: "%.1fx", settings.sizeMultiplier)
                    )
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                Slider(
                    value: $settings.sizeMultiplier,
                    in: 0.25...4.0
                )
                .disabled(!settings.isSnowing)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 320, height: 310)
    }
}

// --- 6. SNOWFALL ANIMATION AND RENDERING ---

struct SnowCanvasView: View {

    let screenSize: CGSize

    @ObservedObject var settings: SnowSettings

    @State private var flakes: [Snowflake] = []

    init(screenSize: CGSize, settings: SnowSettings) {

        self.screenSize = screenSize
        self.settings = settings

        let flakeCount = Int(screenSize.width / 18)

        var temporaryFlakes: [Snowflake] = []

        for _ in 0..<flakeCount {

            temporaryFlakes.append(
                Snowflake(
                    initialX: CGFloat.random(
                        in: -50...screenSize.width + 50
                    ),
                    speedMultiplier: CGFloat.random(in: 30...90),
                    size: CGFloat.random(in: 5...10),
                    opacity: Double.random(in: 0.65...0.95),
                    swingWidth: CGFloat.random(in: 6...18),
                    swingSpeed: Double.random(in: 0.4...1.2),
                    type: Int.random(in: 0...2)
                )
            )
        }

        _flakes = State(initialValue: temporaryFlakes)
    }

    var body: some View {

        Group {

            if settings.isSnowing {

                TimelineView(.animation) { timeline in

                    Canvas { context, size in

                        let timeSeconds = timeline.date.timeIntervalSince1970

                        for flake in flakes {

                            guard let resolvedFlake = context.resolveSymbol(
                                id: flake.type
                            ) else {
                                continue
                            }

                            let currentGlobalSpeed =
                                CGFloat(settings.speedMultiplier)

                            let currentGlobalSize =
                                CGFloat(settings.sizeMultiplier)

                            // Calculate falling position

                            let calculatedFall =
                                flake.speedMultiplier *
                                currentGlobalSpeed *
                                CGFloat(timeSeconds * 0.5)

                            let currentY =
                                calculatedFall.truncatingRemainder(
                                    dividingBy: screenSize.height + 60
                                ) - 30

                            // Calculate horizontal movement

                            let currentSway =
                                sin(timeSeconds * flake.swingSpeed) *
                                Double(flake.swingWidth)

                            let currentX =
                                flake.initialX + CGFloat(currentSway)

                            var innerContext = context

                            innerContext.opacity = flake.opacity

                            innerContext.translateBy(
                                x: currentX,
                                y: currentY
                            )

                            // Calculate rotation

                            let calculatedRotation =
                                timeSeconds *
                                Double(flake.speedMultiplier * 0.2)

                            innerContext.rotate(
                                by: Angle(degrees: calculatedRotation)
                            )

                            // Calculate flake size

                            let dynamicSize =
                                flake.size * currentGlobalSize

                            let scale = dynamicSize / 30.0

                            innerContext.scaleBy(
                                x: scale,
                                y: scale
                            )

                            innerContext.draw(
                                resolvedFlake,
                                at: .zero
                            )
                        }

                    } symbols: {

                        CrystalTemplateView(type: 0).tag(0)
                        CrystalTemplateView(type: 1).tag(1)
                        CrystalTemplateView(type: 2).tag(2)

                    }
                }

            } else {

                Color.clear

            }
        }
        .background(Color.clear)
    }
}

// --- 7. SNOWFLAKE GEOMETRIES ---

struct CrystalTemplateView: View {

    let type: Int

    var body: some View {

        Group {

            if type == 0 {

                Path { path in

                    for i in 0..<6 {

                        let angle = CGFloat(i) * .pi / 3.0

                        path.move(to: .zero)

                        path.addLine(
                            to: CGPoint(
                                x: 15 * cos(angle),
                                y: 15 * sin(angle)
                            )
                        )

                        let midX = 10 * cos(angle)
                        let midY = 10 * sin(angle)

                        path.move(to: CGPoint(x: midX, y: midY))

                        path.addLine(
                            to: CGPoint(
                                x: midX + 5 * cos(angle + .pi/4),
                                y: midY + 5 * sin(angle + .pi/4)
                            )
                        )

                        path.move(to: CGPoint(x: midX, y: midY))

                        path.addLine(
                            to: CGPoint(
                                x: midX + 5 * cos(angle - .pi/4),
                                y: midY + 5 * sin(angle - .pi/4)
                            )
                        )
                    }
                }
                .stroke(
                    Color.white,
                    style: StrokeStyle(
                        lineWidth: 2.2,
                        lineCap: .round
                    )
                )

            } else if type == 1 {

                Path { path in

                    for i in 0..<6 {

                        let angle = CGFloat(i) * .pi / 3.0

                        path.move(to: .zero)

                        path.addLine(
                            to: CGPoint(
                                x: 14 * cos(angle),
                                y: 14 * sin(angle)
                            )
                        )

                        let tipX = 9 * cos(angle)
                        let tipY = 9 * sin(angle)

                        path.move(to: CGPoint(x: tipX, y: tipY))

                        path.addLine(
                            to: CGPoint(
                                x: tipX + 4 * cos(angle + .pi/3),
                                y: tipY + 4 * sin(angle + .pi/3)
                            )
                        )

                        path.move(to: CGPoint(x: tipX, y: tipY))

                        path.addLine(
                            to: CGPoint(
                                x: tipX + 4 * cos(angle - .pi/3),
                                y: tipY + 4 * sin(angle - .pi/3)
                            )
                        )
                    }
                }
                .stroke(
                    Color.white,
                    style: StrokeStyle(
                        lineWidth: 1.8,
                        lineCap: .round
                    )
                )

            } else {

                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: Color.white.opacity(0.6),
                        radius: 1
                    )
            }
        }
        .frame(width: 32, height: 32)
    }
}
