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
        try fileManager.removeItemAtURL(url)
    }

    /// Create a directory at path.
    public func makeDirectory(withIntermediates intermediates: Bool = false) {
        exitOnError {
            try makeDirectory_safe(withIntermediates: intermediates)
        }
    }

    public func makeDirectory_safe(withIntermediates intermediates: Bool = false) throws {
        try fileManager.createDirectoryAtURL(url, withIntermediateDirectories: intermediates, attributes: nil)
    }

    /// Copy the item at path to the location defined by 'toPath'. toPath can be absolute or relative
    public func copy(to toPath: String) {
        exitOnError {
            try copy_safe(to: toPath)
        }
    }

    public func copy_safe(to toPath: String) throws {
        let destinationURL: NSURL
        if (toPath as NSString).absolutePath {
            destinationURL = NSURL(fileURLWithPath: toPath)
        } else {
            destinationURL = url.URLByAppendingPathComponent(toPath)
        }
        try fileManager.copyItemAtURL(url, toURL: destinationURL)
    }

    /// Create a symlink at path to the location defined by 'toPath'. toPath can be absolute or relative
    public func symlink(to toPath: String) {
        exitOnError {
            try symlink_safe(to: toPath)
        }
    }

    public func symlink_safe(to toPath: String) throws {
        if (toPath as NSString).absolutePath {
            try fileManager.createSymbolicLinkAtURL(url, withDestinationURL: NSURL(fileURLWithPath: toPath))
        } else {
            // Use path based API to make sure it ends up relative
            try fileManager.createSymbolicLinkAtPath(url.path!, withDestinationPath: toPath)
        }
    }
}