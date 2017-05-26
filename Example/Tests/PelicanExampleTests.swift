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
    var collected = [Any]()
    func postEvents(json: [Any], done: (Error?) -> Void) {
        collected.append(contentsOf: json)
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
        // In this case, we'll create JSON from tasks and send it to our API.
        let json = tasks.map { $0.dictionary }
        API.shared.postEvents(json: json) { error in
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
    let eventName: String = "Log In"
    let timeStamp: Date
    let userName: String

    init(userName: String) {
        self.timeStamp = Date()
        self.userName = userName
    }

    // PelicanBatchableTask conformance, used to read and store task to storage
    static let taskType: String = String(describing: LogInEvent.self)

    init?(dictionary: [String : Any]) {
        guard let timeStamp = dictionary["timeStamp"] as? Date,
            let userName = dictionary["userName"] as? String else {
                return nil
        }
        self.timeStamp = timeStamp
        self.userName = userName
    }

    var dictionary: [String : Any] {
        return [
            "timeStamp": timeStamp,
            "userName": userName
        ]
    }
}

// Other app events omitted for brevity but by implementing our "AppEvents" protocol, they 
// can all be batched together to a single endpoint

class PelicanExampleTests: XCTestCase {
    func testExample() {
        let storage = InMemoryStorage()
        API.shared.collected = []
        Pelican.register(tasks: [LogInEvent.self], storage: storage)
        Pelican.shared.gulp(task: LogInEvent(userName: "Ender Wiggin"))
        Pelican.shared.gulp(task: LogInEvent(userName: "Mazer Rackham"))
        let tasksGulped = expectation(description: "Tasks Gulped and Processed")
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(6)) {
            tasksGulped.fulfill()
        }

        waitForExpectations(timeout: 7.0) { _ in
            XCTAssert(API.shared.collected.count == 2)
        }
    }
}
