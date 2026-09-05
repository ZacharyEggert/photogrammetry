import SwiftUI
import RealityKit
import UniformTypeIdentifiers

@main
struct PhotogrammetryApp: App {
    // ponytail: no .xcodeproj — this makes the bundle-less SwiftPM binary a real GUI app,
    // so `swift run` and Xcode's Run button both show a window.
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async { NSApp.activate(ignoringOtherApps: true) }
    }

    var body: some SwiftUI.Scene {
        WindowGroup("Photogrammetry Utility") {
            ContentView().frame(minWidth: 460, minHeight: 470)
        }
        .windowResizability(.contentMinSize)
    }
}

// MARK: - Cyanotype palette
// Blueprint blues from the process this app descends from; safelight red only for trouble.
private func hex(_ v: UInt32) -> NSColor {
    NSColor(srgbRed: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255, alpha: 1)
}
private func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(nsColor: NSColor(name: nil) { hex($0.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light) })
}
enum Ink {
    static let bg        = dyn(0xE9EEF3, 0x0B1B29)
    static let surface   = dyn(0xFFFFFF, 0x12283A)
    static let text      = dyn(0x12303F, 0xDDE8F0)
    static let muted     = dyn(0x5C7488, 0x7D97AC)
    static let line      = dyn(0xC3D2DE, 0x1E3A50)
    static let trace     = dyn(0x1B6E9B, 0x4FB0DE)
    static let safelight = dyn(0xC4402B, 0xE2664C)
}
private extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func mono(_ size: CGFloat, _ weight: Weight = .regular) -> Font { .system(size: size, weight: weight, design: .monospaced) }
}

@MainActor
@Observable
final class Model {
    var imagesURL: URL?
    var imageCount = 0
    var status = "Twenty or more overlapping photos, shot in one full circle around a single object, evenly lit."
    var trouble = false
    var progress = 0.0
    var running = false
    var outputURL: URL?

    private static let photoTypes: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "dng", "cr2", "cr3", "arw", "nef", "raf", "orf"]

    func select(_ url: URL) {
        imagesURL = url
        outputURL = nil
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        imageCount = names.filter { Self.photoTypes.contains(($0 as NSString).pathExtension.lowercased()) }.count
        // ponytail: Object Capture wants dense orbital coverage; warn instead of failing 20 min in.
        trouble = imageCount < 20
        status = trouble
            ? "\(imageCount) photos. Reconstruction needs 20 or more overlapping shots to succeed."
            : "\(imageCount) photos ready in \(url.lastPathComponent)."
    }

    func run(detail: PhotogrammetrySession.Request.Detail) async {
        guard let input = imagesURL else { return }
        // Detail in the name so re-runs at another scale don't collide.
        let output = input.deletingLastPathComponent()
            .appendingPathComponent("\(input.lastPathComponent)-\(detail).usdz")
        running = true; progress = 0; outputURL = nil; trouble = false
        status = "Aligning photos…"
        defer { running = false }
        do {
            let session = try PhotogrammetrySession(input: input)
            try session.process(requests: [.modelFile(url: output, detail: detail)])
            outputs: for try await out in session.outputs {
                switch out {
                case .requestProgress(_, let f):
                    progress = f
                    status = "Building model — \(Int(f * 100))% of the orbit solved."
                case .requestComplete:
                    outputURL = output; progress = 1
                    status = "Saved \(output.lastPathComponent) beside your photos."
                case .requestError(_, let e):
                    trouble = true; status = e.localizedDescription
                // Terminal: the stream stays open otherwise and the UI never re-enables.
                case .processingComplete: break outputs
                default: break
                }
            }
        } catch {
            trouble = true
            status = error.localizedDescription
        }
    }
}

// MARK: - Signature: the camera orbit
// Object Capture asks you to walk a circle around the subject. The dial is that circle:
// 36 stations, long ones at the quarter turns, filling as the solve advances.
struct OrbitDial: View {
    var progress: Double
    var live: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let stations = 36
    private let radius: CGFloat = 74

    var body: some View {
        ZStack {
            ForEach(0..<stations, id: \.self) { i in
                let solved = Double(i) / Double(stations) < progress
                Capsule()
                    .fill(solved ? Ink.trace : Ink.muted.opacity(0.45))
                    .frame(width: 2, height: i % 9 == 0 ? 13 : 7)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(i) / Double(stations) * 360))
            }
        }
        .frame(width: radius * 2 + 14, height: radius * 2 + 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: progress)
        .overlay {
            if live && !reduceMotion {
                Circle()
                    .stroke(Ink.trace.opacity(0.35), lineWidth: 1)
                    .frame(width: radius * 2 + 14, height: radius * 2 + 14)
                    .scaleEffect(1.06)
                    .opacity(0.0)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: live)
            }
        }
    }
}

// The five detail levels are a real ordered scale, so the control is a ladder, not a row of tabs.
struct FidelityLadder: View {
    @Binding var detail: PhotogrammetrySession.Request.Detail
    var enabled: Bool

    private let stops: [(PhotogrammetrySession.Request.Detail, String, CGFloat)] = [
        (.preview, "preview", 6), (.reduced, "reduced", 11), (.medium, "medium", 16),
        (.full, "full", 21), (.raw, "raw", 26)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FIDELITY")
                .font(.mono(10, .medium)).tracking(1.4).foregroundStyle(Ink.muted)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(stops, id: \.0) { stop, label, height in
                    let on = detail == stop
                    Button {
                        detail = stop
                    } label: {
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(on ? Ink.trace : Ink.line)
                                .frame(width: 3, height: height)
                            Text(label)
                                .font(.mono(10, on ? .semibold : .regular))
                                .foregroundStyle(on ? Ink.text : Ink.muted)
                        }
                        .frame(width: 62)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .help("\(label) detail")
                }
            }
            .frame(maxWidth: .infinity)
            .background(alignment: .bottom) { Rectangle().fill(Ink.line).frame(height: 1).padding(.bottom, 22) }
            .opacity(enabled ? 1 : 0.4)
            .disabled(!enabled)
        }
    }
}

struct FlatButton: ButtonStyle {
    var filled = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(filled ? Ink.surface : Ink.text)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 7)
                    .fill(filled ? Ink.trace : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(filled ? .clear : Ink.line))
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
    }
}

struct ContentView: View {
    @State private var model = Model()
    @State private var detail: PhotogrammetrySession.Request.Detail = .medium
    @State private var targeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Photos in, object out.")
                .font(.display(26)).foregroundStyle(Ink.text)

            dial.padding(.vertical, 26)

            FidelityLadder(detail: $detail, enabled: !model.running)

            HStack(spacing: 10) {
                Button("Choose folder") { pick() }
                    .buttonStyle(FlatButton())
                Button(model.running ? "Building…" : "Build model") {
                    Task { await model.run(detail: detail) }
                }
                .buttonStyle(FlatButton(filled: true))
                .disabled(model.imagesURL == nil || model.running)
                Spacer()
                if let out = model.outputURL {
                    Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([out]) }
                        .buttonStyle(FlatButton())
                }
            }
            .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Ink.bg)
    }

    // The dial carries every state: waiting, loaded, solving, done.
    private var dial: some View {
        HStack {
            ZStack {
                OrbitDial(progress: model.running || model.outputURL != nil ? model.progress : 0,
                          live: model.running)
                VStack(spacing: 3) {
                    if model.running {
                        Text("\(Int(model.progress * 100))")
                            .font(.display(34)).foregroundStyle(Ink.text)
                            .monospacedDigit()
                        Text("PER CENT").font(.mono(9, .medium)).tracking(1.4).foregroundStyle(Ink.muted)
                    } else if model.outputURL != nil {
                        Text("USDZ").font(.mono(15, .semibold)).foregroundStyle(Ink.trace)
                        Text("model ready").font(.mono(9)).foregroundStyle(Ink.muted)
                    } else if let url = model.imagesURL {
                        Text("\(model.imageCount)")
                            .font(.display(34)).foregroundStyle(Ink.text)
                        Text("PHOTOS").font(.mono(9, .medium)).tracking(1.4).foregroundStyle(Ink.muted)
                        Text(url.lastPathComponent)
                            .font(.mono(9)).foregroundStyle(Ink.muted)
                            .lineLimit(1).truncationMode(.middle).frame(maxWidth: 108)
                            .padding(.top, 2)
                    } else {
                        Text("Drop photos")
                            .font(.display(17)).foregroundStyle(Ink.text)
                        Text("one full orbit").font(.mono(9)).foregroundStyle(Ink.muted)
                    }
                }
            }
            .scaleEffect(targeted ? 1.03 : 1)
            .animation(.easeOut(duration: 0.15), value: targeted)
            .contentShape(Circle())
            .onTapGesture { if let out = model.outputURL { NSWorkspace.shared.activateFileViewerSelecting([out]) } }
            .dropDestination(for: URL.self) { urls, _ in
                guard !model.running, let url = urls.first(where: \.hasDirectoryPath) else { return false }
                model.select(url)
                return true
            } isTargeted: { targeted = $0 && !model.running }
            .accessibilityElement()
            .accessibilityLabel("Camera orbit")
            .accessibilityValue(model.running ? "\(Int(model.progress * 100)) per cent solved" : model.status)
            Text(model.status)
                .font(.mono(11))
                .lineSpacing(3)
                .foregroundStyle(model.trouble ? Ink.safelight : Ink.muted)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 22)
        }
    }

    private func pick() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.prompt = "Use folder"
        guard p.runModal() == .OK, let url = p.url else { return }
        model.select(url)
    }
}
