import XCTest

final class RotationTests: XCTestCase {
    func testRotatingBackAndForthKeepsRowsVisible() throws {
        let app = XCUIApplication()
        app.launch()

        for pass in 1...3 {
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 1.2)
            XCTAssertTrue(
                app.staticTexts["Bufanda de invierno"].exists,
                "pasada \(pass): filas en blanco en apaisado"
            )
            XCTAssertTrue(app.staticTexts["Gorro para Lu"].exists, "pasada \(pass): falta la 2da fila")
            let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            a.name = "R\(pass)-apaisado"; a.lifetime = .keepAlways; add(a)

            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 1.2)
            XCTAssertTrue(
                app.staticTexts["Bufanda de invierno"].exists,
                "pasada \(pass): filas en blanco al volver a vertical"
            )
        }
    }
}
