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

    public static func read(path: String) -> Data {
        return applyScriptWorker(path: path) { $0.read(file: $1) }
    }

    public static func read_safe(path: String) throws -> Data {
        return try applyScriptWorker(path: path) { try $0.read_safe(file: $1) }
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

    public static func readString(path: String) -> String {
        return applyScriptWorker(path: path) { $0.readString(file: $1) }
    }

    public static func readString_safe(path: String) throws -> String {
        return try applyScriptWorker(path: path) { try $0.readString_safe(file: $1) }
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

    public static func readLines(path: String) -> [String] {
        return applyScriptWorker(path: path) { $0.readLines(file: $1) }
    }

    public static func readLines_safe(path: String) throws -> [String] {
        return try applyScriptWorker(path: path) { try $0.readLines_safe(file: $1) }
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

    public static func write(_ data: Data, to path: String) {
        return applyScriptWorker(path: path) { $0.write(data, to: $1) }
    }

    public static func write_safe(_ data: Data, to path: String) throws {
        return try applyScriptWorker(path: path) { try $0.write_safe(data, to: $1) }
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

    public static func writeString(_ string: String, to path: String) {
        return applyScriptWorker(path: path) { $0.writeString(string, to: $1) }
    }

    public static func writeString_safe(_ string: String, to path: String) throws {
        return try applyScriptWorker(path: path) { try $0.writeString_safe(string, to: $1) }
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

    public static func writeLines(_ lines: [String], to path: String) {
        return applyScriptWorker(path: path) { $0.writeLines(lines, to: $1) }
    }

    public static func writeLines_safe(_ lines: [String], to path: String) throws {
        return try applyScriptWorker(path: path) { try $0.writeLines_safe(lines, to: $1) }
    }

    /// Acquire file handles to the given file
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

    public static func touch(path: String) {
        applyScriptWorker(path: path) { $0.touch(file: $1) }
    }
}
