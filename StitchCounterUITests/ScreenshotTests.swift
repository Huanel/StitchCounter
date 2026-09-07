import XCTest

/// Genera las capturas para la ficha del App Store.
///
/// No verifica comportamiento: navega a cada pantalla y adjunta la imagen al
/// resultado. Se corre a mano cuando hay que renovar las capturas, con datos de
/// ejemplo ya sembrados en el simulador.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCaptureScreens() throws {
        let app = XCUIApplication()
        app.launch()

        capture(named: "01-lista")

        // La primera fila del listado; el nombre viene de los datos sembrados.
        let firstProject = app.staticTexts["Bufanda de invierno"]
        XCTAssertTrue(firstProject.waitForExistence(timeout: 10), "no apareció el primer proyecto")
        firstProject.tap()

        // Se confirma con un control que solo existe dentro del contador: el
        // listado también muestra "47", así que buscarlo no probaría nada.
        let plus = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Sumar")
        ).firstMatch
        XCTAssertTrue(plus.waitForExistence(timeout: 10), "no se abrió el contador")
        capture(named: "02-contador")

        // Sumar una vuelta deja visible el botón de deshacer.
        plus.tap()
        capture(named: "03-deshacer")

        // Apaisado: los dos contadores tienen que quedar lado a lado y enteros.
        XCUIDevice.shared.orientation = .landscapeLeft
        let bothVisible = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Sumar")
        )
        XCTAssertTrue(
            bothVisible.element(boundBy: 1).waitForExistence(timeout: 10),
            "en apaisado no se ven los dos contadores"
        )
        capture(named: "04-apaisado")
        XCUIDevice.shared.orientation = .portrait
    }

    private func capture(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
