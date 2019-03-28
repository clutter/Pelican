import UIKit
import XCTest
import Pelican

class UserDefaultsStorageTests: XCTestCase {
    func testRoundTripAndDelete() {
        let storage = PelicanUserDefaultsStorage()

        storage.pelicanDeleteAll()
        XCTAssert(storage.pelicanLoadFromStorage() == nil)

        let storeMe = "Test Data"
        let dataToStore = Data(storeMe.utf8)

        storage.pelicanOverwriteStorage(with: dataToStore)

        let dataFromStorage = storage.pelicanLoadFromStorage()
        XCTAssertEqual(dataToStore, dataFromStorage)

        storage.pelicanDeleteAll()
        XCTAssert(storage.pelicanLoadFromStorage() == nil)
    }
}
