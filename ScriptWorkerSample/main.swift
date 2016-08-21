//
//  main.swift
//  ScriptWorkerSample
//
//  Created by Steve Marquis on 8/20/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation
import ScriptWorker


// Proof of concept demo script that first creates a directory with 5 files in it, and a file listing a subset of those files to symlink.  It then reads in that list, and symlinks any entries found in DirOne into a new DirTwo

var script = ScriptWorker()

script.push("Workspace")
_ = try? script.remove_safe()
script.makeDirectory()

// Part one, create the files
script.push("DirOne")
script.makeDirectory()

for file in ["alpha", "beta", "charlie", "delta", "echo"] {
    script.push(file)
    script.writeString("This file is \(file)")
    script.pop()
}
script.pop()

script.push("linkList.txt")
script.writeLines(["beta", "echo"])
script.pop()


// Part two, create the symlinks
script.push("linkList.txt")
let entries = script.readLines()
script.pop()

var readScript = script
readScript.push("DirOne")

script.push("DirTwo")
script.makeDirectory()

for entry in entries {
    readScript.push(entry)
    defer { readScript.pop() }

    guard readScript.exists else {
        continue
    }

    script.push(entry)
    script.symlink(to: script.relativePathTo(readScript))
    script.pop()
}