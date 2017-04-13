//
//  PelicanUserDefaultsStorage.swift
//  Pods
//
//  Created by Robert Manson on 3/29/17.
//
//

import Foundation

public class PelicanUserDefaultsStorage: PelicanStorage {
    let tasksKey = "com.clutter.pelican"
    public func overwrite(taskGroups: PelicanStorage.Serialized) {
        guard taskGroups.count > 0 else {
            UserDefaults.standard.removeObject(forKey: tasksKey)
            return
        }

        let data = NSKeyedArchiver.archivedData(withRootObject: taskGroups)
        UserDefaults.standard.set(data, forKey: tasksKey)
    }

    public func deleteAll() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
    }

    public func loadTaskGroups() -> PelicanStorage.Serialized? {
        guard let data = UserDefaults.standard.data(forKey: tasksKey) else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(with: data) as? PelicanStorage.Serialized
    }

    public init() {  }
}
