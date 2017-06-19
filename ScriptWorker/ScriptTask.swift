//
//  ScriptTask.swift
//  ScriptWorker
//
//  Created by Stephen Marquis on 6/16/17.
//  Copyright © 2017 Stephen Marquis. All rights reserved.
//

import Foundation

public class ScriptTask {
    public typealias DataHandler = (Data, Bool) -> Void
    public typealias TerminationHandler = (Int) -> Void

    private let command: String
    private let workingDirectory: String
    private var arguments: [String] = []
    private var environment: [String: String] = [:]
    private var dataHandlers: [DataHandler] = []
    private var terminationHandler: TerminationHandler? = nil
    private var exitOnFailure: Bool = false

    // MARK: Builder methods
    public init(_ name: String, workingDirectory: String? = nil) {
        self.command = name
        self.workingDirectory = workingDirectory ?? FileManager.default.currentDirectoryPath
    }

    @discardableResult public func args(_ args: [String]) -> ScriptTask {
        self.arguments = args
        return self
    }

    @discardableResult public func env(_ env: [String: String]) -> ScriptTask {
        self.environment = env
        return self
    }

    @discardableResult public func exitOnFailure(_ exitOnFailure: Bool = true) -> ScriptTask {
        self.exitOnFailure = exitOnFailure
        return self
    }

    // MARK: Piping
    private var destinationTask: ScriptTask? = nil
    private var isPipeDestination: Bool = false

    // Pipes all output from the receiver to the destination task.
    // Any output captured (via `output` or `runForOutput`) will be from the destination, not the receiver
    // If a previous 'pipe' call has been made, it will recursively call pipe on the previous destination, for ease 
    // of setting up pipe chains
    //
    // Note: Once a pipe is set up, only the source task must be started via a `run` method. If called on
    // the destination task, the process will exit with an error
    @discardableResult public func pipe(to: ScriptTask) -> ScriptTask {
        if let destinationTask = destinationTask {
            destinationTask.pipe(to: to)
        } else {
            self.destinationTask = to
            to.isPipeDestination = true
        }
        return self
    }

    // MARK: Data handling
    @discardableResult public func output(to handler: @escaping DataHandler) -> ScriptTask {
        self.dataHandlers.append(handler)
        return self
    }

    @discardableResult public func output(toHandle: FileHandle) -> ScriptTask {
        return self._output(toHandle: toHandle, forPiping: false)
    }

    @discardableResult private func _output(toHandle: FileHandle, forPiping: Bool) -> ScriptTask {
        // Write both stderr and stdout to the target handle
        var otherIsDone: Bool = false // Make sure we wait for both streams to send an empty data
        return self.output { [weak self] data, _ in
            if data.isEmpty {
                if otherIsDone {
                    toHandle.closeFile() // Sends an empty data for us
                } else {
                    otherIsDone = true
                }
            } else {
                if let pid = self?.process.processIdentifier, forPiping {
                    forwardBrokenPipeToChild(pid) {
                        toHandle.write(data)
                    }
                } else {
                    toHandle.write(data)
                }
            }
        }
    }

    @discardableResult private func _outputToParent() -> ScriptTask {
        return self.output(to: { data, isStdOut in
            guard !data.isEmpty else { return }
            if isStdOut {
                FileHandle.standardOutput.write(data)
            } else {
                FileHandle.standardError.write(data)
            }
        })
    }

    // MARK: Running

    // Run the task synchronously. forwards output to the current processes streams if 'printOutput' is true
    // Returns the status code of the process
    @discardableResult public func run(printOutput: Bool = true) -> Int {
        if printOutput {
            self._outputToParent()
        }
        var status = 0
        addTerminationHandler {
            status = $0
        }

        self._launch(sync: true, pipeLaunch: false)
        return status
    }

    @discardableResult public func runForOutput() -> (Int, String, String) {
        var outData = Data()
        var errData = Data()
        self.output(to: { data, isOut in isOut ? outData.append(data) : errData.append(data) })
        let status = self.run(printOutput: false)

        guard let outString = String(data: outData, encoding: .utf8) else {
            fatalError("Failed to read input from command \(command)")
        }
        guard let errString = String(data: errData, encoding: .utf8) else {
            fatalError("Failed to read input from command \(command)")
        }

        return (status, outString, errString)
    }

    // Run the task asynchronously. Status code is sent to the completion block. 
    // By default does not send output anywhere. If interested in the output, use the various `output` variants,
    // or pass 'true' to printOutput
    public func runAsync(printOutput: Bool = false, _ completion: TerminationHandler? = nil) {
        if printOutput {
            self._outputToParent()
        }
        if let completion = completion {
            addTerminationHandler(completion)
        }
        self._launch(sync: false, pipeLaunch: false)
    }

    private var didRun: Bool = false
    private lazy var process = Process()
    private lazy var stdOutPipe = Pipe()
    private lazy var stdErrPipe = Pipe()
    private lazy var stdinPipe = Pipe()
    private func _launch(sync: Bool, pipeLaunch: Bool) {
        guard !didRun else {
            exitMsg("'\(self.command)' attempted to run multiple times!")
        }
        guard !isPipeDestination || pipeLaunch else {
            exitMsg("'\(self.command)' attempted to run when the target of a pipe! Call `run` on the source instead")
        }

        if !pipeLaunch {
            ScriptWorker.log(action: "Running '\(commandDescription)'")
        }
        
        didRun = true
        process.currentDirectoryPath = workingDirectory
        process.launchPath = "/usr/bin/env" // Use env so we can rely on $PATH

        // Since we're using 'env', we just add any environment variables to the arguments
        let envArguments = environment.map { key, value in
            "\(key)=\(value)"
        }

        // Unbuffer IO so we can get it right away
        process.arguments = ["NSUnbufferedIO=YES"] + envArguments + [command] + arguments

        process.standardOutput = stdOutPipe
        process.standardError = stdErrPipe
        process.standardInput = stdinPipe

        if let destinationTask = destinationTask {
            // Pipe all output to the destination
            destinationTask.dataHandlers += self.dataHandlers
            self.dataHandlers.removeAll()
            self._output(toHandle: destinationTask.stdinPipe.fileHandleForWriting, forPiping: true)
        }

        let outComp = setup(pipe: stdOutPipe, stdout: true)
        let errComp = setup(pipe: stdErrPipe, stdout: false)
        addTerminationHandler { _ in
            outComp()
            errComp()
        }
        if exitOnFailure {
            let commandName = self.command
            addTerminationHandler { status in
                if status != 0 {
                    exitMsg("Error: \(commandName) failed with exit code \(status)")
                }
            }
        }

        process.launch() // Launch before setting up the watcher because it needs the Pid
        _watch(pid: process.processIdentifier)

        // If we're piped, run the child first with the same sync settings
        if let destinationTask = destinationTask {
            destinationTask.isPipeDestination = false // Clear the flag so it can run now
            destinationTask._launch(sync: sync, pipeLaunch: true)
        }
        if sync {
            process.waitUntilExit()
        }
    }

    private var commandDescription: String {
        var description = "\(command) \(arguments.joined(separator: " "))"
        if let destinationTask = destinationTask {
            description += " | " + destinationTask.commandDescription
        }
        return description
    }

    private func setup(pipe: Pipe, stdout: Bool) -> ((Void) -> Void)  {
        let readHandle = pipe.fileHandleForReading
        let semaphore = DispatchSemaphore(value: 1)

        readHandle.readabilityHandler = { [weak self] handle in
            semaphore.wait()
            let newData = handle.availableData
            self?.notify(newData, stdout: stdout)
            semaphore.signal()
        }

        return { [weak self] in
            // The 'readabilityHandler' for a file handle doesn't get triggered for EOF for whatever reason, so we clear out the readability handler and read the last available data when the task is done.
            semaphore.wait()
            readHandle.readabilityHandler = nil
            let lastData = readHandle.readDataToEndOfFile()
            self?.notify(lastData, stdout: stdout)
            if !lastData.isEmpty {
                self?.notify(Data(), stdout: stdout)
            }
            semaphore.signal()
        }
    }

    private func notify(_ data: Data, stdout: Bool) {
        dataHandlers.forEach { $0(data, stdout) }
    }

    // MARK: Termination/Launch Handling
    class BundleLookup { } // So we can use the Bundle(forClass:) initializer
    // `Process` is put in a different process group, so to avoid orphaned processes, we install our own signal handler to forward our signals to our child
    // Adds a termination handler to the Process, so should be the _last_ thing called after any other termination handling has bene setup
    private static var childPids: Set<pid_t> = []
    private func _watch(pid: pid_t) {
        setupTraps()
        let watcher = Process()
        watcher.launchPath = Bundle(for: BundleLookup.self).path(forResource: "ProcessParentWatcher", ofType: nil)
        watcher.arguments = ["\(ProcessInfo.processInfo.processIdentifier)", "\(pid)"]
        watcher.launch()
        ScriptTask.childPids.insert(pid)
        addTerminationHandler { _ in
            ScriptTask.childPids.remove(pid)
        }
    }

    private func addTerminationHandler(_ handler: @escaping TerminationHandler) {
        if let existingHandler = process.terminationHandler {
            process.terminationHandler = { theTask in
                existingHandler(theTask)
                handler(Int(theTask.terminationStatus))
            }
        } else {
            process.terminationHandler = { theTask in
                handler(Int(theTask.terminationStatus))
            }
        }
    }

    private func setupTraps() {
        signal(SIGPIPE, SIG_IGN) // We ignore SIGPIPE here, instead we'll catch the broken pipe exception
        let signalsToTrap: [Signal] = [.HUP, .INT, .QUIT, .ABRT, .KILL, .ALRM, .TERM]
        for sig in signalsToTrap {
            trap(signal: sig, action: { theSig in
                let pids = ScriptTask.childPids
                for pid in pids {
                    kill(pid, theSig)
                }
                signal(theSig, SIG_DFL)
            })
        }
    }
}
