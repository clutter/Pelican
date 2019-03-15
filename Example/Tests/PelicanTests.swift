//
//  PelicanTests.swift
//  Pelican
//
//  Created by Robert Manson on 4/5/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import Pelican

private class TaskCollector {
    enum Task {
        case taskA(value: HouseAtreides)
        case taskB(value: HouseHarkonnen)

        var name: String {
            switch self {
            case .taskA(let value):
                return value.name
            case .taskB(let value):
                return value.name
            }
        }

        var houseAtreides: HouseAtreides? {
            switch self {
            case .taskA(let value): return value
            default: return nil
            }
        }

        var houseHarkonnen: HouseHarkonnen? {
            switch self {
            case .taskB(let value): return value
            default: return nil
            }
        }
    }

    static var shared = TaskCollector()
    var collected = [Task]()
    func collect(tasks: [PelicanBatchableTask]) {
        for task in tasks {
            if let task = task as? HouseAtreides {
                collected.append(.taskA(value: task))
            } else if let task = task as? HouseHarkonnen {
                collected.append(.taskB(value: task))
            } else {
                fatalError()
            }
        }
    }
}

private protocol DuneCharacter: PelicanGroupable {
    var name: String { get }
}

extension DuneCharacter where Self: PelicanBatchableTask {
    var group: String {
        return "Dune Character Group"
    }

    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void)) {
        TaskCollector.shared.collect(tasks: tasks)
        didComplete(PelicanProcessResult.done)
    }
}

private struct HouseAtreides: PelicanBatchableTask, DuneCharacter {
    let name: String
    let timeStamp: Date

    init(name: String, birthdate: Date) {
        self.timeStamp = birthdate
        self.name = name
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: HouseAtreides.self)
}

private struct HouseHarkonnen: PelicanBatchableTask, DuneCharacter {
    let name: String
    let weapon: String

    init(name: String, weapon: String) {
        self.name = name
        self.weapon = weapon
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: HouseHarkonnen.self)
}

/// Test the example code in the ReadMe

class PelicanSavingAndRecoveringFromAppState: XCTestCase {
    let letosDate: Date = Date.distantFuture
    let paulsDate: Date = Date.distantFuture.addingTimeInterval(-6000)
    var storage: InMemoryStorage!

    override func setUp() {
        storage = InMemoryStorage()

        // Start by registering and immediately adding 2 tasks
        TaskCollector.shared.collected = []

        var tasks = Pelican.RegisteredTasks()
        tasks.register(for: HouseAtreides.self)
        tasks.register(for: HouseHarkonnen.self)
        Pelican.initialize(tasks: tasks, storage: storage)
    }

    override func tearDown() {
        Pelican.shared.stop()
        storage = nil
    }

    func testSavesWhenBackgroundedRecoversWhenForegrounded() {
        Pelican.shared.gulp(task: HouseAtreides(name: "Duke Leto", birthdate: letosDate))
        Pelican.shared.gulp(task: HouseHarkonnen(name: "Glossu Rabban", weapon: "brutishness"))

        let tasksGulped = expectation(description: "Tasks Gulped and Processed")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(6)) {
            let taskCount = TaskCollector.shared.collected.count
            XCTAssert(taskCount == 2, "Task count is \(taskCount)")
            XCTAssert(TaskCollector.shared.collected[0].name == "Duke Leto",
                      "Task is \(TaskCollector.shared.collected[0].name)")
            XCTAssert(TaskCollector.shared.collected[1].name == "Glossu Rabban",
                      "Task is \(TaskCollector.shared.collected[1].name)")
            tasksGulped.fulfill()
        }

        waitForExpectations(timeout: 7.0, handler: nil)

        XCTAssert(storage.store == nil)
        TaskCollector.shared.collected = []
        XCTAssertTrue(Pelican.shared.groupedTasks.allTasks().isEmpty)

        // Add two more tasks and simulate backgrounding
        Pelican.shared.gulp(task: HouseAtreides(name: "Paul Atreides", birthdate: paulsDate))
        Pelican.shared.gulp(task: HouseHarkonnen(name: "Baron Vladimir Harkonnen", weapon: "cunning"))

        Pelican.shared.didEnterBackground()
        XCTAssert(storage["Dune Character Group"].count == 2)

        Pelican.shared.willEnterForeground()

        let storageLoaded = expectation(description: "Wait for storage to load")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(1)) {
            storageLoaded.fulfill()
        }
        waitForExpectations(timeout: 2.0, handler: nil)

        XCTAssert(storage.store == nil)

        let moreTasksGulped = expectation(description: "More Tasks Gulped and Processed")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(6)) {
            let taskCount = TaskCollector.shared.collected.count
            XCTAssertEqual(taskCount, 2)

            let paul = TaskCollector.shared.collected[0].houseAtreides
            XCTAssertEqual(paul?.name, "Paul Atreides")
            XCTAssertEqual(paul?.timeStamp, self.paulsDate)

            let baron = TaskCollector.shared.collected[1].houseHarkonnen
            XCTAssertEqual(baron?.name, "Baron Vladimir Harkonnen")
            XCTAssertEqual(baron?.weapon, "cunning")
            moreTasksGulped.fulfill()
        }

        waitForExpectations(timeout: 7.0, handler: nil)

        Pelican.shared.didEnterBackground()
        XCTAssert(storage.store == nil)
    }
}

class PelicanStoresOnGulpTests: XCTestCase {
    var storage: InMemoryStorage!
    var pelican: Pelican!

    override func setUp() {
        storage = InMemoryStorage()

        var tasks = Pelican.RegisteredTasks()
        tasks.register(for: HouseAtreides.self)
        tasks.register(for: HouseHarkonnen.self)

        pelican = Pelican(tasks: tasks, storage: storage)
    }

    override func tearDown() {
        pelican.stop()
        pelican = nil
        storage = nil
    }

    func testArchiveWithNoTasksSucceeds() {
        pelican.archiveGroups()
        // This should be nil, since we didn't gulp anything
        XCTAssertNil(storage.store)
    }

    func testArchiveGroupsSavesTasksToStorage() {
        pelican.gulp(task: HouseAtreides(name: "Duke Leto", birthdate: .distantPast))
        pelican.gulp(task: HouseHarkonnen(name: "Glossu Rabban", weapon: "brutishness"))

        pelican.archiveGroups()

        let duneCharacterGroup = storage["Dune Character Group"]
        guard duneCharacterGroup.count == 2 else {
            XCTFail("Storage does not contain correct number of tasks for \"Dune Character Group\"")
            return
        }

        if let taskOne = duneCharacterGroup[0].task as? HouseAtreides {
            XCTAssertEqual(taskOne.name, "Duke Leto")
            XCTAssertEqual(taskOne.timeStamp, .distantPast)
        } else {
            XCTFail("Expecting first task to be HouseAtreides")
        }

        if let taskTwo = duneCharacterGroup[1].task as? HouseHarkonnen {
            XCTAssertEqual(taskTwo.name, "Glossu Rabban")
            XCTAssertEqual(taskTwo.weapon, "brutishness")
        } else {
            XCTFail("Expecting second task to be HouseHarkonnen")
        }
    }
}

class PelicanLoadsFromStorageTests: XCTestCase {
    var storage: InMemoryStorage!
    var pelican: Pelican!

    override func setUp() {
        storage = InMemoryStorage()

        var tasks = Pelican.RegisteredTasks()
        tasks.register(for: HouseAtreides.self)
        tasks.register(for: HouseHarkonnen.self)

        pelican = Pelican(tasks: tasks, storage: storage)
    }

    override func tearDown() {
        pelican.stop()
        pelican = nil
        storage = nil
    }

    func testUnarchiveGroupsLoadsNoTaskGroupsFromEmptyStorage() {
        pelican.unarchiveGroups()

        XCTAssertTrue(pelican.groupedTasks.allTasks().isEmpty)
        XCTAssertNil(storage.store)
    }

    func testUnarchiveGroupsLoadsArchivedTasksFromStorage() {
        let task = TaskContainer(task: HouseAtreides(name: "Duke Leto", birthdate: Date.distantPast))

        storage["Dune Character Group"] = [ task ]

        pelican.unarchiveGroups()

        let allGroups = pelican.groupedTasks.allTasks()
        XCTAssertEqual(allGroups.count, 1)
        if let duneCharacterGroup = allGroups.first(where: { $0.group == "Dune Character Group" }) {
            guard duneCharacterGroup.containers.count == 1 else {
                XCTFail("Storage does not contain correct number of tasks for \"Dune Character Group\"")
                return
            }

            let taskContainer = duneCharacterGroup.containers[0]
            XCTAssertEqual(taskContainer.identifier, task.identifier)
            XCTAssertEqual(taskContainer.taskType, HouseAtreides.taskType)
            if let task = taskContainer.task as? HouseAtreides {
                XCTAssertEqual(task.name, "Duke Leto")
                XCTAssertEqual(task.timeStamp, Date.distantPast)
            } else {
                XCTFail("Task is not correct type (expected \(HouseAtreides.self), got \(type(of: taskContainer.task))")
            }
        } else {
            XCTFail("Storage does not contain correct group")
        }
    }
}

extension InMemoryStorage {
    subscript(groupName: String) -> [TaskContainer] {
        get {
            guard let data = store,
                let taskGroups = try? JSONDecoder().decode([GroupedTasks.GroupAndContainers].self, from: data) else {
                    return []
            }

            return taskGroups.first(where: { $0.group == groupName })?.containers ?? []
        }

        set {
            guard !newValue.isEmpty else {
                store = nil
                return
            }

            let group = GroupedTasks.GroupAndContainers(group: groupName, containers: newValue)
            store = try? JSONEncoder().encode([group])
        }
    }
}
