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
        self.path = path ?? NSFileManager.defaultManager().currentDirectoryPath
    }

    /// The file path represented by this struct
    public var path: String


    /// Name of the currently pointed to item, i.e., the last path component
    public var name: String {
        return (path as NSString).lastPathComponent
    }

    var url: NSURL {
        return NSURL(fileURLWithPath: path)
    }

    let fileManager = NSFileManager.defaultManager()

    /// Returns an array of ScriptWorker's representing the contents at 'path'. If path is not a directory, returns an empty array
    public var contents: [ScriptWorker] {
        guard let items = try? fileManager.contentsOfDirectoryAtPath(path) else {
            return []
        }

        return items.map { item in
            let newPath = url.URLByAppendingPathComponent(item).path!
            return ScriptWorker(path: newPath)
        }
    }

    /// Attempts to calculate the relative path to another ScriptWorker. It first standardizes both paths and resolves any symbolic links.
    /// This means the relative path may not be the 'shortest' route if other symbolic links are involved in the paths.
    /// Returns the absolute path for the given script worker if the calculation fails
    public func relativePathTo(to: ScriptWorker) -> String {
        guard let resolvedURL = url.URLByStandardizingPath?.URLByResolvingSymlinksInPath, toResolvedURL = to.url.URLByStandardizingPath?.URLByResolvingSymlinksInPath else {
            return to.path
        }

        guard var pathComponents = resolvedURL.pathComponents, var toPathComponents = toResolvedURL.pathComponents else {
            return to.path
        }

        // First remove any path components they have in common
        while pathComponents.first == toPathComponents.first {
            if pathComponents.isEmpty || toPathComponents.isEmpty {
                break
            }

            pathComponents.removeFirst()
            toPathComponents.removeFirst()
        }

        if pathComponents.count > 1 {
            toPathComponents = Array(count: pathComponents.count - 1, repeatedValue: "..") + toPathComponents

        }

        guard toPathComponents.count > 0 else {
            return to.path
        }

        let relativePath = toPathComponents.joinWithSeparator("/")
        return relativePath
    }

    // MARK: Path stack

    private var pathStack: [String] = []

    // Change the workers current path, and storing the previous path in the stack. The passed in path can be absolute or relative
    public mutating func push(newPath: String) {
        pathStack.append(path)
        if (newPath as NSString).absolutePath {
            path = newPath
        } else {
            path = url.URLByAppendingPathComponent(newPath).URLByStandardizingPath!.path!
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

@noreturn func exitMsg(msg: String) {
    print(msg)
    exit(1)
}

@noreturn func exitError(error: ErrorType) {
    let nsErr = error as NSError
    var msg = nsErr.localizedDescription
    if let reason = nsErr.localizedFailureReason {
        msg += ": \(reason)"
    }
    exitMsg(msg)
}

func exitOnError(@noescape action: (Void throws -> Void)) {
    do {
        try action()
    } catch let error {
        exitError(error)
    }
}
