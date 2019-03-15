//
//  RetryTaskTests.swift
//  Pelican
//
//  Created by Robert Manson on 4/25/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
@testable import Pelican

private class TaskCollector {
    static var shared = TaskCollector()
    var collected = [RetryTask]()

    var retryCount = 0
    func collect(tasks: [PelicanBatchableTask]) {
        for task in tasks {
            if let task = task as? RetryTask {
                collected.append(task)
            } else {
                fatalError()
            }
        }
    }
}

protocol RetryGroup: PelicanGroupable {
    var name: String { get }
}

extension RetryGroup where Self: PelicanBatchableTask {
    var group: String {
        return "Retry Group"
    }

    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void)) {
        guard TaskCollector.shared.retryCount >= 3 else {
            TaskCollector.shared.retryCount += 1
            didComplete(.retry(delay: 0))
            return
        }

        TaskCollector.shared.collect(tasks: tasks)
        didComplete(PelicanProcessResult.done)
    }
}

private struct RetryTask: PelicanBatchableTask, RetryGroup {
    let name: String

    init(name: String) {
        self.name = name
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: RetryTask.self)
}

class RetryTaskTests: XCTestCase {
    override func setUp() {
        var tasks = Pelican.RegisteredTasks()
        tasks.register(for: RetryTask.self)

        TaskCollector.shared.collected = []

        let storage = InMemoryStorage()
        Pelican.initialize(tasks: tasks, storage: storage)
    }

    override func tearDown() {
        Pelican.shared.stop()
    }

    // Test retrying behavior to make sure tasks are properly retried after processGroup signals that is correct
    // behavior
    func testRetryBehavior() {
        Pelican.shared.gulp(task: RetryTask(name: "Task A"))
        Pelican.shared.gulp(task: RetryTask(name: "Task B"))

        let tasksGulped = expectation(description: "Retryable Tasks Gulped and Processed")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(6)) {
            let taskCount = TaskCollector.shared.collected.count
            XCTAssert(taskCount == 2, "Task count is \(taskCount)")
            XCTAssert(TaskCollector.shared.collected[0].name == "Task A",
                      "Task is \(TaskCollector.shared.collected[0].name)")
            XCTAssert(TaskCollector.shared.collected[1].name == "Task B",
                      "Task is \(TaskCollector.shared.collected[1].name)")
            XCTAssert(TaskCollector.shared.retryCount == 3)
            tasksGulped.fulfill()
        }

        waitForExpectations(timeout: 7.0, handler: nil)
    }
}
