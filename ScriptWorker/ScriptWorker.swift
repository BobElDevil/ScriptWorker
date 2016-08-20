//
//  ScriptWorker.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

// Simple struct to encapsulate common scripting actions.
struct ScriptWorker {
    enum ScriptError : ErrorType {
        case NotADirectory
        case EmptyDirectoryStack
    }

    // Current path of the worker
    var path: String

    // Name of the item, i.e., the last path component
    var name: String {
        return (path as NSString).lastPathComponent
    }

    // Helper var for operations that require a url
    private var url: NSURL {
        return NSURL(fileURLWithPath: path)
    }

    private var pathStack: [String] = []

    private let fileManager = NSFileManager.defaultManager()

    // If no path is given, defaults to the processes current working directory
    init(path: String? = nil) {
        if let path = path {
            self.path = path
        } else {
            self.path = fileManager.currentDirectoryPath
        }
    }

    // Change the workers current path by applying relativePath, and storing the previous path in the stack
    mutating func pushPath(relativePath: String) {
        let newURL = url.URLByAppendingPathComponent(relativePath).URLByStandardizingPath!
        pathStack.append(path)
        path = newURL.path!
    }

    // Change the current path back to the previous path. Must be matched with a previous call to push
    mutating func popPath() {
        guard let newPath = pathStack.last else {
            exitMsg("Tried to pop directory with an empty directory stack!")
        }
        path = newPath
    }

    var isFile: Bool {
        var isDirObj: ObjCBool = false
        let exists = fileManager.fileExistsAtPath(path, isDirectory: &isDirObj)

        return exists && !isDirObj.boolValue
    }

    var isDirectory: Bool {
        var isDirObj: ObjCBool = false
        let exists = fileManager.fileExistsAtPath(path, isDirectory: &isDirObj)

        return exists && isDirObj.boolValue
    }

    var isSymlink: Bool {
        if let _ = try? fileManager.destinationOfSymbolicLinkAtPath(path) {
            return true
        }

        return false
    }

    func removeItem(force force: Bool = false) {
        if force {
            _ = try? fileManager.removeItemAtURL(url)
        } else {
            exitOnError {
                try fileManager.removeItemAtURL(url)
            }
        }
    }

    func makeDirectory(withIntermediates intermediates: Bool = false) {
        exitOnError {
            try fileManager.createDirectoryAtURL(url, withIntermediateDirectories: intermediates, attributes: nil)
        }
    }

    func copy(to toPath: String) {
        exitOnError {
            try fileManager.copyItemAtURL(url, toURL: NSURL(fileURLWithPath: toPath))
        }
    }

    func symlink(to toPath: String) {
        exitOnError {
            if (toPath as NSString).absolutePath {
                try fileManager.createSymbolicLinkAtURL(url, withDestinationURL: NSURL(fileURLWithPath: toPath))
            } else {
                // Use path based API to make sure it ends up relative
                try fileManager.createSymbolicLinkAtPath(url.path!, withDestinationPath: toPath)
            }
        }
    }

    // Enumerates all items within self, generating a new ScriptWorker whos path is the full path of self (including 'name'), and `name` set to the item within the directory.
    var contents: [ScriptWorker] {
        var items: [String] = []
        exitOnError {
            items = try fileManager.contentsOfDirectoryAtPath(path)
        }

        return items.map { item in
            var subworker = ScriptWorker(path: path)
            subworker.pushPath(item)
            return subworker
        }
    }

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