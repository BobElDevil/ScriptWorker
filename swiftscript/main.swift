//
//  main.swift
//  swiftscript
//
//  Created by Stephen Marquis on 4/5/17.
//  Copyright © 2017 Stephen Marquis. All rights reserved.
//

import Foundation

/** Simple helper program for writing multi-file scripts. As input takes a swift file to run.
 swiftscript looks for line(s) with the format:

//!swiftscript <file-or-directory>
 
 Which it will compile together with the given script (the script acting as the 'main.swift').
 Additionally you can add framework search paths via

 //!swiftsearch <framework-search-path>

 These lines are only processed until the first non-whitespace line with different content is found, with the exception of a shebang #!
 
 Any other arguments supplied to swiftscript will be provided to the resulting 'swift/swiftc' command used to compile everything together
**/

