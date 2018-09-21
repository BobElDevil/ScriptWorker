//
//  main.swift
//  swiftscript
//
//  Created by Stephen Marquis on 4/5/17.
//  Copyright © 2017 Stephen Marquis. All rights reserved.
//

import Foundation

/** Simple helper program for writing multi-file scripts. As input takes a swift file to run.
 swiftscript looks for line(s) with the format:

//!swiftscript <file-or-directory>
 
 Which it will compile together with the given script (the script acting as the 'main.swift').
 Additionally you can add framework search paths via

 //!swiftsearch <framework-search-path>

 These lines are only processed until the first non-whitespace line with different content is found, with the exception of a shebang #!
 
 Any other arguments supplied to swiftscript will be provided to the resulting 'swift/swiftc' command used to compile everything together
**/

func runExec(task: String, args: [String], overrideExecutablePath: String? = nil) {
    let passedInTask = overrideExecutablePath ?? task
    let fullArgList = [passedInTask] + args
    let cArgs = fullArgList.map { strdup($0) } + [nil]
    task.withCString{ cTask in
        let ret = execv(cTask, cArgs)
        print("Failed to exec \(task) \(args)")
        let errString = String(cString: strerror(errno))
        print("Error \(ret) \(errString)")
    }
}

// Returns the path to the executable in the temporary directory
func setup(file: URL, withAdditionalFiles additionalFiles: [URL], searchPaths: [URL]) -> URL {
    let workingDirectoryTemplate = NSTemporaryDirectory() + "/swiftscript-XXX"
    let workingDirCString = UnsafeMutablePointer<Int8>(mutating: workingDirectoryTemplate.cString(using: .utf8))
    
    guard let cstring = mkdtemp(workingDirCString) else {
        print("Failed to create temporary directory for compilation: errno \(errno)")
        exit(1)
    }

    let workingDirectory = URL(fileURLWithPath: String(cString: cstring))

    let swiftFiles = SwiftScript.swiftURLs(for: additionalFiles)

    let (mainFile, compiledFiles) = SwiftScript.setup(workingDirectory: workingDirectory, for: file, with: swiftFiles)

    let process = Process()
    process.launchPath = "/usr/bin/xcrun"

    let executableURL = workingDirectory.appendingPathComponent(file.deletingPathExtension().lastPathComponent)

    let args = ["swiftc", "-o", executableURL.path] + SwiftScript.swiftArguments(for: mainFile, additionalFiles: compiledFiles, searchPaths: searchPaths)
    process.arguments = args
    process.launch()
    process.waitUntilExit()

    return executableURL
}

guard CommandLine.arguments.count >= 2 else {
    print("No script found to run!")
    print("Usage: swiftscript <script-file> <options>")
    exit(1)
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[1])
let remainingArgs = CommandLine.arguments.suffix(from: 2)

let scriptDir = scriptURL.deletingLastPathComponent()

let lines = SwiftScript.readLines(from: scriptURL)
let (additionalFiles, searchPaths) = SwiftScript.filesAndFrameworks(for: lines, withDir: scriptDir)

if additionalFiles.isEmpty {
    // Just run swift directly instead of compiling the output since there's no additional files
    let args = SwiftScript.swiftArguments(for: scriptURL, additionalFiles: additionalFiles, searchPaths: searchPaths)
    runExec(task: "/usr/bin/xcrun", args: ["swift"] + args + remainingArgs)
} else {
    // Run swift compiler, then exec the resulting binary
    let executable = setup(file: scriptURL, withAdditionalFiles: additionalFiles, searchPaths: searchPaths)

    // Launch a separate process that cleans up our working directory once the process has already begun
    let cleanupProcess = Process()
    cleanupProcess.launchPath = "/bin/sh"
    cleanupProcess.arguments = ["-c", "sleep 10; rm -r \(executable.deletingLastPathComponent().path)"]
    cleanupProcess.launch()

    let scriptDir = scriptURL.deletingLastPathComponent().path
    scriptDir.withCString { cstr in
        chdir(cstr)
        runExec(task: executable.path, args: Array(remainingArgs), overrideExecutablePath: scriptURL.path)
    }
}
