//
//  PelicanStorage.swift
//  Pods
//
//  Created by Robert Manson on 3/29/17.
//
//

import Foundation

public protocol PelicanStorage {
    typealias Serialized = [String: [[String: Any]]]
    func overwrite(taskGroups: Serialized)
    func loadTaskGroups() -> Serialized?
    func deleteAll()
}
