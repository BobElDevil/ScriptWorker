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
    public func launch(commandForOutput command: String, arguments: [String] = [], environment: [String: String] = [:], exitOnFailure: Bool = false) -> (Int, String, String) {
        var outData = Data()
        var errData = Data()
        let status = _launch(command: command, arguments: arguments, environment: environment, exitOnFailure: exitOnFailure, dataHandler:  { (data, isStdout) in
            if (isStdout) {
                outData.append(data)
            } else {
                errData.append(data)
            }
        })

        guard let outString = String(data: outData, encoding: .utf8) else {
            fatalError("Failed to read input from command \(command)")
        }
        guard let errString = String(data: errData, encoding: .utf8) else {
            fatalError("Failed to read input from command \(command)")
        }

        return (status, outString, errString)
    }

    /// Launches the given command with the working directory set to path (or the parent directory if path is a file). If provided, calls dataHandler with any data from the command. If the bool is true, it came from stdout, otherwise stderr.
    /// If not provided, all output is piped to the current stdout/stderr respectively
    /// Note: While dataHandler is technically marked '@escaping', because we always wait for the task to complete, you can be guaranteed that dataHandler will not be called after this method completes.
    ///
    /// Returns the status.
    @discardableResult public func launch(command: String, arguments: [String] = [], environment: [String: String] = [:], exitOnFailure: Bool = false, dataHandler: ((Data, Bool) -> Void)? = nil) -> Int {
        if let providedHandler = dataHandler {
            return _launch(command: command, arguments: arguments, environment: environment, exitOnFailure: exitOnFailure, dataHandler: providedHandler)
        } else {
            return _launch(command: command, arguments: arguments, environment: environment, exitOnFailure: exitOnFailure, dataHandler: { (data, isStdout) in
                if isStdout {
                    FileHandle.standardOutput.write(data)
                } else {
                    FileHandle.standardError.write(data)
                }
            })
        }
    }



    private static var childPid: pid_t = -1
    // Internal function used by all the public variants for the bulk of the launch work
    private func _launch(command: String, arguments: [String], environment: [String: String], exitOnFailure: Bool, dataHandler: @escaping (Data, Bool) -> Void) -> Int {
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

        log(action: "Running '\(command) \(arguments.joined(separator: " "))'")

        task.arguments = envArguments + [command] + arguments

        // Sets up stderr or stdout for reading, and returns a block that should be called once
        // the task is complete
        func setupPipe(forStdout: Bool) -> ((Void) -> Void)  {
            let pipe = Pipe()
            if forStdout {
                task.standardOutput = pipe
            } else {
                task.standardError = pipe
            }

            let readHandle = pipe.fileHandleForReading
            let semaphore = DispatchSemaphore(value: 1)

            readHandle.readabilityHandler = { handle in
                semaphore.wait()
                let newData = handle.availableData
                dataHandler(newData, forStdout)
                semaphore.signal()
            }

            return {
                // The 'readabilityHandler' for a file handle doesn't get triggered for EOF for whatever reason, so we clear out the readability handler and read the last available data when the task is done.
                semaphore.wait()
                readHandle.readabilityHandler = nil
                dataHandler(readHandle.readDataToEndOfFile(), forStdout)
                semaphore.signal()
            }
        }
        let outComp = setupPipe(forStdout: true)
        let errComp = setupPipe(forStdout: false)
        task.terminationHandler = { _ in
            outComp()
            errComp()
        }
        _launchAndWait(forTask: task)

        let status = Int(task.terminationStatus)
        if exitOnFailure && status != 0 {
            exitMsg("Error: \(command) failed with exit code \(status)")
        }
        return status
    }

    private func _launchAndWait(forTask task: Process) {
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
