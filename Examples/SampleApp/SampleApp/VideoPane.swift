import SwiftUI
import BaresipKit
import BaresipKitVideo

struct VideoPane: UIViewRepresentable {
    @EnvironmentObject private var model: CallModel
    let callID: BaresipCallID
    let local: Bool

    final class Coordinator {
        var attachedCall: BaresipCallID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BaresipVideoView {
        let view = BaresipVideoView()
        attach(view, context: context)
        return view
    }

    func updateUIView(_ uiView: BaresipVideoView, context: Context) {
        attach(uiView, context: context)
    }

    private func attach(_ view: BaresipVideoView, context: Context) {
        guard context.coordinator.attachedCall != callID, let engine = model.engine else { return }
        context.coordinator.attachedCall = callID
        let renderer = view.renderer
        let call = callID
        let local = local
        Task {
            try? await engine.setVideoRenderer(renderer, callID: call, local: local)
        }
    }
}
