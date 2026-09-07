import SwiftUI

struct ContentView: View {
    @StateObject private var projectStore = ProjectStore()

    var body: some View {
        ProjectListView()
            .environmentObject(projectStore)
            // La paleta de la app es una sola y clara: fondos crema, texto
            // marrón. Sin declararlo, en un teléfono en modo oscuro el sistema
            // dibuja su parte —títulos de barra, alertas, teclado, cursor— con
            // los colores oscuros, y queda texto claro sobre fondo claro.
            .preferredColorScheme(.light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
