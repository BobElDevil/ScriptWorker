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
    /// Remove the specified item. If item is nil, remove the path currently represented by the receiver. item defaults to nil.
    public func remove(item: String? = nil) {
        exitOnError {
            try remove_safe(item: item)
        }
    }

    public func remove_safe(item: String? = nil) throws {
        log(action: "Removing \(path(item: item))")
        try fileManager.removeItem(at: url(item: item))
    }

    /// Create a directory. If item is nil, creates directory at the path currently represented by the reciever. item defaults to nil
    public func makeDirectory(at item: String? = nil, withIntermediates intermediates: Bool = false) {
        exitOnError {
            try makeDirectory_safe(at: item, withIntermediates: intermediates)
        }
    }

    public func makeDirectory_safe(at item: String? = nil, withIntermediates intermediates: Bool = false) throws {
        log(action: "Creating directory \(path(item: item))")
        try fileManager.createDirectory(at: url(item: item), withIntermediateDirectories: intermediates, attributes: nil)
    }

    /// Copy item at path to the location defined by 'toPath'. toPath can be absolute or relative
    /// If item is nil, copies the directory represented by the receiver.
    /// If 'toPath' alreday exists and is a directory, it will copy the item into that directory with the original name.
    /// Otherwise it copies to the destination with the destination name
    public func copy(item: String? = nil, to toPath: String) {
        exitOnError {
            try copy_safe(item: item, to: toPath)
        }
    }

    public func copy_safe(item: String? = nil, to toPath: String) throws {
        let destinationURL = destinationURLFor(item: item, path: toPath)
        log(action: "Copying \(path(item: item)) to \(destinationURL.path)")
        try fileManager.copyItem(at: url(item: item), to: destinationURL)
    }

    /// Move the item at path to the location defined by 'toPath'. toPath can be absolute or relative
    /// If item is nil, moves the directory represented by the receiver.
    /// If 'toPath' already exists and is a directory, it will move the item into that directory with the original name.
    /// Otherwise it moves to the destination with the destination name
    public func move(item: String? = nil, to toPath: String) {
        exitOnError {
            try move_safe(item: item, to: toPath)
        }
    }

    public func move_safe(item: String? = nil, to toPath: String) throws {
        let destinationURL = destinationURLFor(item: item, path: toPath)
        log(action: "Moving \(path(item: item)) to \(destinationURL.path)")
        try fileManager.moveItem(at: url(item: item), to: destinationURL)
    }

    private func destinationURLFor(item: String?, path: String) -> URL {
        var destinationURL: URL
        if (path as NSString).isAbsolutePath {
            destinationURL = URL(fileURLWithPath: path)
        } else {
            destinationURL = url().appendingPathComponent(path)
        }
        let (exists, isDir) = fileStatus(for: destinationURL.path)
        print("Exists: \(exists), isDir: \(isDir) for \(destinationURL.path)")
        if exists && isDir {
            destinationURL.appendPathComponent(item ?? url().lastPathComponent)
        }
        return destinationURL
    }

    /// Create a symlink at path to the location defined by 'toPath'. toPath can be absolute or relative
    public func symlink(item: String, to toPath: String) {
        exitOnError {
            try symlink_safe(item: item, to: toPath)
        }
    }

    public func symlink_safe(item: String, to toPath: String) throws {
        log(action: "Creating symlink from \(path(item: item)) to \(toPath)")
        if (toPath as NSString).isAbsolutePath {
            try fileManager.createSymbolicLink(at: url(item: item), withDestinationURL: URL(fileURLWithPath: toPath))
        } else {
            // Use path based API to make sure it ends up relative
            try fileManager.createSymbolicLink(atPath: path(item: item), withDestinationPath: toPath)
        }
    }
}
