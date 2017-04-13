import UIKit
import XCTest
import Pelican

class UserDefaultsStorageTests: XCTestCase {
    func testStorage() {
        let storage = PelicanUserDefaultsStorage()
        storage.deleteAll()

        XCTAssert(storage.loadTaskGroups() == nil)

        let storeMe: PelicanStorage.Serialized = [
            "groupA": [
                ["key": "value"]
            ],
            "groupB": [
                ["key": "value"]
            ]
        ]
        storage.overwrite(taskGroups: storeMe)

        let tasks = storage.loadTaskGroups()
        XCTAssert(tasks?.keys.count == 2)

        storage.deleteAll()
        XCTAssert(storage.loadTaskGroups() == nil)
    }
}
