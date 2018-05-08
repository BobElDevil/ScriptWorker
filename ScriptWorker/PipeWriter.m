//
//  PipeWriter.m
//  ScriptWorker
//
//  Created by Stephen Marquis on 6/19/17.
//  Copyright © 2017 Stephen Marquis. All rights reserved.
//

#import "PipeWriter.h"

void forwardBrokenPipeToChild(pid_t child, void (^block)(void)) {
    @try {
        block();
    } @catch(NSException *e) {
        if ([e.name isEqualToString:NSFileHandleOperationException]) {
            kill(child, SIGPIPE);
        } else {
            [e raise];
        }
    }
}
