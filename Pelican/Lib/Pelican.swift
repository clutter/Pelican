//
//  Pelican.swift
//  Pods
//
//  Created by Robert Manson on 3/29/17.
//
//

import Foundation

public enum PelicanProcessResult {
    case done
    case retry
}

public protocol PelicanGroupable {
    var group: String { get }

    /// Called on a background thread to process a group of collected tasks
    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void))
}

public protocol PelicanBatchableTask: PelicanGroupable {
    static var taskType: String { get }

    init? (dictionary: [String: Any])
    var dictionary: [String: Any] { get }
}

extension PelicanBatchableTask {
    var taskType: String {
        return Self.taskType
    }
}

public class Pelican {
    public static var shared: Pelican!

    public static func register(tasks: [PelicanBatchableTask.Type],
                                storage: PelicanStorage = PelicanUserDefaultsStorage()) {
        var typeToTask: [String: PelicanBatchableTask.Type] = [: ]
        for task in tasks {
            typeToTask[task.taskType] = task
        }

        shared = Pelican(typeToTask: typeToTask, storage: storage)
    }

    public func gulp(task: PelicanBatchableTask) {
        let container = TaskContainer(task: task)

        if containersByGroup[task.group] != nil {
            containersByGroup[task.group]?.append(container)
        } else {
            containersByGroup[task.group] = [container]
        }
    }

    class TaskContainer {
        let identifier: String
        let task: PelicanBatchableTask

        init(task: PelicanBatchableTask) {
            identifier = UUID().uuidString
            self.task = task
        }

        init?(containerDictionary: [String: Any], typeToTask: [String: PelicanBatchableTask.Type]) {
            guard let taskDict = containerDictionary["task"] as? [String: Any],
                let id = containerDictionary["id"] as? String,
                let taskTypeName = containerDictionary["taskType"] as? String,
                let taskType = typeToTask[taskTypeName],
                let task = taskType.init(dictionary: taskDict) else {
                    return nil
            }

            self.task = task
            self.identifier = id
        }

        var containerDictionary: [String: Any] {
            return [
                "id": identifier,
                "task": task.dictionary,
                "taskType": task.taskType
            ]
        }
    }

    // MARK - Intialization

    init(typeToTask: [String: PelicanBatchableTask.Type], storage: PelicanStorage) {
        self.typeToTask = typeToTask
        containersByGroup = [: ]
        self.storage = storage

        start()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(didEnterBackground),
                                       name: .UIApplicationDidEnterBackground,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(willTerminate),
                                       name: .UIApplicationWillTerminate,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(willEnterForeground),
                                       name: .UIApplicationWillEnterForeground,
                                       object: nil)
    }

    deinit {
        stop()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Internal State

    let typeToTask: [String: PelicanBatchableTask.Type]

    typealias GroupedTasks = [String: [TaskContainer]]
    var containersByGroup: GroupedTasks
    let storage: PelicanStorage

    var isRunning = false
    var activeGroup: (group: String, tasks: [TaskContainer])?
    var timer: Timer?

    @objc func didEnterBackground() {
        stop()
    }

    @objc func willEnterForeground() {
        start()
    }

    @objc func willTerminate() {
        stop()
    }

    @objc func timerFired() {
        guard isRunning, activeGroup == nil else { return }

        // Chunk containers into 100 maximum per group

        typealias GroupsArray = [(String, [TaskContainer])]
        let maxChunck = 100
        let containersAndGroups: GroupsArray = containersByGroup.flatMap { (pair: (group: String, containers: [Pelican.TaskContainer])) -> GroupsArray in
            let chunks = stride(from: 0, to: pair.containers.count, by: maxChunck).map {
                Array(pair.containers[$0..<min($0 + maxChunck, pair.containers.count)])
            }
            let pairedChunks: GroupsArray = chunks.map({ (pair.group, $0) })
            return pairedChunks
        }

        DispatchQueue.global(qos: .userInitiated).async {
            for (group, containers) in containersAndGroups {
                self.activeGroup = (group, containers)
                guard let firstContainer = containers.first else { self.containersByGroup.removeValue(forKey: group); continue }
                guard let taskType = self.typeToTask[firstContainer.task.taskType] else { /* TODO: Error handling */ continue }

                var retry = true
                let sema = DispatchSemaphore(value: 0)
                while retry {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let tasks = containers.map({ $0.task })
                        taskType.processGroup(tasks: tasks, didComplete: { (result) in
                            switch result {
                            case .done:
                                let filtered = self.containersByGroup[group]?.filter { elem in
                                    return !containers.contains(where: { elem == $0 })
                                    } ?? []
                                if filtered.count > 0 {
                                    self.containersByGroup[group] = filtered
                                } else {
                                    self.containersByGroup.removeValue(forKey: group)
                                }

                                retry = false
                                self.activeGroup = nil
                            case .retry:
                                break
                            }
                            sema.signal()
                        })
                    }
                    sema.wait()
                }
            }
        }
    }
}

fileprivate extension Pelican {
    // MARK: - Start or stop batch processing

    func start() {
        guard !isRunning else { return }

        DispatchQueue.global(qos: .userInteractive).async {
            self.unarchiveGroups()

            self.isRunning = true
            guard self.timer == nil else { return }
            DispatchQueue.main.async {
                self.timer = Timer.scheduledTimer(timeInterval: 5.0,
                                                  target: self,
                                                  selector: #selector(self.timerFired),
                                                  userInfo: nil,
                                                  repeats: true)
            }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil

        archiveGroups()
    }

    // MARK: - Serialization Helpers

    func unarchiveGroups() {
        let serializedGroups = storage.loadTaskGroups() ?? [: ]
        for (groupKey, values) in fromDictionary(serialized: serializedGroups) {
            if containersByGroup[groupKey] != nil {
                // Handle case where containersByGroup didn't go out of memory, so we don't want to insert duplicates
                let existingValues = containersByGroup[groupKey] ?? []
                let uniqueValues = values.filter({ val in return !existingValues.contains(where: { val == $0 }) })
                containersByGroup[groupKey]?.append(contentsOf: uniqueValues)
            } else {
                containersByGroup[groupKey] = values
            }
        }
        storage.deleteAll()
    }

    func archiveGroups() {
        if containersByGroup.count > 0 {
            storage.overwrite(taskGroups: toDictionary(taskGroups: containersByGroup))
        } else {
            storage.deleteAll()
        }
    }

    func toDictionary(taskGroups: Pelican.GroupedTasks) -> PelicanStorage.Serialized {
        var dict: PelicanStorage.Serialized = [: ]
        for (group, containers) in taskGroups {
            let serialized: [[String: Any]] = containers.map { $0.containerDictionary }
            dict[group] = serialized
        }
        return dict
    }

    func fromDictionary(serialized: PelicanStorage.Serialized) -> Pelican.GroupedTasks {
        var taskGroups: Pelican.GroupedTasks = [: ]
        for (group, array) in serialized {
            taskGroups[group] = array.flatMap({ containerDict in
                guard let container = TaskContainer(containerDictionary: containerDict, typeToTask: typeToTask) else {
                    /* TODO: Error handling */
                    return nil
                }
                return container
            })
        }

        return containersByGroup
    }
}

extension Pelican.TaskContainer: Equatable {}

func == (lhs: Pelican.TaskContainer, rhs: Pelican.TaskContainer) -> Bool {
    return lhs.identifier == rhs.identifier
}
