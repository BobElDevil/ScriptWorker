//
//  ScriptWorker.swift
//  ScriptWorker
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

/// Struct that represents a file path to take actions on
public struct ScriptWorker {

    /// Initialize a ScriptWorker object with the given file path. If nil, use the current working directory
    public init(path: String? = nil) {
        // Set line buffering so our output doesn't get weirdly intermixed with sub process output
        setlinebuf(stdout)
        setlinebuf(stderr)
        if let path = path {
            self.url = URL(fileURLWithPath: path)
        } else {
            self.url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        }
    }

    /// Name of the currently pointed to item, i.e., the last path component
    public var name: String {
        return (path() as NSString).lastPathComponent
    }

    /// Prints to stdout any actions the worker takes. Defaults to true
    public static var logActions: Bool = true

    static func log(action: String) {
        if logActions {
            print("% \(action)")
        }
    }

    func log(action: String) {
        ScriptWorker.log(action: action)
    }

    private var url: URL
    func url(item: String? = nil) -> URL {
        if let item = item {
            return url.appendingPathComponent(item)
        } else {
            return url
        }
    }

    let fileManager = FileManager.default

    /// Returns the path reperesented by this struct. Optionally appending item as a component. item Defaults to nil
    public func path(item: String? = nil) -> String {
        return url(item: item).path
    }

    /// Returns an array of Strings with the names of thee contents at 'path'.
    public var contents: [String] {

        guard let items = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
            return []
        }

        return items.map { $0.lastPathComponent }
    }

    /// Attempts to calculate the relative path from the receivers current location to a given path.
    /// It first standardizes both paths and resolves any symbolic links.
    /// This means the relative path may not be the 'shortest' route if other symbolic links are involved in the paths.
    /// Returns 'path' unaltered if it was already relative or the calculation failed.
    public func relative(to path: String) -> String {
        guard (path as NSString).isAbsolutePath else {
            return path
        }

        var pathComponents = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        var toPathComponents = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().pathComponents

        // First remove any path components they have in common
        while pathComponents.first == toPathComponents.first {
            if pathComponents.isEmpty || toPathComponents.isEmpty {
                break
            }

            pathComponents.removeFirst()
            toPathComponents.removeFirst()
        }

        if pathComponents.count > 0 {
            toPathComponents = Array(repeating: "..", count: pathComponents.count) + toPathComponents
        }

        guard toPathComponents.count > 0 else {
            return path
        }

        let relativePath = toPathComponents.joined(separator: "/")
        return relativePath
    }

    // MARK: Path stack

    private var urlStack: [URL] = []

    // Change the workers current path, and storing the previous path in the stack. The passed in path can be absolute or relative
    public mutating func push(_ newPath: String) {
        urlStack.append(url)
        if (newPath as NSString).isAbsolutePath {
            url = URL(fileURLWithPath: newPath)
        } else {
            url = url.appendingPathComponent(newPath).resolvingSymlinksInPath()
        }
    }

    // Change the current path back to the previous path. Exits if the directory stack is empty
    public mutating func pop() {
        guard !urlStack.isEmpty else {
            exitMsg("Tried to pop directory with an empty directory stack!")
        }
        url = urlStack.removeLast()
    }
}

func exitMsg(_ msg: String) -> Never {
    print(msg)
    exit(1)
}

func exitError(_ error: Error) -> Never {
    let nsErr = error as NSError
    var msg = nsErr.localizedDescription
    if let reason = nsErr.localizedFailureReason {
        msg += ": \(reason)"
    }
    exitMsg(msg)
}

func exitOnError(_ action: (() throws -> Void)) {
    do {
        try action()
    } catch let error {
        exitError(error)
    }
}
