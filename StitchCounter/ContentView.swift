import SwiftUI

struct ContentView: View {
    @StateObject private var projectStore = ProjectStore()

    var body: some View {
        ProjectListView()
            .environmentObject(projectStore)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
