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

struct TestTask: PelicanBatchableTask, TestGroup, Equatable {
    let name: String
    let taskData: String

    init() {
        self.name = "Test Task"
        self.taskData = "Task Data"
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: TestTask.self)
}

class TaskContainerEqualityTests: XCTestCase {
    func testEquatable() {
        let container = TaskContainer(task: TestTask())
        let container2 = TaskContainer(task: TestTask())

        XCTAssert(container != container2)
        XCTAssert(container == container)
    }
}

class TaskContainerEncodeDecodeTests: XCTestCase {
    override func setUp() {
        TaskContainer.register(for: TestTask.self)
    }

    func testRoundCodableTrip() throws {
        let container = TaskContainer(task: TestTask())

        let data = try JSONEncoder().encode(container)
        let decodedContainer = try JSONDecoder().decode(TaskContainer.self, from: data)

        guard let task = container.task as? TestTask, let decodedTask = decodedContainer.task as? TestTask else {
            XCTFail("Task is in wrong format")
            return
        }

        XCTAssertEqual(task, decodedTask)
        XCTAssertEqual(container.identifier, decodedContainer.identifier)
        XCTAssertEqual(container.taskType, container.taskType)
    }
}
