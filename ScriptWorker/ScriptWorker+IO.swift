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
    /// Read the contents at path as an NSData
    public func read() -> NSData {
        var data: NSData! = nil
        exitOnError {
            data = try read_safe()
        }
        return data
    }

    public func read_safe() throws -> NSData {
        let fileHandle = try NSFileHandle(forReadingFromURL: url)
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
        let result = String(data: data, encoding: NSUTF8StringEncoding)
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
        return try readString_safe().componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
    }

    /// Write the given data to path
    public func write(data: NSData) {
        exitOnError {
            try write_safe(data)
        }
    }

    public func write_safe(data: NSData) throws {
        try data.writeToURL(url, options: [])
    }

    /// Write the given string to path with the utf8 encoding
    public func writeString(string: String) {
        exitOnError {
            try writeString_safe(string)
        }
    }

    public func writeString_safe(string: String) throws {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding)!
        try write_safe(data)
    }

    /// Write the array of lines to path separated by newlines with the utf8 encoding
    public func writeLines(lines: [String]) {
        exitOnError {
            try writeLines_safe(lines)
        }
    }

    public func writeLines_safe(lines: [String]) throws {
        let string = lines.joinWithSeparator("\n")
        try writeString_safe(string)
    }
}