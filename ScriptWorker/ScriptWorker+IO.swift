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
    public func read() -> Data {
        var data: Data! = nil
        exitOnError {
            data = try read_safe()
        }
        return data
    }

    public func read_safe() throws -> Data {
        let fileHandle = try FileHandle(forReadingFrom: url)
        log(action: "Reading contents of \(path)")
        return fileHandle.readDataToEndOfFile()
    }

    /// Read the contents at path as a utf-8 string
    public func readString() -> String {
        var string: String!
        exitOnError {
            string = try readString_safe()
        }
        return string
    }

    public func readString_safe() throws -> String {
        let data = try read_safe()
        let result = String(data: data, encoding: String.Encoding.utf8)
        return result ?? ""
    }

    /// Read the contents at path as a utf-8 string, and return an array of strings separated by newlines
    public func readLines() -> [String] {
        var lines: [String]!
        exitOnError {
            lines = try readLines_safe()
        }
        return lines
    }

    public func readLines_safe() throws -> [String] {
        return try readString_safe().components(separatedBy: CharacterSet.newlines)
    }

    /// Write the given data to path
    public func write(_ data: Data) {
        exitOnError {
            try write_safe(data)
        }
    }

    public func write_safe(_ data: Data) throws {
        log(action: "Writing to file \(path)")
        try data.write(to: url, options: [])
    }

    /// Write the given string to path with the utf8 encoding
    public func writeString(_ string: String) {
        exitOnError {
            try writeString_safe(string)
        }
    }

    public func writeString_safe(_ string: String) throws {
        let data = string.data(using: String.Encoding.utf8)!
        try write_safe(data)
    }

    /// Write the array of lines to path separated by newlines with the utf8 encoding
    public func writeLines(_ lines: [String]) {
        exitOnError {
            try writeLines_safe(lines)
        }
    }

    public func writeLines_safe(_ lines: [String]) throws {
        let string = lines.joined(separator: "\n")
        try writeString_safe(string)
    }

    public func readFileHandle() -> FileHandle? {
        return try? FileHandle(forReadingFrom: url)
    }

    public func writeFileHandle() -> FileHandle? {
        return try? FileHandle(forWritingTo: url)
    }

    public func touch() {
        do {
            try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: path)
        } catch {
            // Must not exist, create a file there
            write(Data())
        }
    }

}
