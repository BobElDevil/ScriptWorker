//
//  PipeWriter.h
//  ScriptWorker
//
//  Created by Stephen Marquis on 6/19/17.
//  Copyright © 2017 Stephen Marquis. All rights reserved.
//

@import Foundation;

// Need to catch broken pipe NSException, so small objective c shim
void forwardBrokenPipeToChild(pid_t child, void (^block)());
