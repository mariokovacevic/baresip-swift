import SwiftUI
import UIKit
import BaresipKit
import BaresipKitCallKit

enum CallScreen: String, Identifiable {
    case incoming
    case inCall

    var id: String {
        rawValue
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: CallModel

    var body: some View {
        TabView(selection: $model.tab) {
            NavigationStack {
                if model.settings.isComplete {
                    DoorsView().screenBackground()
                } else {
                    SetupView().screenBackground()
                }
            }
            .appTab(.doors, title: "Doors", systemImage: "house")
            NavigationStack { ActivityView().screenBackground() }
                .appTab(.activity, title: "Activity", systemImage: "clock")
            NavigationStack { KeypadView().screenBackground() }
                .appTab(.keypad, title: "Keypad", systemImage: "circle.grid.3x3.fill")
            NavigationStack { MessagesListView().screenBackground() }
                .badge(model.unreadCount())
                .appTab(.messages, title: "Messages", systemImage: "bubble.left")
            NavigationStack { SettingsView().screenBackground() }
                .appTab(.settings, title: "Settings", systemImage: "slider.horizontal.3")
        }
        .tint(Theme.brass)
        .preferredColorScheme(.dark)
        .task { await model.start() }
        .onContinueUserActivity(BaresipRedialRequest.activityType) { activity in
            guard let request = BaresipRedialRequest(activity: activity) else { return }
            Task { await model.redial(request) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            model.showPreviewNotificationIfHidden()
        }
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
                if model.callOnScreen != nil, !model.callMinimized {
                    return .inCall
                }
                return nil
            },
            set: { value in
                if value == nil, model.incoming == nil, model.callOnScreen != nil {
                    model.callMinimized = true
                }
            }
        )
    }
}

extension View {
    /// The app's dark ground behind a screen.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    /// A tab of the app, with links and controls in the link color.
    func appTab(_ tab: AppTab, title: String, systemImage: String) -> some View {
        tint(Theme.info)
            .tabItem { Label(title, systemImage: systemImage) }
            .tag(tab)
    }
}
