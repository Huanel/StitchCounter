import SwiftUI

@main
struct Stitch_Counter_Watch_AppApp: App {
    @StateObject private var projectStore = ProjectStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectStore)
        }
    }
}
