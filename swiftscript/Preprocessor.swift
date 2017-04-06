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
        case script(String)
        case framework(String)
        case blank
        case other

        init(_ rawLine: String) {
            let parse = { (line: String, prefix: String) -> String? in
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                guard let range = trimmedLine.range(of: prefix, options: .anchored, range: nil, locale: nil) else {
                    return nil
                }

                return trimmedLine.substring(from: range.upperBound).trimmingCharacters(in: .whitespaces)
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

    class func readLines(from filePath: String) -> [String] {
        let scriptUrl = URL(fileURLWithPath: filePath)

        let fileHandle = try! FileHandle(forReadingFrom: scriptUrl)
        let data = fileHandle.readDataToEndOfFile()
        guard let string = String(data: data, encoding: String.Encoding.utf8) else {
            print("Failed to read content of \(scriptUrl)")
            exit(1)
        }


        return string.components(separatedBy: .newlines)
    }

    class func filesAndFrameworks(for lines: [String], withDir dir: String) -> ([String], [String]) {
        guard !lines.isEmpty else {
            return ([], [])
        }
        var lines = lines
        if lines[0].hasPrefix("#!") {
            lines.removeFirst()
        }

        var filesToRead: [String] = []
        var frameworkSearchPaths: [String] = []
        var stop: Bool = false
        while !lines.isEmpty && !stop {
            let line = lines.removeFirst()
            switch LineType(line) {
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

        return (resolve(paths: filesToRead, against: dir), resolve(paths: frameworkSearchPaths, against: dir))
    }

    private class func resolve(paths: [String], against dir: String) -> [String] {
        return paths.map { ($0 as NSString).expandingTildeInPath }.map { path in
            if (path as NSString).isAbsolutePath {
                return path
            } else {
                return (dir as NSString).appendingPathComponent(path)
            }
        }
    }

    class func swiftArguments(for file: URL, additionalFiles: [String], searchPaths: [String]) -> [String] {
        var args: [String] = []
        args += searchPaths.flatMap { ["-F", $0] }
        args.append(file.path)
        args += additionalFiles
        
        return args
    }
}
