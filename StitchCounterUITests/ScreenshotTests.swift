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
        let firstProject = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Bufanda")
        ).firstMatch
        XCTAssertTrue(firstProject.waitForExistence(timeout: 10), "no apareció el primer proyecto")
        firstProject.tap()

        // El número lleva accessibilityLabel "Vueltas: 47", no "47" a secas.
        let counter = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "47")
        ).firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 10), "no se abrió el contador")
        capture(named: "02-contador")

        // Sumar una vuelta deja visible el botón de deshacer.
        app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Sumar")
        ).firstMatch.tap()
        capture(named: "03-deshacer")
    }

    private func capture(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
