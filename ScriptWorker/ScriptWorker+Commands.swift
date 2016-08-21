//
//  ScriptWorker+Commands.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

extension ScriptWorker {
    /// Launches the given command with the working directory set to path (or the parent directory if path is a file)
    ///
    /// Returns a tuple with status, stdout and stderr
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

    /// Launches the given command with the working directory set to path (or the parent directory if path is a file), forwarding stderr and stdout to the current process
    ///
    /// Returns the status.
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