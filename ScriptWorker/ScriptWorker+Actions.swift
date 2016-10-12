//
//  ScriptWorker+Actions.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

/**
 All of the actions come in two variants. The standard method exits the program on any encountered errors, printing the received error.

 Actions suffixed with '_safe' throw any encountered errors, in case you want to handle the error without program failure.
*/
extension ScriptWorker {
    /// Remove the item pointed to by path. If 'force' is true, it ignores any errors
    public func remove() {
        exitOnError {
            try remove_safe()
        }
    }

    public func remove_safe() throws {
        log(action: "Removing \(path)")
        try fileManager.removeItem(at: url)
    }

    /// Create a directory at path.
    public func makeDirectory(withIntermediates intermediates: Bool = false) {
        exitOnError {
            try makeDirectory_safe(withIntermediates: intermediates)
        }
    }

    public func makeDirectory_safe(withIntermediates intermediates: Bool = false) throws {
        log(action: "Creating directory \(path)")
        try fileManager.createDirectory(at: url, withIntermediateDirectories: intermediates, attributes: nil)
    }

    /// Copy the item at path to the location defined by 'toPath'. toPath can be absolute or relative
    public func copy(to toPath: String) {
        exitOnError {
            try copy_safe(to: toPath)
        }
    }

    public func copy_safe(to toPath: String) throws {
        let destinationURL: URL
        if (toPath as NSString).isAbsolutePath {
            destinationURL = URL(fileURLWithPath: toPath)
        } else {
            destinationURL = url.appendingPathComponent(toPath)
        }
        log(action: "Copying \(path) to \(destinationURL.path)")
        try fileManager.copyItem(at: url, to: destinationURL)
    }

    /// Move the item at path to the location defined by 'toPath'. toPath can be absolute or relative
    public func move(to toPath: String) {
        exitOnError {
            try move_safe(to: toPath)
        }
    }

    public func move_safe(to toPath: String) throws {
        let destinationURL: URL
        if (toPath as NSString).isAbsolutePath {
            destinationURL = URL(fileURLWithPath: toPath)
        } else {
            destinationURL = url.appendingPathComponent(toPath)
        }
        log(action: "Moving \(path) to \(destinationURL.path)")
        try fileManager.moveItem(at: url, to: destinationURL)
    }

    /// Create a symlink at path to the location defined by 'toPath'. toPath can be absolute or relative
    public func symlink(to toPath: String) {
        exitOnError {
            try symlink_safe(to: toPath)
        }
    }

    public func symlink_safe(to toPath: String) throws {
        log(action: "Creating symlink from \(path) to \(toPath)")
        if (toPath as NSString).isAbsolutePath {
            try fileManager.createSymbolicLink(at: url, withDestinationURL: URL(fileURLWithPath: toPath))
        } else {
            // Use path based API to make sure it ends up relative
            try fileManager.createSymbolicLink(atPath: url.path, withDestinationPath: toPath)
        }
    }
}
