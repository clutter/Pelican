//
//  PelicanUserDefaultsStorage.swift
//  Pods
//
//  Created by Robert Manson on 3/29/17.
//
//

import Foundation

public class PelicanUserDefaultsStorage: PelicanStorage {
    let tasksKey = "com.clutter.pelican.codable-tasks"
    public func pelicanOverwriteStorage(with data: Data) {
        UserDefaults.standard.set(data, forKey: tasksKey)
    }

    public func pelicanDeleteAll() {
        UserDefaults.standard.removeObject(forKey: tasksKey)
    }

    public func pelicanLoadFromStorage() -> Data? {
        return UserDefaults.standard.data(forKey: tasksKey)
    }

    public init() {  }
}
