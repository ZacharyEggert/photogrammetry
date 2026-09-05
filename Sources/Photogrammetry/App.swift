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
        WindowGroup("Photogrammetry") {
            ContentView().frame(minWidth: 420, minHeight: 260)
        }
    }
}

@MainActor
@Observable
final class Model {
    var imagesURL: URL?
    var status = "Pick a folder of images."
    var progress = 0.0
    var running = false
    var outputURL: URL?

    func run(detail: PhotogrammetrySession.Request.Detail) async {
        guard let input = imagesURL else { return }
        // Detail in the name so re-runs at another scale don't collide.
        let output = input.deletingLastPathComponent()
            .appendingPathComponent("\(input.lastPathComponent)-\(detail).usdz")
        running = true; progress = 0; outputURL = nil
        defer { running = false }
        do {
            let session = try PhotogrammetrySession(input: input)
            try session.process(requests: [.modelFile(url: output, detail: detail)])
            outputs: for try await out in session.outputs {
                switch out {
                case .requestProgress(_, let f): progress = f; status = "Processing…"
                case .requestComplete: outputURL = output; status = "Done: \(output.path)"
                case .requestError(_, let e): status = "Error: \(e.localizedDescription)"
                // Terminal: the stream stays open otherwise and the UI never re-enables.
                case .processingComplete: break outputs
                default: break
                }
            }
        } catch {
            status = "Failed: \(error.localizedDescription)"
        }
    }
}

struct ContentView: View {
    @State private var model = Model()
    @State private var detail: PhotogrammetrySession.Request.Detail = .medium

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button("Choose Images Folder…") { pick() }
                Text(model.imagesURL?.lastPathComponent ?? "none").foregroundStyle(.secondary)
            }
            Picker("Detail", selection: $detail) {
                ForEach([PhotogrammetrySession.Request.Detail.preview, .reduced, .medium, .full, .raw], id: \.self) {
                    Text(String(describing: $0)).tag($0)
                }
            }.pickerStyle(.segmented)
            Button("Generate USDZ") { Task { await model.run(detail: detail) } }
                .disabled(model.imagesURL == nil || model.running)
            if model.running { ProgressView(value: model.progress) }
            Text(model.status).font(.caption).textSelection(.enabled)
            if let out = model.outputURL {
                Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([out]) }
            }
            Spacer()
        }
        .padding()
    }

    private func pick() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        guard p.runModal() == .OK, let url = p.url else { return }
        model.imagesURL = url
        let n = (try? FileManager.default.contentsOfDirectory(atPath: url.path).count) ?? 0
        // ponytail: Object Capture wants dense orbital coverage; warn instead of failing 20 min in.
        model.status = n < 20 ? "\(n) images — expect failure; 20+ overlapping shots recommended." : "\(n) images. Ready."
    }
}
