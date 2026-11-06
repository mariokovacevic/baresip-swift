import SwiftUI

@main
struct SampleApp: App {
    @StateObject private var model = CallModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
        }
    }
}
