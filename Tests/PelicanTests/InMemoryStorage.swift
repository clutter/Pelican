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
    var store: Data?
    func pelicanLoadFromStorage() -> Data? {
        return store
    }

    func pelicanDeleteAll() {
        store = nil
    }

    func pelicanOverwriteStorage(with data: Data) {
        store = data
    }
}
