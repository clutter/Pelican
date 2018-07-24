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
    case retry(delay: TimeInterval)
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
        let container = Pelican.TaskContainer(task: task)
        groupedTasks.insert(container, forGroup: task.group)
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

    init(typeToTask: [String: PelicanBatchableTask.Type], storage: PelicanStorage, maxChunkSize: Int = 50) {
        self.typeToTask = typeToTask
        groupedTasks = GroupedTasks()
        self.storage = storage
        self.maxChunkSize = maxChunkSize

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

    var groupedTasks: GroupedTasks
    let storage: PelicanStorage
    let maxChunkSize: Int

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

        let chunkedTasks = self.groupedTasks.chunkedTasks(by: self.maxChunkSize)

        DispatchQueue.global(qos: .userInitiated).async {
            for (group, containers) in chunkedTasks {
                self.activeGroup = (group, containers)
                guard let firstContainer = containers.first else {
                    self.groupedTasks.removeAllTasks(forGroup: group)
                    continue
                }
                guard let taskType = self.typeToTask[firstContainer.task.taskType] else { /* TODO: Error handling */ continue }

                var retry = true
                var retryDelay: TimeInterval = 0
                let sema = DispatchSemaphore(value: 0)
                while retry {
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + retryDelay) {
                        let tasks = containers.map({ $0.task })
                        taskType.processGroup(tasks: tasks, didComplete: { (result) in
                            switch result {
                            case .done:
                                self.groupedTasks.remove(containers, forGroup: group)
                                retry = false
                                self.activeGroup = nil
                            case .retry(let delay):
                                retryDelay = delay
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

extension Pelican {
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
        let serializedGroups = storage.loadTaskGroups() ?? [:]
        let taskGroups = fromDictionary(serialized: serializedGroups)

        groupedTasks.merge(taskGroups)

        storage.deleteAll()
    }

    func archiveGroups() {
        let taskGroups = toDictionary(taskGroups: groupedTasks.allTasks())

        if taskGroups.isEmpty {
            storage.deleteAll()
        } else {
            storage.overwrite(taskGroups: taskGroups)
        }
    }

    private func toDictionary(taskGroups: [GroupedTasks.GroupAndContainers]) -> PelicanStorage.Serialized {
        var dict: PelicanStorage.Serialized = [:]
        for (group, containers) in taskGroups {
            let serialized: [[String: Any]] = containers.map { $0.containerDictionary }
            dict[group] = serialized
        }
        return dict
    }

    private func fromDictionary(serialized: PelicanStorage.Serialized) -> [GroupedTasks.GroupAndContainers] {
        var taskGroups: [GroupedTasks.GroupAndContainers] = []

        for (group, array) in serialized {
            let containers: [TaskContainer] = array.compactMap { containerDict in
                guard let container = TaskContainer(containerDictionary: containerDict, typeToTask: typeToTask) else {
                    /* TODO: Error handling */
                    return nil
                }
                return container
            }
            taskGroups.append((group, containers))
        }

        return taskGroups
    }
}

extension Pelican.TaskContainer: Equatable {
    static func == (lhs: Pelican.TaskContainer, rhs: Pelican.TaskContainer) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
