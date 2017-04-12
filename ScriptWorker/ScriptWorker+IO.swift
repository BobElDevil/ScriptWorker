//
//  ScriptWorker+IO.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

/// Methods for reading or writing the current path
extension ScriptWorker {
    /// Read the contents at path as Data
    public func read(file: String) -> Data {
        var data: Data! = nil
        exitOnError {
            data = try read_safe(file: file)
        }
        return data
    }

    public func read_safe(file: String) throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: url(item: file))
        log(action: "Reading contents of \(path(item: file))")
        return fileHandle.readDataToEndOfFile()
    }

    /// Read the contents at path as a utf-8 string
    public func readString(file: String) -> String {
        var string: String!
        exitOnError {
            string = try readString_safe(file: file)
        }
        return string
    }

    public func readString_safe(file: String) throws -> String {
        let data = try read_safe(file: file)
        let result = String(data: data, encoding: String.Encoding.utf8)
        return result ?? ""
    }

    /// Read the contents at path as a utf-8 string, and return an array of strings separated by newlines
    public func readLines(file: String) -> [String] {
        var lines: [String]!
        exitOnError {
            lines = try readLines_safe(file: file)
        }
        return lines
    }

    public func readLines_safe(file: String) throws -> [String] {
        return try readString_safe(file: file).components(separatedBy: CharacterSet.newlines)
    }

    /// Write the given data to path
    public func write(_ data: Data, to file: String) {
        exitOnError {
            try write_safe(data, to: file)
        }
    }

    public func write_safe(_ data: Data, to file: String) throws {
        log(action: "Writing to file \(path(item: file))")
        try data.write(to: url(item: file), options: [])
    }

    /// Write the given string to path with the utf8 encoding
    public func writeString(_ string: String, to file: String) {
        exitOnError {
            try writeString_safe(string, to: file)
        }
    }

    public func writeString_safe(_ string: String, to file: String) throws {
        let data = string.data(using: String.Encoding.utf8)!
        try write_safe(data, to: file)
    }

    /// Write the array of lines to path separated by newlines with the utf8 encoding
    public func writeLines(_ lines: [String], to file: String) {
        exitOnError {
            try writeLines_safe(lines, to: file)
        }
    }

    public func writeLines_safe(_ lines: [String], to file: String) throws {
        let string = lines.joined(separator: "\n")
        try writeString_safe(string, to: file)
    }

    public func readFileHandle(for file: String) -> FileHandle? {
        return try? FileHandle(forReadingFrom: url(item: file))
    }

    public func writeFileHandle(for file: String) -> FileHandle? {
        return try? FileHandle(forWritingTo: url(item: file))
    }

    public func touch(file: String) {
        do {
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: path(item: file))
        } catch {
            // Must not exist, create a file there
            write(Data(), to: file)
        }
    }
}
