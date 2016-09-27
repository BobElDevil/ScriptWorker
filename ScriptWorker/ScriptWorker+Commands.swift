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
    public func launch(commandForOutput command: String, arguments: [String] = [], environment: [String: String] = [:], logCommand: Bool = true, exitOnFailure: Bool = false) -> (Int, String, String) {
        var outString: String = ""
        var errString: String = ""
        let status = launch(command: command, arguments: arguments, environment: environment, logCommand: logCommand, exitOnFailure: exitOnFailure, configure:  { task in
            // Sets up stderr or stdout for reading, and returns a block that should be called once
            // the task is complete
            func setupPipe(forStdout: Bool) -> (() -> String) {
                let pipe = Pipe()
                if forStdout {
                    task.standardOutput = pipe
                } else {
                    task.standardError = pipe
                }

                let readHandle = pipe.fileHandleForReading

                return {
                    let data = readHandle.readDataToEndOfFile()
                    guard let string = String(data: data, encoding: .utf8) else {
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
    @discardableResult public func launch(command: String, arguments: [String] = [], environment: [String: String] = [:], logCommand: Bool = true, exitOnFailure: Bool = false) -> Int {
        return launch(command: command, arguments: arguments, environment: environment, logCommand: logCommand, exitOnFailure: exitOnFailure, configure: { task in
            task.standardOutput = FileHandle.standardOutput
            task.standardError = FileHandle.standardError
        })
    }

    private static var childPid: pid_t = -1

    // Launch the task and return the status. Configure block for configuring stdout/stderr
    private func launch(command: String, arguments: [String], environment: [String: String], logCommand: Bool, exitOnFailure: Bool, configure: ((Process) -> Void)) -> Int {
        let task = Process()
        if isDirectory {
            task.currentDirectoryPath = path
        } else {
            task.currentDirectoryPath = url.deletingLastPathComponent().path
        }

        task.launchPath = "/usr/bin/env" // Use env so we can rely on items in $PATH
        // Since we're using 'env' already, we can just prepend the environment variables to the arguments.

        let envArguments = environment.map { key, value in
            "\(key)=\(value)"
        }

        if logCommand {
            print("% Running '\(command) \(arguments.joined(separator: " "))'")
            if environment.count > 0 {
                print("% with environment:")
                environment.forEach { key, value in
                    print("%\t\(key) = \(value)")
                }
            }
        }

        task.arguments = envArguments + [command] + arguments
        configure(task)

        launchAndWait(forTask: task)

        let status = Int(task.terminationStatus)
        if exitOnFailure && status != 0 {
            exitMsg("Error: \(command) failed with exit code \(status)")
        }
        return status
    }

    private func launchAndWait(forTask task: Process) {
        // `Process` is put in a different process group, so to avoid orphaned processes, we install our own signal handler to forward our signals to our child
        trap(signal: .INT, action: { sig in
            if ScriptWorker.childPid != -1 {
                kill(ScriptWorker.childPid, sig)
            }
        })
        task.launch()
        ScriptWorker.childPid = task.processIdentifier
        task.waitUntilExit()
        ScriptWorker.childPid = -1
    }

}
