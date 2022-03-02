//
//  PelicanStorage.swift
//  Pods
//
//  Created by Robert Manson on 3/29/17.
//
//

import Foundation

public protocol PelicanStorage {
    func pelicanOverwriteStorage(with data: Data)
    func pelicanLoadFromStorage() -> Data?
    func pelicanDeleteAll()
}
