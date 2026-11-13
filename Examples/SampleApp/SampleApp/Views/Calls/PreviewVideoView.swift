import SwiftUI
import BaresipKitVideo

/// Shows the video of a ringing call that a ``CallPreviewFeed`` receives.
struct PreviewVideoView: UIViewRepresentable {
    final class Coordinator {
        let feed: CallPreviewFeed
        var renderer: BaresipVideoRenderer?

        init(feed: CallPreviewFeed) {
            self.feed = feed
        }
    }

    let feed: CallPreviewFeed
    var onViewCreated: (BaresipVideoView) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(feed: feed)
    }

    func makeUIView(context: Context) -> BaresipVideoView {
        let view = BaresipVideoView()
        let renderer = view.renderer
        context.coordinator.renderer = renderer
        feed.setDisplay(renderer)
        onViewCreated(view)
        return view
    }

    func updateUIView(_ uiView: BaresipVideoView, context: Context) {}

    static func dismantleUIView(_ uiView: BaresipVideoView, coordinator: Coordinator) {
        if let renderer = coordinator.renderer {
            coordinator.feed.removeDisplay(renderer)
        }
    }
}
