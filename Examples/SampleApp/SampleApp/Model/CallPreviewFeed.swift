import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import BaresipKit
import BaresipKitVideo

/// Passes a ringing call's video on to the view showing it and saves a picture of it a few
/// times a second, for the call's notification and the live preview inside it.
///
/// Attach it with `BaresipEngine.setVideoRenderer(_:callID:local:)`. A call has one renderer,
/// so the incoming call screen shows the video through ``setDisplay(_:)`` instead of attaching
/// a view of its own.
final class CallPreviewFeed: BaresipVideoRenderer, @unchecked Sendable {
    // SAFETY: `state` is read and written only while holding `lock`; everything else is constant.
    private struct State {
        var display: BaresipVideoRenderer?
        var lastSaved: ContinuousClock.Instant?
        var saving = false
        var announced = false
        var stopped = false
    }

    private static let interval: Duration = .milliseconds(250)
    private static let quality = 0.6

    let call: BaresipCallID
    let file: URL
    private let lock = NSLock()
    private var state = State()
    private let queue = DispatchQueue(label: "com.example.BaresipKitSample.preview-feed", qos: .utility)
    private let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
    private let onFirstPicture: @Sendable () -> Void

    /// Creates the feed.
    ///
    /// - Parameters:
    ///   - call: The ringing call.
    ///   - file: Where the latest picture is written, as JPEG.
    ///   - onFirstPicture: Called once, on a background queue, after the first picture was saved.
    init(call: BaresipCallID, file: URL, onFirstPicture: @escaping @Sendable () -> Void) {
        self.call = call
        self.file = file
        self.onFirstPicture = onFirstPicture
    }

    /// Sets the renderer that shows the video, or removes it.
    func setDisplay(_ renderer: BaresipVideoRenderer?) {
        lock.withLock { state.display = renderer }
    }

    /// Removes the renderer that shows the video, unless another one replaced it meanwhile.
    func removeDisplay(_ renderer: BaresipVideoRenderer) {
        lock.withLock {
            if state.display === renderer {
                state.display = nil
            }
        }
    }

    /// Stops saving pictures and deletes the last one.
    func stop() {
        lock.withLock {
            state.stopped = true
            state.display = nil
        }
        queue.async { [file] in
            try? FileManager.default.removeItem(at: file)
        }
    }

    func render(_ frame: BaresipVideoFrame) {
        let (display, save) = lock.withLock { () -> (BaresipVideoRenderer?, Bool) in
            guard !state.stopped else { return (nil, false) }
            let now = ContinuousClock.now
            let due = state.lastSaved.map { now - $0 >= Self.interval } ?? true
            guard due, !state.saving else { return (state.display, false) }
            state.saving = true
            state.lastSaved = now
            return (state.display, true)
        }
        display?.render(frame)
        guard save else { return }
        queue.async { [self] in
            let saved = write(frame)
            let announce = lock.withLock { () -> Bool in
                state.saving = false
                guard saved, !state.announced, !state.stopped else { return false }
                state.announced = true
                return true
            }
            if announce {
                onFirstPicture()
            }
        }
    }

    func didChangeSize(width: Int, height: Int) {
        lock.withLock { state.display }?.didChangeSize(width: width, height: height)
    }

    private func write(_ frame: BaresipVideoFrame) -> Bool {
        guard !lock.withLock({ state.stopped }), let image = frame.makeImage(context: context) else { return false }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData,
                                                                 UTType.jpeg.identifier as CFString, 1, nil)
        else { return false }
        let options = [kCGImageDestinationLossyCompressionQuality: Self.quality] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return false }
        return (try? (data as Data).write(to: file, options: .atomic)) != nil
    }
}
