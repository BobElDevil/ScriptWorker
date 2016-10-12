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
        self.path = path ?? FileManager.default.currentDirectoryPath
    }

    /// The file path represented by this struct.
    public var path: String


    /// Name of the currently pointed to item, i.e., the last path component
    public var name: String {
        return (path as NSString).lastPathComponent
    }

    /// Prints to stdout any actions the worker takes. Defaults to true
    public var logActions: Bool = true

    func log(action: String) {
        if logActions {
            print("% \(action)")
        }
    }

    var url: URL {
        return URL(fileURLWithPath: path)
    }

    let fileManager = FileManager.default

    /// Returns an array of ScriptWorker's representing the contents at 'path'. If path is not a directory, returns an empty array
    public var contents: [ScriptWorker] {
        guard let items = try? fileManager.contentsOfDirectory(atPath: path) else {
            return []
        }

        return items.map { item in
            let newPath = url.appendingPathComponent(item).path
            return ScriptWorker(path: newPath)
        }
    }

    /// Attempts to calculate the relative path to another ScriptWorker. It first standardizes both paths and resolves any symbolic links.
    /// This means the relative path may not be the 'shortest' route if other symbolic links are involved in the paths.
    /// Returns the absolute path for the given script worker if the calculation fails
    public func relative(to: ScriptWorker) -> String {
        var pathComponents = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        var toPathComponents = to.url.standardizedFileURL.resolvingSymlinksInPath().pathComponents

        // First remove any path components they have in common
        while pathComponents.first == toPathComponents.first {
            if pathComponents.isEmpty || toPathComponents.isEmpty {
                break
            }

            pathComponents.removeFirst()
            toPathComponents.removeFirst()
        }

        if pathComponents.count > 1 {
            toPathComponents = Array(repeating: "..", count: pathComponents.count - 1) + toPathComponents

        }

        guard toPathComponents.count > 0 else {
            return to.path
        }

        let relativePath = toPathComponents.joined(separator: "/")
        return relativePath
    }

    // MARK: Path stack

    private var pathStack: [String] = []

    // Change the workers current path, and storing the previous path in the stack. The passed in path can be absolute or relative
    public mutating func push(_ newPath: String) {
        pathStack.append(path)
        if (newPath as NSString).isAbsolutePath {
            path = newPath
        } else {
            path = url.appendingPathComponent(newPath).resolvingSymlinksInPath().path
        }
    }

    // Change the current path back to the previous path. Exits if the directory stack is empty
    public mutating func pop() {
        guard !pathStack.isEmpty else {
            exitMsg("Tried to pop directory with an empty directory stack!")
        }
        path = pathStack.removeLast()
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
