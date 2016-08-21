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

    /// Initialize a ScriptWorker object with the given file path. If nil, use the current working directory
    public init(path: String? = nil) {
        self.path = path ?? NSFileManager.defaultManager().currentDirectoryPath
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

    /// Attempts to calculate the relative path to another ScriptWorker. It first standardizes both paths and resolves any symbolic links.
    /// This means the relative path may not be the 'shortest' route if other symbolic links are involved in the paths.
    /// Returns the absolute path for the given script worker if the calculation fails
    public func relativePathTo(to: ScriptWorker) -> String {
        guard let resolvedURL = url.URLByStandardizingPath?.URLByResolvingSymlinksInPath, toResolvedURL = to.url.URLByStandardizingPath?.URLByResolvingSymlinksInPath else {
            return to.path
        }

        guard var pathComponents = resolvedURL.pathComponents, var toPathComponents = toResolvedURL.pathComponents else {
            return to.path
        }

        // First remove any path components they have in common
        while pathComponents.first == toPathComponents.first {
            if pathComponents.isEmpty || toPathComponents.isEmpty {
                break
            }

            pathComponents.removeFirst()
            toPathComponents.removeFirst()
        }

        if pathComponents.count > 1 {
            toPathComponents = Array(count: pathComponents.count - 1, repeatedValue: "..") + toPathComponents

        }

        guard toPathComponents.count > 0 else {
            return to.path
        }

        let relativePath = toPathComponents.joinWithSeparator("/")
        return relativePath
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

    // MARK: Data operations

    /// Read the contents at path as an NSData
    public func read() -> NSData {
        var data: NSData! = nil
        exitOnError {
            data = try read_safe()
        }
        return data
    }

    public func read_safe() throws -> NSData {
        let fileHandle = try NSFileHandle(forReadingFromURL: url)
        return fileHandle.readDataToEndOfFile()
    }

    /// Read the contents at path as a utf-8 string
    public func readString() -> String {
        var string: String!
        exitOnError {
            string = try readString_safe()
        }
        return string
    }

    public func readString_safe() throws -> String {
        let data = try read_safe()
        let result = String(data: data, encoding: NSUTF8StringEncoding)
        return result ?? ""
    }

    /// Read the contents at path as a utf-8 string, and return an array of strings separated by newlines
    public func readLines() -> [String] {
        var lines: [String]!
        exitOnError {
            lines = try readLines_safe()
        }
        return lines
    }

    public func readLines_safe() throws -> [String] {
        return try readString_safe().componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
    }

    /// Write the given data to path
    public func write(data: NSData) {
        exitOnError {
            try write_safe(data)
        }
    }

    public func write_safe(data: NSData) throws {
        try data.writeToURL(url, options: [])
    }

    /// Write the given string to path with the utf8 encoding
    public func writeString(string: String) {
        exitOnError {
            try writeString_safe(string)
        }
    }

    public func writeString_safe(string: String) throws {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding)!
        try write_safe(data)
    }

    /// Write the array of lines to path separated by newlines with the utf8 encoding
    public func writeLines(lines: [String]) {
        exitOnError {
            try writeLines_safe(lines)
        }
    }

    public func writeLines_safe(lines: [String]) throws {
        let string = lines.joinWithSeparator("\n")
        try writeString_safe(string)
    }

    // MARK: Path stack

    private var pathStack: [String] = []

    // Change the workers current path, and storing the previous path in the stack. The passed in path can be absolute or relative
    public mutating func pushPath(newPath: String) {
        pathStack.append(path)
        if (newPath as NSString).absolutePath {
            path = newPath
        } else {
            path = url.URLByAppendingPathComponent(newPath).URLByStandardizingPath!.path!
        }
    }

    // Change the current path back to the previous path. Exits if the directory stack is empty
    public mutating func popPath() {
        guard !pathStack.isEmpty else {
            exitMsg("Tried to pop directory with an empty directory stack!")
        }
        path = pathStack.removeLast()
    }

    // MARK: Tasks

    /// Launches the given command with the working directory set to path (or the parent directory if path is a file), returning a tuple with status, stdout and stderr
    public func launchCommandForOutput(command: String, arguments: [String] = []) -> (Int, String, String) {
        var outString: String = ""
        var errString: String = ""
        let status = launchCommand(command, arguments: arguments, configure:  { task in
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

    /// Launches the given command with the working directory set to path (or the parent directory if path is a file), returning the status.
    /// Stdout and Stderr are directed to the current programs Stdout and Stderr
    public func launchCommand(command: String, arguments: [String] = []) -> Int {
        return launchCommand(command, arguments: arguments, configure: { task in
            task.standardOutput = NSFileHandle.fileHandleWithStandardOutput()
            task.standardError = NSFileHandle.fileHandleWithStandardError()
        })
    }

    // Launch the task and return the status. Configure block for configuring stdout/stderr
    private func launchCommand(command: String, arguments: [String] = [], configure: (NSTask -> Void)) -> Int {
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
    


}

@noreturn private func exitMsg(msg: String) {
    print(msg)
    exit(1)
}

@noreturn private func exitError(error: ErrorType) {
    let nsErr = error as NSError
    var msg = nsErr.localizedDescription
    if let reason = nsErr.localizedFailureReason {
        msg += ": \(reason)"
    }
    exitMsg(msg)
}

private func exitOnError(@noescape action: (Void throws -> Void)) {
    do {
        try action()
    } catch let error {
        exitError(error)
    }
}
