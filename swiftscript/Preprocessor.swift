//
//  Preprocessor.swift
//  ScriptWorker
//
//  Created by Stephen Marquis on 4/5/17.
//  Copyright © 2017 Stephen Marquis. All rights reserved.
//

import Foundation

// Simple container class so we can compile this into a unit test bundle
class Preprocessor {
    private enum LineType {
        case script(URL)
        case framework(URL)
        case blank
        case other

        init(_ rawLine: String, againstBase base: URL) {
            let parse = { (line: String, prefix: String) -> URL? in
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                guard let range = trimmedLine.range(of: prefix, options: .anchored, range: nil, locale: nil) else {
                    return nil
                }

                var path = trimmedLine.substring(from: range.upperBound).trimmingCharacters(in: .whitespaces)
                path = (path as NSString).expandingTildeInPath
                let url: URL
                if (path as NSString).isAbsolutePath {
                    url = URL(fileURLWithPath: path)
                } else {
                    url = base.appendingPathComponent(path)
                }

                return url
            }

            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let val = parse(line, "//!swiftscript") {
                self = .script(val)
            } else if let val = parse(line, "//!swiftsearch") {
                self = .framework(val)
            } else {
                self = line.trimmingCharacters(in: .whitespaces).isEmpty ? .blank : .other
            }
        }
    }

    class func readLines(from fileURL: URL) -> [String] {
        let fileHandle = try! FileHandle(forReadingFrom: fileURL)
        let data = fileHandle.readDataToEndOfFile()
        guard let string = String(data: data, encoding: String.Encoding.utf8) else {
            print("Failed to read content of \(fileURL)")
            exit(1)
        }


        return string.components(separatedBy: .newlines)
    }

    class func filesAndFrameworks(for lines: [String], withDir dir: URL) -> ([URL], [URL]) {
        guard !lines.isEmpty else {
            return ([], [])
        }
        var lines = lines
        if lines[0].hasPrefix("#!") {
            lines.removeFirst()
        }

        var filesToRead: [URL] = []
        var frameworkSearchPaths: [URL] = []
        var stop: Bool = false
        while !lines.isEmpty && !stop {
            let line = lines.removeFirst()
            switch LineType(line, againstBase: dir) {
            case let .script(file):
                filesToRead.append(file)
            case let .framework(path):
                frameworkSearchPaths.append(path)
            case .blank:
                continue
            case .other:
                stop = true
            }
        }

        return (filesToRead, frameworkSearchPaths)
    }

    class func swiftArguments(for file: URL, additionalFiles: [URL], searchPaths: [URL]) -> [String] {
        var args: [String] = []
        args += searchPaths.flatMap { ["-F", $0.path] }
        args.append(file.path)
        args += additionalFiles.map { $0.path }
        
        return args
    }

    class func swiftURLs(for additionalFiles: [URL]) -> [URL] {
        let fileManager = FileManager.default
        let swiftURLs = additionalFiles
            .flatMap { fileOrDirectory -> [URL] in
                var isDirectory = ObjCBool(booleanLiteral: false)
                guard fileManager.fileExists(atPath: fileOrDirectory.path, isDirectory: &isDirectory) else {
                    print("Could not find additional file \(fileOrDirectory.path) to compile")
                    exit(1)
                }

                if isDirectory.boolValue {
                    return try! fileManager.contentsOfDirectory(at: fileOrDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                        .filter { $0.pathExtension == "swift" }
                } else {
                    return [fileOrDirectory]
                }
            }
        return swiftURLs
    }

    // Returns the destination urls of the script and additional swift files
    class func setup(workingDirectory: URL, for script: URL, with swiftURLs: [URL]) -> (URL, [URL]) {

        let fileManager = FileManager.default
        let destinations = swiftURLs.map { workingDirectory.appendingPathComponent($0.lastPathComponent) }
        let scriptDestination = workingDirectory.appendingPathComponent("main.swift")

        zip(swiftURLs, destinations).forEach { source, destination in
            try! fileManager.copyItem(at: source, to: destination)
        }

        try! fileManager.copyItem(at: script, to: scriptDestination)

        return (scriptDestination, destinations)
    }
}
