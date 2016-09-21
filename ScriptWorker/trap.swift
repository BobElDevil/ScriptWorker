// Based on this gist https://gist.github.com/sharplet/d640eea5b6c99605ac79

import Darwin

enum Signal: Int32 {
  case HUP    = 1
  case INT    = 2
  case QUIT   = 3
  case ABRT   = 6
  case KILL   = 9
  case ALRM   = 14
  case TERM   = 15
}

func trap(signal: Signal, action: @convention(c) (Int32) -> ()) {
  // From Swift, sigaction.init() collides with the Darwin.sigaction() function.
  // This local typealias allows us to disambiguate them.
  typealias SignalAction = sigaction

  var signalAction = SignalAction(__sigaction_u: unsafeBitCast(action, to: __sigaction_u.self), sa_mask: 0, sa_flags: 0)

  _ = withUnsafePointer(to: &signalAction) { actionPointer in
    sigaction(signal.rawValue, actionPointer, nil)
  }
}
