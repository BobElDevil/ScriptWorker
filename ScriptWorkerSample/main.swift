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
    script.writeString("This file is \(file)", to: file)
}
script.pop()

script.writeLines(["beta", "echo"], to: "linkList.txt")

// Part two, create the symlinks
let entries = script.readLines(file: "linkList.txt")

var readScript = script
readScript.push("DirOne")

script.push("DirTwo")
script.makeDirectory()

for entry in entries {
    let destPath = readScript.path(item: entry)
    script.symlink(item: entry, to: script.relative(to: destPath))
}
