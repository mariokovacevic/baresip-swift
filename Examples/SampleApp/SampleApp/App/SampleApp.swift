import SwiftUI
import BaresipKit

@main
struct SampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = CallModel()

    init() {
        let info = Bundle.main.infoDictionary
        FileLog.shared.write("""
        launched \(Bundle.main.bundleIdentifier ?? "") \
        \(info?["CFBundleShortVersionString"] as? String ?? "") (\(info?["CFBundleVersion"] as? String ?? "")), \
        BaresipKit core \(BaresipEngine.coreVersion)
        """)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .onAppear { appDelegate.model = model }
        }
    }
}
