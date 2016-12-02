//
//  main.swift
//  ProcessParentWatcher
//
//  Created by Stephen Marquis on 12/2/16.
//  Copyright © 2016 Stephen Marquis. All rights reserved.
//

import Foundation

/// NSTask launches subprocesses in a separate group by default. This means the sub processes are decoupled from the main one.
/// ScriptWorker automatically forwards signals it can handle to children, however it doesn't cover the case where the parent dies
/// with an unhandled signal.
/// This simple process is spun up on the side given the child and parent pid. If the parent disappears and the child is still running it kills it.
let parentPid = Int32(CommandLine.arguments[1])!
let childPid = Int32(CommandLine.arguments[2])!

while true {
    sleep(1)
    if kill(parentPid, 0) != 0 {
        kill(childPid, 9)
        exit(0)
    }
}
