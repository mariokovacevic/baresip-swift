#if canImport(UIKit)
    import AVFoundation
    import SwiftUI
    import UIKit
    import BaresipKit

    /// A SwiftUI view that shows a call's remote video or the camera image the call sends.
    ///
    /// The view attaches its renderer to the call when it appears or the call changes, and
    /// detaches it when it goes away, unless another view took over in the meantime.
    ///
    /// ```swift
    /// ZStack(alignment: .topTrailing) {
    ///     BaresipCallVideo(engine: engine, callID: call)
    ///     BaresipCallVideo(engine: engine, callID: call, source: .local, mirrored: true)
    ///         .frame(width: 100, height: 140)
    /// }
    /// ```
    ///
    /// For more control, use ``BaresipVideoView`` with
    /// `BaresipEngine.setVideoRenderer(_:callID:local:)` directly.
    public struct BaresipCallVideo: UIViewRepresentable {
        /// Which video of the call to show.
        public enum Source: Sendable, Hashable {
            /// The other side's video.
            case remote
            /// The camera image this side sends.
            case local
        }

        let engine: BaresipEngine
        let callID: BaresipCallID
        let source: Source
        let mirrored: Bool
        let videoGravity: AVLayerVideoGravity
        let onViewCreated: (@MainActor (BaresipVideoView) -> Void)?

        /// Creates the view.
        ///
        /// - Parameters:
        ///   - engine: The engine of the call.
        ///   - callID: The call.
        ///   - source: The remote video or the camera image sent.
        ///   - mirrored: Whether to flip the picture horizontally, as people expect for their own
        ///     front camera.
        ///   - videoGravity: How the video fills the view, or `nil` to fit the remote video and
        ///     fill the view with the camera image.
        ///   - onViewCreated: Called once with the underlying view, for example to take snapshots.
        public init(engine: BaresipEngine, callID: BaresipCallID, source: Source = .remote,
                    mirrored: Bool = false, videoGravity: AVLayerVideoGravity? = nil,
                    onViewCreated: (@MainActor (BaresipVideoView) -> Void)? = nil) {
            self.engine = engine
            self.callID = callID
            self.source = source
            self.mirrored = mirrored
            self.videoGravity = videoGravity ?? (source == .local ? .resizeAspectFill : .resizeAspect)
            self.onViewCreated = onViewCreated
        }

        /// Remembers what a view is attached to.
        public final class Coordinator {
            var attached: Attachment?
            weak var engine: BaresipEngine?
        }

        struct Attachment: Hashable {
            let engine: ObjectIdentifier
            let callID: BaresipCallID
            let local: Bool
        }

        /// The view attached last to each call video, so a view that goes away does not detach
        /// the view that replaced it.
        @MainActor private static var owners: [Attachment: ObjectIdentifier] = [:]

        /// Creates the coordinator.
        ///
        /// - Returns: The coordinator.
        public func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        /// Creates the video view and attaches it to the call.
        ///
        /// - Parameter context: The context.
        /// - Returns: The view.
        public func makeUIView(context: Context) -> BaresipVideoView {
            let view = BaresipVideoView()
            configure(view)
            attach(view, coordinator: context.coordinator)
            onViewCreated?(view)
            return view
        }

        /// Applies changed options and attaches the view to a changed call.
        ///
        /// - Parameters:
        ///   - uiView: The view.
        ///   - context: The context.
        public func updateUIView(_ uiView: BaresipVideoView, context: Context) {
            configure(uiView)
            attach(uiView, coordinator: context.coordinator)
        }

        /// Detaches the view from the call unless another view replaced it.
        ///
        /// - Parameters:
        ///   - uiView: The view.
        ///   - coordinator: The coordinator.
        public static func dismantleUIView(_ uiView: BaresipVideoView, coordinator: Coordinator) {
            guard let attachment = coordinator.attached,
                  owners[attachment] == ObjectIdentifier(uiView),
                  let engine = coordinator.engine else { return }
            owners[attachment] = nil
            Task {
                try? await engine.setVideoRenderer(nil, callID: attachment.callID, local: attachment.local)
            }
        }

        private func configure(_ view: BaresipVideoView) {
            view.videoGravity = videoGravity
            view.transform = mirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        }

        private func attach(_ view: BaresipVideoView, coordinator: Coordinator) {
            let attachment = Attachment(engine: ObjectIdentifier(engine), callID: callID, local: source == .local)
            guard coordinator.attached != attachment else { return }
            coordinator.attached = attachment
            coordinator.engine = engine
            Self.owners[attachment] = ObjectIdentifier(view)
            let renderer = view.renderer
            let engine = engine
            Task {
                try? await engine.setVideoRenderer(renderer, callID: attachment.callID, local: attachment.local)
            }
        }
    }
#endif
