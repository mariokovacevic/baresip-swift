#if canImport(UIKit)
    import AVFoundation
    import SwiftUI
    import BaresipKit
    import BaresipKitVideo

    @MainActor
    public extension BaresipCallVideo {
        /// Creates a view of a phone call's remote video or of the camera image it sends.
        ///
        /// The camera image is mirrored while the front camera is used.
        ///
        /// - Parameters:
        ///   - call: The call.
        ///   - source: The remote video or the camera image sent.
        ///   - videoGravity: How the video fills the view, or `nil` to fit the remote video and
        ///     fill the view with the camera image.
        ///   - onViewCreated: Called once with the underlying view, for example to take snapshots.
        init(call: BaresipPhoneCall, source: Source = .remote, videoGravity: AVLayerVideoGravity? = nil,
             onViewCreated: (@MainActor (BaresipVideoView) -> Void)? = nil) {
            self.init(engine: call.engine, callID: call.id, source: source,
                      mirrored: source == .local && call.camera.isMirroredInPreview,
                      videoGravity: videoGravity, onViewCreated: onViewCreated)
        }
    }

    /// The small picture of your own camera that call screens show in a corner while the camera
    /// is sent.
    ///
    /// It shows nothing while ``BaresipPhoneCall/isSendingVideo`` is `false`, mirrors the front
    /// camera, and switches between the front and back camera when tapped. Place it in an
    /// overlay, for example:
    ///
    /// ```swift
    /// RemoteVideo()
    ///     .overlay(alignment: .topTrailing) {
    ///         BaresipSelfView(call: call).padding()
    ///     }
    /// ```
    ///
    /// Build your own with `BaresipCallVideo` and `source: .local` for a different look.
    public struct BaresipSelfView: View {
        @ObservedObject private var call: BaresipPhoneCall
        private let size: CGSize
        private let cornerRadius: CGFloat
        private let switchesCameraOnTap: Bool

        /// Creates the view.
        ///
        /// - Parameters:
        ///   - call: The call whose camera image to show.
        ///   - size: The size of the picture.
        ///   - cornerRadius: The radius of the rounded corners.
        ///   - switchesCameraOnTap: Whether a tap switches between the front and back camera.
        public init(call: BaresipPhoneCall, size: CGSize = CGSize(width: 100, height: 140),
                    cornerRadius: CGFloat = 12, switchesCameraOnTap: Bool = true) {
            self.call = call
            self.size = size
            self.cornerRadius = cornerRadius
            self.switchesCameraOnTap = switchesCameraOnTap
        }

        /// The picture, or nothing while the camera is not sent.
        public var body: some View {
            if call.isSendingVideo {
                BaresipCallVideo(call: call, source: .local)
                    .frame(width: size.width, height: size.height)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.35), lineWidth: 1))
                    .shadow(radius: 6)
                    .onTapGesture {
                        guard switchesCameraOnTap else { return }
                        Task { try? await call.switchCamera() }
                    }
                    .accessibilityElement()
                    .accessibilityLabel(Text("Your camera"))
                    .accessibilityHint(switchesCameraOnTap ? Text("Switches between the front and back camera") :
                        Text(""))
                    .accessibilityAddTraits(switchesCameraOnTap ? .isButton : [])
            }
        }
    }
#endif
