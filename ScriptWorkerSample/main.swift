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

script.pushPath("Workspace")
_ = try? script.remove_safe()
script.makeDirectory()

// Part one, create the files
script.pushPath("DirOne")
script.makeDirectory()

for file in ["alpha", "beta", "charlie", "delta", "echo"] {
    script.pushPath(file)
    script.writeString("This file is \(file)")
    script.popPath()
}
script.popPath()

script.pushPath("linkList.txt")
script.writeLines(["beta", "echo"])
script.popPath()


// Part two, create the symlinks
script.pushPath("linkList.txt")
let entries = script.readLines()
script.popPath()

var readScript = script
readScript.pushPath("DirOne")

script.pushPath("DirTwo")
script.makeDirectory()

for entry in entries {
    readScript.pushPath(entry)
    defer { readScript.popPath() }

    guard readScript.exists else {
        continue
    }

    script.pushPath(entry)
    script.symlink(to: script.relativePathTo(readScript))
    script.popPath()
}