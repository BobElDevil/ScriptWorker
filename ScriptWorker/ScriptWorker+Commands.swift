//
//  ScriptWorker+Commands.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation


extension ScriptWorker {

    public func task(_ command: String) -> ScriptTask {
        let workingDir = directoryExists() ? path() : url().deletingLastPathComponent().path
        return ScriptTask(command, workingDirectory: workingDir)
    }

    // MARK: Legacy methods for api compatibility

    /// Launches the given command with the working directory set to path (or the parent directory if path is a file)
    ///
    /// Returns a tuple with status, stdout and stderr
    public func launch(commandForOutput command: String, arguments: [String] = [], environment: [String: String] = [:], exitOnFailure: Bool = false) -> (Int, String, String) {
        return task(command).args(arguments).env(environment).exitOnFailure().runForOutput()
    }

    /// Launches the given command with the working directory set to path (or the parent directory if path is a file). If provided, calls dataHandler with any data from the command. If the bool is true, it came from stdout, otherwise stderr.
    /// If not provided, all output is piped to the current stdout/stderr respectively
    /// Note: While dataHandler is technically marked '@escaping', because we always wait for the task to complete, you can be guaranteed that dataHandler will not be called after this method completes.
    ///
    /// Returns the status.
    @discardableResult public func launch(command: String, arguments: [String] = [], environment: [String: String] = [:], exitOnFailure: Bool = false, dataHandler: ScriptTask.DataHandler? = nil) -> Int {
        let task = self.task(command).args(arguments).env(environment).exitOnFailure(exitOnFailure)
        let status: Int
        if let providedHandler = dataHandler {
            task.output(to: providedHandler)
            status = task.run(printOutput: false)
        } else {
            status = task.run()
        }
        return status
    }

    // MARK: Background commands

    public func launchBackground(command: String, arguments: [String] = [], environment: [String: String] = [:], dataHandler: ScriptTask.DataHandler? = nil, terminationHandler: ScriptTask.TerminationHandler? = nil) {
        let task = self.task(command).args(arguments).env(environment)
        if let dataHandler = dataHandler {
            task.output(to: dataHandler)
        }
        task.runAsync(terminationHandler)
    }
}
