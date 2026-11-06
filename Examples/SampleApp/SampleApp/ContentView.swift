import SwiftUI
import BaresipKit

enum CallScreen: String, Identifiable {
    case incoming
    case inCall

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        NavigationStack {
            CallsHomeView()
        }
        .task { await model.start() }
        .fullScreenCover(item: screen) { screen in
            switch screen {
            case .incoming:
                IncomingCallView()
                    .environmentObject(model)
            case .inCall:
                InCallView()
                    .environmentObject(model)
            }
        }
    }

    private var screen: Binding<CallScreen?> {
        Binding(
            get: {
                if model.incoming != nil {
                    return .incoming
                }
                if model.currentCall != nil && !model.callMinimized {
                    return .inCall
                }
                return nil
            },
            set: { value in
                if value == nil && model.incoming == nil && model.currentCall != nil {
                    model.callMinimized = true
                }
            }
        )
    }
}
