//
//  TaskContainer.swift
//  Pelican
//
//  Created by Robert Manson on 3/14/19.
//

import Foundation

enum TaskContainerError: Error {
    case missingDecoder
    case missingEncoder
}

class TaskContainer: Codable {
    let identifier: String
    let taskType: String
    let task: PelicanBatchableTask

    typealias TaskDecoder = (KeyedDecodingContainer<CodingKeys>) throws -> PelicanBatchableTask
    typealias TaskEncoder = (PelicanBatchableTask, inout KeyedEncodingContainer<CodingKeys>) throws -> Void

    static var decoders: [String: TaskDecoder] = [:]
    static var encoders: [String: TaskEncoder] = [:]

    static func register<T: PelicanBatchableTask>(for type: T.Type) {
        encoders[T.taskType] = { task, container in
            //swiftlint:disable:next force_cast
            try container.encode(task as! T, forKey: CodingKeys.task)
        }
        decoders[T.taskType] = { container in
            let task = try container.decode(T.self, forKey: .task)
            return task
        }
    }

    init(task: PelicanBatchableTask) {
        identifier = UUID().uuidString
        taskType = task.taskType
        self.task = task
    }

    enum CodingKeys: String, CodingKey {
        case identifier
        case taskType
        case task
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        taskType = try container.decode(String.self, forKey: .taskType)
        identifier = try container.decode(String.self, forKey: .identifier)

        guard let taskDecoder = TaskContainer.decoders[taskType] else {
            throw TaskContainerError.missingDecoder
        }

        task = try taskDecoder(container)
    }

    func encode(to encoder: Encoder) throws {
        guard let taskEncoder = TaskContainer.encoders[taskType] else {
            throw TaskContainerError.missingEncoder
        }

        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(taskType, forKey: .taskType)
        try container.encode(identifier, forKey: .identifier)
        try taskEncoder(task, &container)
    }
}

extension TaskContainer: Equatable {
    static func == (lhs: TaskContainer, rhs: TaskContainer) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
