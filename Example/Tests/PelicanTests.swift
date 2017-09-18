//
//  PelicanTests.swift
//  Pelican
//
//  Created by Robert Manson on 4/5/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import Pelican

fileprivate class TaskCollector {
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

fileprivate protocol DuneCharacter: PelicanGroupable {
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

fileprivate struct HouseAtreides: PelicanBatchableTask, DuneCharacter {
    let name: String
    let timeStamp: Date

    init(name: String, birthdate: Date) {
        self.timeStamp = birthdate
        self.name = name
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: HouseAtreides.self)

    init?(dictionary: [String : Any]) {
        guard let timeStamp = dictionary["timeStamp"] as? Date,
            let name = dictionary["name"] as? String else {
                fatalError()
        }
        self.timeStamp = timeStamp
        self.name = name
    }

    var dictionary: [String : Any] {
        return [
            "timeStamp": timeStamp,
            "name": name
        ]
    }
}

fileprivate struct HouseHarkonnen: PelicanBatchableTask, DuneCharacter {
    let name: String
    let weapon: String

    init(name: String, weapon: String) {
        self.name = name
        self.weapon = weapon
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: HouseHarkonnen.self)

    init?(dictionary: [String : Any]) {
        guard let weapon = dictionary["weapon"] as? String,
            let name = dictionary["name"] as? String else {
                fatalError()
        }
        self.weapon = weapon
        self.name = name
    }

    var dictionary: [String : Any] {
        return [
            "weapon": weapon,
            "name": name
        ]
    }
}

/// Test the example code in the ReadMe

class PelicanTests: XCTestCase {
    func testExample() {
        let letosDate: Date = Date.distantFuture
        let paulsDate: Date = Date.distantFuture.addingTimeInterval(-6000)
        let storage = InMemoryStorage()

        // Start by registering and immediately adding 2 tasks
        TaskCollector.shared.collected = []
        Pelican.register(tasks: [HouseAtreides.self, HouseHarkonnen.self], storage: storage)
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
        XCTAssert(Pelican.shared.containersByGroup.keys.count == 0)

        // Add two more tasks and simulate backgrounding
        Pelican.shared.gulp(task: HouseAtreides(name: "Paul Atreides", birthdate: paulsDate))
        Pelican.shared.gulp(task: HouseHarkonnen(name: "Baron Vladimir Harkonnen", weapon: "cunning"))

        Pelican.shared.didEnterBackground()
        XCTAssert(storage.store?["Dune Character Group"]?.count == 2)

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
            XCTAssert(taskCount == 2, "Task count is \(taskCount)")

            let paul = TaskCollector.shared.collected[0].houseAtreides!
            XCTAssert(paul.name == "Paul Atreides")
            XCTAssert(paul.timeStamp == paulsDate)

            let baron = TaskCollector.shared.collected[1].houseHarkonnen!
            XCTAssert(baron.name == "Baron Vladimir Harkonnen")
            XCTAssert(baron.weapon == "cunning")
            moreTasksGulped.fulfill()
        }

        waitForExpectations(timeout: 7.0, handler: nil)

        Pelican.shared.didEnterBackground()
        XCTAssert(storage.store == nil)
    }

    func testArchiveGroupsDoesNotSaveTaskGroupsToStorageWhenNoGroups() {
        let storage = InMemoryStorage()
        // This is done to test that we are calling deleteAll (which sets the storage to nil) properly
        storage.store = [:]
        let pelican = Pelican(typeToTask: [:], storage: storage)

        pelican.archiveGroups()

        // This should be nil, since we shouldn't call overwriteGroups
        XCTAssertNil(storage.store)
    }

    func testArchiveGroupsSavesTasksToStorage() {
        let storage = InMemoryStorage()
        let typeToTask: [String: PelicanBatchableTask.Type] = [ HouseAtreides.taskType: HouseAtreides.self,
                                                                HouseHarkonnen.taskType: HouseHarkonnen.self ]
        let pelican = Pelican(typeToTask: typeToTask, storage: storage)

        pelican.gulp(task: HouseAtreides(name: "Duke Leto", birthdate: .distantPast))
        pelican.gulp(task: HouseHarkonnen(name: "Glossu Rabban", weapon: "brutishness"))

        pelican.archiveGroups()

        // This should be set to 1 because both tasks are a part of the "Dune Character Group"
        XCTAssertEqual(storage.store?.count, 1)
        if let duneCharacterGroup = storage.store?["Dune Character Group"] {
            guard duneCharacterGroup.count == 2 else {
                XCTFail("Storage does not contain correct number of tasks for \"Dune Character Group\"")
                return
            }

            if let taskOne = duneCharacterGroup[0]["task"] as? [String: Any] {
                XCTAssertEqual(taskOne["name"] as? String, "Duke Leto")
                XCTAssertEqual(taskOne["timeStamp"] as? Date, .distantPast)
            } else {
                XCTFail("Missing task dictionary for first task")
            }

            if let taskTwo = duneCharacterGroup[1]["task"] as? [String: Any] {
                XCTAssertEqual(taskTwo["name"] as? String, "Glossu Rabban")
                XCTAssertEqual(taskTwo["weapon"] as? String, "brutishness")
            } else {
                XCTFail("Missing task dictionary for second task")
            }
        } else {
            XCTFail("Storage does not contain correct group")
        }
    }

    func testUnarchiveGroupsReturnsUnarchivedTasks() {
        let storage = InMemoryStorage()
        let typeToTask: [String: PelicanBatchableTask.Type] = [ HouseAtreides.taskType: HouseAtreides.self ]

        let serializedTask: [String: Any] = [ "id": "foo",
                                              "task": [ "name": "Duke Leto", "timeStamp": Date.distantPast],
                                              "taskType": HouseAtreides.taskType ]
        storage.store = [ "Dune Character Group": [ serializedTask ] ]

        let pelican = Pelican(typeToTask: typeToTask, storage: storage)

        pelican.unarchiveGroups()

        XCTAssertEqual(pelican.containersByGroup.count, 1)
        if let duneCharacterGroup = pelican.containersByGroup["Dune Character Group"] {
            guard duneCharacterGroup.count == 1 else {
                XCTFail("Storage does not contain correct number of tasks for \"Dune Character Group\"")
                return
            }

            let taskContainer = duneCharacterGroup[0]
            XCTAssertEqual(taskContainer.identifier, "foo")
            XCTAssertEqual(taskContainer.containerDictionary["taskType"] as? String, HouseAtreides.taskType)
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
