//
//  GroupedTasksTests.swift
//  Pelican_Tests
//
//  Created by Erik Strottmann on 7/25/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import XCTest
@testable import Pelican

final class GroupedTasksTests: XCTestCase {
    private var groupedTasks: GroupedTasks!
    private var queue: DispatchQueue!
    private let iterationCount = 100

    override func setUp() {
        super.setUp()

        groupedTasks = GroupedTasks()
        queue = DispatchQueue(label: "com.clutter.Pelican.GroupedTaskTests.queue", attributes: .concurrent)
    }
    
    override func tearDown() {
        queue = nil
        groupedTasks = nil

        super.tearDown()
    }
    
    func testInsertingConcurrently() {
        let expectation = self.expectation(description: "GroupedTasks should allow inserting tasks concurrently")
        expectation.expectedFulfillmentCount = iterationCount

        for _ in 1...iterationCount {
            queue.async {
                let task = DummyTask()
                let container = Pelican.TaskContainer(task: task)
                self.groupedTasks.insert(container, forGroup: task.group)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 0.1)

        let allTasks = groupedTasks.allTasks()
        XCTAssertEqual(allTasks.count, 1)
        let (_, containers) = allTasks[0]
        XCTAssertEqual(containers.count, iterationCount, "GroupedTasks should allow all tasks to be inserted")
    }

    func testInsertingDuplicates() {
        let task = DummyTask()
        let container = Pelican.TaskContainer(task: task)

        groupedTasks.insert(container, forGroup: task.group)
        groupedTasks.insert(container, forGroup: task.group)
        groupedTasks.insert(container, forGroup: task.group)

        let allTasks = groupedTasks.allTasks()
        XCTAssertEqual(allTasks.count, 1)
        let (_, containers) = allTasks[0]
        XCTAssertEqual(containers.count, 3, "GroupedTask should allow inserting duplicates of the same task container")
    }

    func testMergingConcurrently() {
        testInsertingConcurrently()

        let taskGroups: [GroupedTasks.GroupAndContainers] = (1...iterationCount).map { _ in
            let task = DummyTask()
            let container = Pelican.TaskContainer(task: task)
            return (task.group, [container])
        }

        let expectation = self.expectation(description: "GroupedTasks should allow merging tasks concurrently")
        expectation.expectedFulfillmentCount = iterationCount

        for taskGroup in taskGroups {
            queue.async {
                self.groupedTasks.merge([taskGroup])
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 0.1)
    }

    func testMergingDuplicates() {
        let someContainers: [Pelican.TaskContainer] = (1...2).map { _ in
            let task = DummyTask()
            return Pelican.TaskContainer(task: task)
        }
        let groupName = someContainers[0].task.group
        let someGroups = [(groupName, someContainers)]

        groupedTasks.merge(someGroups)

        var allTasks = groupedTasks.allTasks()
        XCTAssertEqual(allTasks.count, 1)
        var (_, containers) = allTasks[0]
        XCTAssertEqual(containers.count, 2, "GroupedTask should allow merging tasks")

        groupedTasks.merge(someGroups) // again

        allTasks = groupedTasks.allTasks()
        XCTAssertEqual(allTasks.count, 1)
        (_, containers) = allTasks[0]
        XCTAssertEqual(containers.count, 2, "GroupedTask should not merge duplicate tasks")

        let otherContainers: [Pelican.TaskContainer] = (1...2).map { _ in
            let task = DummyTask()
            return Pelican.TaskContainer(task: task)
        }
        let otherGroups = [(groupName, otherContainers)]

        groupedTasks.merge(otherGroups)

        allTasks = groupedTasks.allTasks()
        XCTAssertEqual(allTasks.count, 1)
        (_, containers) = allTasks[0]
        XCTAssertEqual(containers.count, 4, "GroupedTask should merge unique tasks")

    }

    func testRemovingConcurrently() {
        testInsertingConcurrently()
        let allTasks = groupedTasks.allTasks()
        let (_, containers) = allTasks[0]

        let expectation = self.expectation(description: "GroupedTasks should allow removing tasks concurrently")
        expectation.expectedFulfillmentCount = iterationCount

        for container in containers {
            queue.async {
                self.groupedTasks.remove([container], forGroup: container.task.group)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 0.1)
    }

    func testRemovingAllTasks() {
        let someContainers: [Pelican.TaskContainer] = (1...2).map { _ in
            let task = DummyTask()
            return Pelican.TaskContainer(task: task)
        }
        let groupName = someContainers[0].task.group
        let someGroups = [(groupName, someContainers)]

        groupedTasks.merge(someGroups)

        var allTasks = groupedTasks.allTasks()
        XCTAssertEqual(allTasks.count, 1)
        let (_, containers) = allTasks[0]
        XCTAssertEqual(containers.count, 2, "GroupedTask should allow merging tasks")

        groupedTasks.removeAllTasks(forGroup: groupName)

        allTasks = groupedTasks.allTasks()
        XCTAssertEqual(allTasks.count, 0, "GroupedTask should allow removing all tasks")
    }

    func testChunkingTasks() {
        let someContainers: [Pelican.TaskContainer] = (1...10).map { _ in
            let task = DummyTask()
            return Pelican.TaskContainer(task: task)
        }
        let groupName = someContainers[0].task.group
        let someGroups = [(groupName, someContainers)]

        groupedTasks.merge(someGroups)

        let chunkedTasks = groupedTasks.chunkedTasks(by: 4)
        XCTAssertEqual(chunkedTasks.count, 3)

        let (groupName0, containers0) = chunkedTasks[0]
        XCTAssertEqual(containers0.count, 4, "The first chunk should have 4 task containers")

        let (groupName1, containers1) = chunkedTasks[1]
        XCTAssertEqual(containers1.count, 4, "The second chunk should have 4 task containers")
        XCTAssertEqual(groupName1, groupName0)

        let (groupName2, containers2) = chunkedTasks[2]
        XCTAssertEqual(containers2.count, 2, "The third chunk should have 2 task containers")
        XCTAssertEqual(groupName2, groupName0)
    }
}

private struct DummyTask: PelicanGroupable, PelicanBatchableTask {
    init() {}

    var group: String { return "DummyTask group" }

    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void)) {}

    static var taskType: String { return String(describing: DummyTask.self) }

    init?(dictionary: [String: Any]) {}
    var dictionary: [String: Any] { return [:] }
}
