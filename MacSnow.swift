// --- MacSnow 1.0, Oct 31 2026 ---
// --- Functional Gemini slop (in a Brave browser window lol) ---

import SwiftUI
import AppKit
import Combine

// --- 1. DATA MODEL FOR BRIGHT, EFFICIENT SNOWFLAKES ---
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
    // Calibrated Baseline: 1.0 starts exactly at your previous maximum speed baseline
    @Published var speedMultiplier: Double = 1.5
    @Published var sizeMultiplier: Double = 1.0
    @Published var isSnowing: Bool = true
}

// --- 3. MAIN APPLICATION LIFECYCLE ---
@main
struct MacSnowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

// --- 4. APP DELEGATE MANAGING MULTIPLE WINDOW LAYERS ---
class AppDelegate: NSObject, NSApplicationDelegate {
    var snowWindows: [NSWindow] = []
    var controlWindow: NSWindow?
    let settings = SnowSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Step A: Build a transparent, click-through overlay window for each connected monitor
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
            
            // Keeps snow floating above normal windows, but completely passes mouse clicks through
            snowWindow.level = .mainMenu + 1
            snowWindow.ignoresMouseEvents = true
            snowWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            
            let contentView = NSHostingView(rootView: SnowCanvasView(screenSize: frame.size, settings: settings))
            snowWindow.contentView = contentView
            
            snowWindow.makeKeyAndOrderFront(nil)
            snowWindows.append(snowWindow)
        }
        
        // Step B: Build the standalone control center settings window
        let controlBox = NSWindow(
            contentRect: NSRect(x: 150, y: 150, width: 320, height: 250),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        controlBox.title = "❄️ MacSnow Control Center"
        controlBox.level = .floating
        controlBox.isReleasedWhenClosed = false
        
        let controlView = NSHostingView(rootView: ControlPanelView(settings: settings))
        controlBox.contentView = controlView
        controlBox.center()
        controlBox.makeKeyAndOrderFront(nil)
        
        self.controlWindow = controlBox
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// --- 5. INTERACTIVE CONTROL CENTER INTERFACE ---
struct ControlPanelView: View {
    @ObservedObject var settings: SnowSettings
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MacSnow Settings")
                .font(.headline)
                .padding(.top, 15)
            
            // High-efficiency operational switch
            Button(action: {
                settings.isSnowing.toggle()
            }) {
                HStack {
                    Image(systemName: settings.isSnowing ? "stop.fill" : "play.fill")
                    Text(settings.isSnowing ? "Stop Snowfall" : "Start Snowfall")
                        .font(.body).bold()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(settings.isSnowing ? Color.gray : Color.green)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Snow Velocity:")
                    Spacer()
                    // Interface text matches the faster speed scale boundaries perfectly
                    Text(settings.speedMultiplier < 1.5 ? "Heavy" : settings.speedMultiplier > 2.5 ? "Blizzard" : "Gentle")
                        .foregroundColor(.secondary)
                }
                // Slider scale begins at previous maximum (1.0) and ranges cleanly to 3.0x speed
                Slider(value: $settings.speedMultiplier, in: 2.0...15.0)
                    .disabled(!settings.isSnowing)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Flake Scale Size:")
                    Spacer()
                    Text(String(format: "%.1fx", settings.sizeMultiplier))
                        .foregroundColor(.secondary)
                }
                Slider(value: $settings.sizeMultiplier, in: 0.5...3.0)
                    .disabled(!settings.isSnowing)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 15)
        .frame(width: 320, height: 250)
    }
}

// --- 6. CLEAN TIMELINE GRAPHICS RENDERING CANVAS ---
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
            temporaryFlakes.append(Snowflake(
                initialX: CGFloat.random(in: -50...screenSize.width + 50),
                speedMultiplier: CGFloat.random(in: 30...90),
                size: CGFloat.random(in: 5...10),
                opacity: Double.random(in: 0.65...0.95),
                swingWidth: CGFloat.random(in: 6...18),
                swingSpeed: Double.random(in: 0.4...1.2),
                type: Int.random(in: 0...2)
            ))
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
                            guard let resolvedFlake = context.resolveSymbol(id: flake.type) else { continue }
                            
                            let currentGlobalSpeed = CGFloat(settings.speedMultiplier)
                            let currentGlobalSize = CGFloat(settings.sizeMultiplier)
                            
                            // Math position parsing calculated via linear physics tracking equations
                            let calculatedFall = flake.speedMultiplier * currentGlobalSpeed * CGFloat(timeSeconds * 0.5)
                            let currentY = (calculatedFall).truncatingRemainder(dividingBy: screenSize.height + 60) - 30
                            
                            let currentSway = sin(timeSeconds * flake.swingSpeed) * Double(flake.swingWidth)
                            let currentX = flake.initialX + CGFloat(currentSway)
                            
                            var innerContext = context
                            innerContext.opacity = flake.opacity
                            
                            innerContext.translateBy(x: currentX, y: currentY)
                            
                            let calculatedRotation = timeSeconds * Double(flake.speedMultiplier * 0.2)
                            innerContext.rotate(by: Angle(degrees: calculatedRotation))
                            
                            let dynamicSize = flake.size * currentGlobalSize
                            let scale = dynamicSize / 30.0
                            innerContext.scaleBy(x: scale, y: scale)
                            
                            innerContext.draw(resolvedFlake, at: .zero)
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

// --- 7. PRE-RENDERED HIGH-QUALITY CRYSTAL MATHEMATICAL GEOMETRIES ---
struct CrystalTemplateView: View {
    let type: Int
    
    var body: some View {
        Group {
            if type == 0 {
                Path { path in
                    for i in 0..<6 {
                        let angle = CGFloat(i) * .pi / 3.0
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: 15 * cos(angle), y: 15 * sin(angle)))
                        
                        let midX = 10 * cos(angle)
                        let midY = 10 * sin(angle)
                        path.move(to: CGPoint(x: midX, y: midY))
                        path.addLine(to: CGPoint(x: midX + 5 * cos(angle + .pi/4), y: midY + 5 * sin(angle + .pi/4)))
                        path.move(to: CGPoint(x: midX, y: midY))
                        path.addLine(to: CGPoint(x: midX + 5 * cos(angle - .pi/4), y: midY + 5 * sin(angle - .pi/4)))
                    }
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            } else if type == 1 {
                Path { path in
                for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3.0
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: 14 * cos(angle), y: 14 * sin(angle)))
                let tipX = 9 * cos(angle)
                let tipY = 9 * sin(angle)
                path.move(to: CGPoint(x: tipX, y: tipY))
                path.addLine(to: CGPoint(x: tipX + 4 * cos(angle + .pi/3), y: tipY + 4 * sin(angle + .pi/3)))
                path.move(to: CGPoint(x: tipX, y: tipY))
                path.addLine(to: CGPoint(x: tipX + 4 * cos(angle - .pi/3), y: tipY + 4 * sin(angle - .pi/3)))
                }
                }
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                } else {
                Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
                .shadow(color: Color.white.opacity(0.6), radius: 1)
                }
                }
                .frame(width: 32, height: 32)
                }
                }
