//
//  InMemoryStorage.swift
//  Pelican
//
//  Created by Robert Manson on 4/4/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

import Foundation
import Pelican

class InMemoryStorage: PelicanStorage {
    var store: PelicanStorage.Serialized?
    func loadTaskGroups() -> PelicanStorage.Serialized? {
        return store
    }

    func deleteAll() {
        store = nil
    }

    func overwrite(taskGroups: PelicanStorage.Serialized) {
        store = taskGroups
    }
}
