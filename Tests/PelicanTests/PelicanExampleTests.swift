//
//  PelicanExampleTests.swift
//  Pelican
//
//  Test the example code in the Readme
//
//  Created by Robert Manson on 4/3/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import XCTest
import Pelican

class API {
    static var shared = API()
    var collected = [String]()
    func postEvents(json: Data, done: (Error?) -> Void) {
        let stringValue = String(bytes: json, encoding: .utf8) ?? ""
        collected.append(stringValue)
        done(nil)
    }
}

protocol AppEvents: PelicanGroupable {
    var eventName: String { get }
    var timeStamp: Date { get }
}

// Batch all app events together into the same group
extension AppEvents {
    // Used to group events so they can batched
    var group: String {
        return "Example App Events"
    }

    /// Pelican will call `processGroup` on a background thread. You should implement it to do whatever processing is 
    /// relevant to your application. Below is a sample implementation that sends application events to as a batch.
    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void)) {
        // Construct JSON to pass to your API.
        guard let tasks = tasks as? [LogInEvent] else { didComplete(PelicanProcessResult.done); return }
        let postData = Data(tasks.map({ $0.userName }).joined(separator: "\n").utf8)
        API.shared.postEvents(json: postData) { error in
            if error == nil {
                didComplete(PelicanProcessResult.done)
            } else {
                // Retry will call process group again until succesful
                didComplete(PelicanProcessResult.retry(delay: 0))
            }
        }
    }
}

struct LogInEvent: PelicanBatchableTask, AppEvents {
    var eventName: String { "Log In" }
    let timeStamp: Date
    let userName: String

    init(userName: String) {
        self.timeStamp = Date()
        self.userName = userName
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: LogInEvent.self)
}

// Other app events omitted for brevity but by implementing our "AppEvents" protocol, they 
// can all be batched together to a single endpoint

class PelicanExampleTests: XCTestCase {
    func testReadMe() {
        let storage = InMemoryStorage()
        API.shared.collected = []

        var tasks = Pelican.RegisteredTasks()
        tasks.register(for: LogInEvent.self)

        Pelican.initialize(tasks: tasks, storage: storage)

        Pelican.shared.gulp(task: LogInEvent(userName: "Ender Wiggin"))
        Pelican.shared.gulp(task: LogInEvent(userName: "Mazer Rackham"))
        let tasksGulped = expectation(description: "Tasks Gulped and Processed")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(6)) {
            tasksGulped.fulfill()
        }

        waitForExpectations(timeout: 7.0) { _ in
            let expected = """
                Ender Wiggin
                Mazer Rackham
                """
            XCTAssertEqual(API.shared.collected.first, expected)
        }
    }
}
