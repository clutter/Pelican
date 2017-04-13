//
//  TaskContainerTests.swift
//  Pelican
//
//  Created by Robert Manson on 4/7/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import Pelican

protocol TestGroup: PelicanGroupable {
    var name: String { get }
}

extension TestGroup {
    var group: String {
        return "Test Group"
    }

    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void)) {
        // NOOP
        didComplete(.done)
    }
}

struct TestTask: PelicanBatchableTask, TestGroup {
    let name = "Test Task"

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: TestTask.self)

    init() { }
    init?(dictionary: [String : Any]) { }

    var dictionary: [String : Any] {
        return [: ]
    }
}

class TaskContainerTests: XCTestCase {
    func testEquatableAndInit() {
        let container = Pelican.TaskContainer(task: TestTask())
        let container2 = Pelican.TaskContainer(task: TestTask())
        let typeToTask = [TestTask.taskType: TestTask.self]
        let container3 = Pelican.TaskContainer(containerDictionary: container.containerDictionary,
                                               typeToTask: typeToTask)

        XCTAssert(container != container2)
        XCTAssert(container == container3)
    }
}
