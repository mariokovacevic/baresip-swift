import UIKit
import BaresipKit
import BaresipKitVideo

/// Keeps a small picture of each video call, such as a door station's camera, for the recent
/// calls list.
@MainActor
final class CallSnapshots {
    private final class WeakView {
        weak var view: BaresipVideoView?

        init(_ view: BaresipVideoView) {
            self.view = view
        }
    }

    private static let thumbnailWidth: CGFloat = 240
    private static let jpegQuality: CGFloat = 0.7
    private var views: [BaresipCallID: WeakView] = [:]
    private var taken: [BaresipCallID: String] = [:]

    /// Remembers the view showing a call's remote video.
    func register(_ view: BaresipVideoView, for call: BaresipCallID) {
        views[call] = WeakView(view)
    }

    /// Saves the picture on screen, once per call.
    func capture(_ call: BaresipCallID) {
        guard taken[call] == nil, let image = views[call]?.view?.snapshot(),
              let data = Self.thumbnail(of: image) else { return }
        let name = "\(UUID().uuidString).jpg"
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try data.write(to: Self.directory.appendingPathComponent(name), options: .atomic)
            taken[call] = name
        } catch {
            return
        }
    }

    /// Captures a last picture if there is none yet and returns the file name for the call record.
    func finish(_ call: BaresipCallID) -> String? {
        capture(call)
        views[call] = nil
        return taken.removeValue(forKey: call)
    }

    static func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }

    /// Deletes the pictures that neither a call record nor a running call refers to.
    func prune(keeping names: Set<String>) {
        let keep = names.union(taken.values)
        let directory = Self.directory
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for file in files where !keep.contains(file) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(file))
        }
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CallSnapshots", isDirectory: true)
    }

    private static func thumbnail(of image: CGImage) -> Data? {
        let scale = min(1, thumbnailWidth / CGFloat(image.width))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: jpegQuality)
    }
}
