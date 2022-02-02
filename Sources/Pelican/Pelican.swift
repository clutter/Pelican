//
//  Pelican.swift
//  Pods
//
//  Created by Robert Manson on 3/29/17.
//
//

import UIKit

public enum PelicanProcessResult {
    case done
    case retry(delay: TimeInterval)
}

public protocol PelicanGroupable {
    var group: String { get }

    /// Called on a background thread to process a group of collected tasks
    static func processGroup(tasks: [PelicanBatchableTask], didComplete: @escaping ((PelicanProcessResult) -> Void))
}

public protocol PelicanBatchableTask: PelicanGroupable, Codable {
    static var taskType: String { get }
}

extension PelicanBatchableTask {
    var taskType: String {
        return Self.taskType
    }
}

public class Pelican {
    public static var shared: Pelican!

    public struct RegisteredTasks {
        var typeToTask: [String: PelicanBatchableTask.Type] = [:]

        public mutating func register<T: PelicanBatchableTask>(for type: T.Type) {
            TaskContainer.register(for: type)
            typeToTask[type.taskType] = type
        }

        public init() { }
    }

    public static func initialize(tasks: RegisteredTasks,
                                  storage: PelicanStorage = PelicanUserDefaultsStorage()) {
        shared = Pelican(tasks: tasks, storage: storage)
    }

    public func gulp(task: PelicanBatchableTask) {
        let container = TaskContainer(task: task)
        groupedTasks.insert(container, forGroup: task.group)
    }

    // MARK: - Intialization

    init(tasks: RegisteredTasks, storage: PelicanStorage, maxChunkSize: Int = 50) {
        self.typeToTask = tasks.typeToTask
        groupedTasks = GroupedTasks()
        self.storage = storage
        self.maxChunkSize = maxChunkSize

        start()

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(didEnterBackground),
                                       name: UIApplication.didEnterBackgroundNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(willTerminate),
                                       name: UIApplication.willTerminateNotification,
                                       object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(willEnterForeground),
                                       name: UIApplication.willEnterForegroundNotification,
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
            for taskGroup in chunkedTasks {
                self.activeGroup = (taskGroup.group, taskGroup.containers)
                guard let firstContainer = taskGroup.containers.first else {
                    self.groupedTasks.removeAllTasks(forGroup: taskGroup.group)
                    continue
                }
                guard let taskType = self.typeToTask[firstContainer.task.taskType] else {
                    /* TODO: Error handling */
                    continue
                }

                var retry = true
                var retryDelay: TimeInterval = 0
                let sema = DispatchSemaphore(value: 0)
                while retry {
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + retryDelay) {
                        let tasks = taskGroup.containers.map({ $0.task })
                        taskType.processGroup(tasks: tasks, didComplete: { (result) in
                            switch result {
                            case .done:
                                self.groupedTasks.remove(taskGroup.containers, forGroup: taskGroup.group)
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
        groupedTasks.removeAllTasks()
    }

    // MARK: - Serialization Helpers

    func unarchiveGroups() {
        if let data = storage.pelicanLoadFromStorage(),
            let taskGroups = try? JSONDecoder().decode([GroupedTasks.GroupAndContainers].self, from: data) {
            groupedTasks.merge(taskGroups)
        }

        storage.pelicanDeleteAll()
    }

    func archiveGroups() {
        let taskGroups = groupedTasks.allTasks()

        if taskGroups.isEmpty {
            storage.pelicanDeleteAll()
        } else {
            guard let data = try? JSONEncoder().encode(taskGroups) else {
                return
            }

            storage.pelicanOverwriteStorage(with: data)
        }
    }
}
