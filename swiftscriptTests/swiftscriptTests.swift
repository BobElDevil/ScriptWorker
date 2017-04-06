//
//  swiftscriptTests.swift
//  swiftscriptTests
//
//  Created by Stephen Marquis on 4/5/17.
//  Copyright © 2017 Stephen Marquis. All rights reserved.
//

import XCTest

class swiftscriptTests: XCTestCase {

    private func validate(files: [String], searchPaths: [String], inLines lines: [String], file: StaticString = #file, line: UInt = #line) {
        let (scriptsAndDirs, foundSearchPaths) = Preprocessor.filesAndFrameworks(for: lines, withDir: "/Relative/Prefix")
        XCTAssertEqual(scriptsAndDirs, files, file: file, line: line)
        XCTAssertEqual(foundSearchPaths, searchPaths, file: file, line: line)
    }
    
    func testNoScriptLines() {
        validate(files: [], searchPaths: [], inLines: [])
    }

    func testScriptLinesWithoutWhitespace() {
        validate(files: ["/file1", "/file2"], searchPaths: [], inLines: ["//!swiftscript /file1", "//!swiftscript /file2"])
        validate(files: ["/file1", "/file2"], searchPaths: [], inLines: ["#!/usr/bin/stuff", "//!swiftscript /file1", "//!swiftscript /file2"])
    }

    func testScriptLinesWithWhitespace() {
        validate(files: ["/file1", "/file2"], searchPaths: [], inLines: ["//!swiftscript /file1", "", "  ", "  ", "//!swiftscript /file2"])
        validate(files: ["/file1", "/file2"], searchPaths: [], inLines: ["#!/usr/bin/stuff", "//!swiftscript /file1", "", "  ", "  ", "//!swiftscript /file2"])
    }

    func testScriptLinesStopParsing() {
        validate(files: ["/file1"], searchPaths: [], inLines: ["//!swiftscript /file1", "class Stuff {", "//!swiftscript /file2"])
        validate(files: ["/file1"], searchPaths: [], inLines: ["//!swiftscript /file1", "#!/shebang/not/on/first/line", "//!swiftscript /file2"])
        validate(files: ["/file1"], searchPaths: [], inLines: ["#!/usr/bin/stuff", "//!swiftscript /file1", "#!/shebang/not/on/first/line", "//!swiftscript /file2"])
        validate(files: ["/file1"], searchPaths: [], inLines: ["#!/usr/bin/stuff", "//!swiftscript /file1", "InterruptionAndWhitespace", "   ", "//!swiftscript /file2"])
    }

    func testScriptAndSearchPaths() {
        validate(files: ["/file1"], searchPaths: ["/dir2"], inLines: ["//!swiftscript /file1", "//!swiftsearch /dir2"])
        validate(files: ["/file1", "/file2"], searchPaths: ["/dir2"], inLines: ["//!swiftscript /file1", "//!swiftsearch /dir2", "//!swiftscript /file2"])
    }

    func testPathExpansions() {
        validate(files: ["/Relative/Prefix/file1"], searchPaths: [], inLines: ["//!swiftscript file1"])
        validate(files: ["\(FileManager.default.homeDirectoryForCurrentUser.path)/file1"], searchPaths: [], inLines: ["//!swiftscript ~/file1"])
    }

    func testCompilerArgGeneration() {
        let args = Preprocessor.swiftArguments(for: URL(fileURLWithPath: "/my/script.swift"), additionalFiles: ["/my/localdep.swift"], searchPaths: ["/Library/Frameworks"])
        XCTAssertEqual(args, ["-F", "/Library/Frameworks", "/my/script.swift", "/my/localdep.swift"])
    }
    
}
