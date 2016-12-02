//
//  ScriptWorker+Commands.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

extension ScriptWorker {

    public typealias DataHandler = (Data, Bool) -> Void
    public typealias TerminationHandler = (Process) -> Void
    /// Launches the given command with the working directory set to path (or the parent directory if path is a file)
    ///
    /// Returns a tuple with status, stdout and stderr
    public func launch(commandForOutput command: String, arguments: [String] = [], environment: [String: String] = [:], exitOnFailure: Bool = false) -> (Int, String, String) {
        var outData = Data()
        var errData = Data()
        let status = _launchAndWait(command: command, arguments: arguments, environment: environment, exitOnFailure: exitOnFailure, dataHandler:  { (data, isStdout) in
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
    @discardableResult public func launch(command: String, arguments: [String] = [], environment: [String: String] = [:], exitOnFailure: Bool = false, dataHandler: DataHandler? = nil) -> Int {
        if let providedHandler = dataHandler {
            return _launchAndWait(command: command, arguments: arguments, environment: environment, exitOnFailure: exitOnFailure, dataHandler: providedHandler)
        } else {
            return _launchAndWait(command: command, arguments: arguments, environment: environment, exitOnFailure: exitOnFailure, dataHandler: { (data, isStdout) in
                if isStdout {
                    FileHandle.standardOutput.write(data)
                } else {
                    FileHandle.standardError.write(data)
                }
            })
        }
    }

    // MARK: Background commands

    public func launchBackground(command: String, arguments: [String] = [], environment: [String: String] = [:], dataHandler: DataHandler? = nil, terminationHandler: TerminationHandler? = nil) -> Process {
        return _launch(command: command, arguments: arguments, environment: environment, dataHandler: dataHandler, terminationHandler: terminationHandler)
    }

    // MARK: Internal methods

    private func _launchAndWait(command: String, arguments: [String], environment: [String: String], exitOnFailure: Bool, dataHandler: DataHandler? = nil) -> Int {
        let task = _launch(command: command, arguments: arguments, environment: environment, dataHandler: dataHandler, terminationHandler: {_ in})
        task.waitUntilExit()

        let status = Int(task.terminationStatus)
        if exitOnFailure && status != 0 {
            exitMsg("Error: \(command) failed with exit code \(status)")
        }
        return status
    }

    private func _launch(command: String, arguments: [String], environment: [String: String], dataHandler: DataHandler? = nil, terminationHandler: TerminationHandler? = nil) -> Process {
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

        // Unbuffer the IO here since we use pipes now so setlinebuf doesn't work
        task.arguments = ["NSUnbufferedIO=YES"] + envArguments + [command] + arguments

        if let dataHandler = dataHandler {
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
        }
        if let terminationHandler = terminationHandler {
            nestTerminationHandler(forTask: task, handler: terminationHandler)
        }
        _launch(forTask: task)
        return task

    }

    // `Process` is put in a different process group, so to avoid orphaned processes, we install our own signal handler to forward our signals to our child
    // Adds a termination handler to the Process, so should be the _last_ thing called after any other termination handling has bene setup
    private static var childPids: Set<pid_t> = []
    private func _launch(forTask task: Process) {
        setupTrap()
        task.launch()
        ScriptWorker.childPids.insert(task.processIdentifier)
        nestTerminationHandler(forTask: task) { theTask in
            ScriptWorker.childPids.remove(theTask.processIdentifier)
        }
    }

    private func nestTerminationHandler(forTask task: Process, handler: @escaping TerminationHandler) {
        if let existingHandler = task.terminationHandler {
            task.terminationHandler = { theTask in
                existingHandler(theTask)
                handler(theTask)
            }
        } else {
            task.terminationHandler = handler
        }
    }

    private func setupTrap() {
        trap(signal: .INT, action: { sig in
            let pids = ScriptWorker.childPids
            for pid in pids {
                kill(pid, sig)
            }
            signal(sig, SIG_DFL)
            raise(sig)
        })
    }
    


}
