//
//  ScriptWorker+Attributes.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

extension ScriptWorker {
    /**
     Indicates whether the given item exists and is a file. Note it is better to attempt an action and handle failure than to check existence to predicate behavior. For example,

     let _ = try script.remove_safe(item: foo)

     is better than

     if script.fileExists(foo) {
     script.remove(item: foo)
     }
     */
    public func fileExists(_ file: String) -> Bool {
        let status = fileStatus(for: path(item: file))
        return status.exists && !status.directory
    }

    /// Indicates whether the given item is a directory. If item is nil, returns whether the current path of the reciever is a directory
    public func directoryExists(_ dir: String? = nil) -> Bool {
        let status = fileStatus(for: path(item: dir))
        return status.exists && status.directory
    }

    /// Indicates whether the given file is a symbolic link
    public func fileIsSymlink(_ file: String) -> Bool {
        if let _ = try? fileManager.destinationOfSymbolicLink(atPath: path(item: file)) {
            return true
        }

        return false
    }

    // Helper for figuring out attributes.
    func fileStatus(for itemPath: String) -> (exists: Bool, directory: Bool) {
        var isDirObj: ObjCBool = false
        let exists = fileManager.fileExists(atPath: itemPath, isDirectory: &isDirObj)
        return (exists, isDirObj.boolValue)
    }
}
