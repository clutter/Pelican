//
//  GroupedTasks.swift
//  Pelican
//
//  Created by Erik Strottmann on 7/23/18.
//

import Foundation

final class GroupedTasks {
    private var containersByGroup: [String: [Pelican.TaskContainer]]

    private let queue = DispatchQueue(label: "com.clutter.Pelican.GroupedTask.queue", qos: .utility)

    init() {
        containersByGroup = [:]
    }

    // MARK: Inserting

    func insert(_ task: Pelican.TaskContainer, forGroup group: String) {
        queue.async {
            self.containersByGroup[group, default: []].append(task)
        }
    }

    func merge(_ taskGroups: [GroupAndContainers]) {
        queue.sync {
            for (group, tasks) in taskGroups {
                let existingTasks = containersByGroup[group] ?? []
                let uniqueTasks = tasks.filter({ !existingTasks.contains($0) })
                containersByGroup[group, default: []].append(contentsOf: uniqueTasks)
            }
        }
    }

    // MARK: Removing

    func remove(_ tasks: [Pelican.TaskContainer], forGroup group: String) {
        queue.sync {
            let filteredTasks = self.containersByGroup[group, default: []].filter { !tasks.contains($0) }

            if filteredTasks.isEmpty {
                self.containersByGroup.removeValue(forKey: group)
            } else {
                self.containersByGroup[group] = filteredTasks
            }
        }
    }

    func removeAllTasks(forGroup group: String) {
        queue.sync {
            _ = containersByGroup.removeValue(forKey: group)
        }
    }

    func removeAllTasks() {
        queue.sync {
            containersByGroup.removeAll()
        }
    }

    // MARK: Accessing

    typealias GroupAndContainers = (String, [Pelican.TaskContainer])

    func allTasks() -> [GroupAndContainers] {
        return queue.sync {
            return Array(containersByGroup)
        }
    }

    func chunkedTasks(by chunkSize: Int) -> [GroupAndContainers] {
        return queue.sync {
            return containersByGroup.chunked(by: chunkSize)
        }
    }
}

private extension Dictionary where Value: RandomAccessCollection, Value.Index == Int {
    func chunked(by chunkSize: Int) -> [(Key, [Value.Element])] {
        return flatMap { pair -> [(Key, [Value.Element])] in
            let (key, values) = pair
            let chunks = values.chunked(by: chunkSize)
            return chunks.map({ (key, $0) })
        }
    }
}

private extension RandomAccessCollection where Index == Int {
    func chunked(by chunkSize: Int) -> [[Element]] {
        return stride(from: startIndex, to: count, by: chunkSize).map {
            Array(self[$0 ..< Swift.min($0 + chunkSize, count)])
        }
    }
}
