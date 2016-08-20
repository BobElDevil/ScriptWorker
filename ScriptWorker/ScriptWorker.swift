//
//  ScriptWorker.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

/**
 Struct that represents a file path to take actions on.
 The represented path doesn't need to exist, but will throw errors if any actions are taken that require an existing path

 All of the actions come in two variants. The standard method exits the program on any encountered errors, printing the received error.

 Actions suffixed with '_safe' throw any encountered errors, in case you want to handle the error without program failure.
*/
public struct ScriptWorker {

    /// The file path represented by this struct
    public var path: String

    // private helper to get the url during file operations
    private var url: NSURL {
        return NSURL(fileURLWithPath: path)
    }

    private let fileManager = NSFileManager.defaultManager()


    /// Name of the currently pointed to item, i.e., the last path component
    public var name: String {
        return (path as NSString).lastPathComponent
    }

    /// Initialize a ScriptWorker object with the given file path
    public init(path: String) {
        self.path = path
    }

    // MARK: Attributes

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
        if let _ = try? fileManager.destinationOfSymbolicLinkAtPath(path) {
            return true
        }

        return false
    }

    // Helper for figuring out attributes.
    private func fileStatus() -> (exists: Bool, directory: Bool) {
        var isDirObj: ObjCBool = false
        let exists = fileManager.fileExistsAtPath(path, isDirectory: &isDirObj)
        return (exists, isDirObj.boolValue)
    }

    // MARK: Actions

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

    /// Returns an array of ScriptWorker's representing the contents at 'path'. If path is not a directory, returns an empty array
    public var contents: [ScriptWorker] {
        guard let items = try? fileManager.contentsOfDirectoryAtPath(path) else {
            return []
        }

        return items.map { item in
            let newPath = url.URLByAppendingPathComponent(item).path!
            return ScriptWorker(path: newPath)
        }
    }

    // MARK: Path stack

    private var pathStack: [String] = []

    // Change the workers current path, and storing the previous path in the stack. The passed in path can be absolute or relative
    mutating func pushPath(newPath: String) {
        pathStack.append(path)
        if (newPath as NSString).absolutePath {
            path = newPath
        } else {
            path = url.URLByAppendingPathComponent(newPath).URLByStandardizingPath!.path!
        }
    }

    // Change the current path back to the previous path. Exits if the directory stack is empty
    mutating func popPath() {
        guard let newPath = pathStack.last else {
            exitMsg("Tried to pop directory with an empty directory stack!")
        }
        path = newPath
    }

    // MARK: Tasks

    // Launch the task and return the status. Configure block for configuring stdout/stderr
    private func launchTask(command: String, arguments: [String] = [], configure: (NSTask -> Void)) -> Int {
        let task = NSTask()
        if isDirectory {
            task.currentDirectoryPath = path
        } else {
            task.currentDirectoryPath = url.URLByDeletingLastPathComponent!.path!
        }

        task.launchPath = "/usr/bin/env" // Use env so we can rely on items in $PATH
        task.arguments = [command] + arguments

        configure(task)

        task.launch()
        task.waitUntilExit()
        return Int(task.terminationStatus)
    }

    // Launches the given task with the working directory set to path (or the parent directory if path is a file), returning a tuple with status, stdout and stderr
    func launchTaskForOutput(command: String, arguments: [String] = []) -> (Int, String, String) {

        var outString: String = ""
        var errString: String = ""
        let status = launchTask(command, arguments: arguments, configure:  { task in
            // Sets up stderr or stdout for reading, and returns a block that should be called once
            // the task is complete
            func setupPipe(forStdout forStdout: Bool) -> (Void -> String) {
                let pipe = NSPipe()
                if forStdout {
                    task.standardOutput = pipe
                } else {
                    task.standardError = pipe
                }

                let readHandle = pipe.fileHandleForReading

                return {
                    let data = readHandle.readDataToEndOfFile()
                    guard let string = String(data: data, encoding: NSUTF8StringEncoding) else {
                        fatalError("Failed to read input from command \(command)")
                    }
                    return string
                }
            }

            let outCompletion = setupPipe(forStdout: true)
            let errorCompletion = setupPipe(forStdout: false)

            task.terminationHandler = { task in
                outString = outCompletion()
                errString = errorCompletion()
            }
        })

        return (status, outString, errString)
    }

    // Runs given task, printing stdout & stderr
    func launchTask(command: String, arguments: [String] = []) -> Int {
        return launchTask(command, arguments: arguments, configure: { task in
            task.standardOutput = NSFileHandle.fileHandleWithStandardOutput()
            task.standardError = NSFileHandle.fileHandleWithStandardError()
        })
    }

}

@noreturn func exitMsg(msg: String) {
    print(msg)
    exit(1)
}

@noreturn func exitError(error: ErrorType) {
    let nsErr = error as NSError
    var msg = nsErr.localizedDescription
    if let reason = nsErr.localizedFailureReason {
        msg += ": \(reason)"
    }
    exitMsg(msg)
}

func exitOnError(@noescape action: (Void throws -> Void)) {
    do {
        try action()
    } catch let error {
        exitError(error)
    }
}
