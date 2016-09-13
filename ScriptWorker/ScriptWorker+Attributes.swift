//
//  ScriptWorker+Attributes.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

extension ScriptWorker {
    /// Indicates whether the current path is a file
    public var isFile: Bool {
        let status = fileStatus()
        return status.exists && !status.directory
    }

    /// Indicates whether the current path is a directory
    public var isDirectory: Bool {
        let status = fileStatus()
        return status.exists && status.directory
    }

    /**
     Indicates whether the current path exists. Note it is better to attempt an action and handle failure than to check existence to predicate behavior. For example,

     let _ = try script.remove_safe()

     is better than

     if script.exists {
     script.remove()
     }
     */
    public var exists: Bool {
        return fileStatus().exists
    }

    /// Indicates whether the current path is a symbolic link
    public var isSymlink: Bool {
        if let _ = try? fileManager.destinationOfSymbolicLink(atPath: path) {
            return true
        }

        return false
    }

    // Helper for figuring out attributes.
    private func fileStatus() -> (exists: Bool, directory: Bool) {
        var isDirObj: ObjCBool = false
        let exists = fileManager.fileExists(atPath: path, isDirectory: &isDirObj)
        return (exists, isDirObj.boolValue)
    }
}
