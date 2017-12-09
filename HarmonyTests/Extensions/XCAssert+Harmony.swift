//
//  XCAssert+Harmony.swift
//  HarmonyTests
//
//  Created by Riley Testut on 10/21/17.
//  Copyright © 2017 Riley Testut. All rights reserved.
//

import XCTest
@testable import Harmony

import CwlPreconditionTesting

func XCTAssertFatalError<T>(_ expression: @escaping @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line)
{
#if arch(x86_64)
    
    let exception: BadInstructionException? = catchBadInstruction {
        _ = try? expression()
    }
    
    XCTAssert(exception != nil, message, file: file, line: line)
    
#else
    XCTAssert(false, "XCTAssertFatalError can only be run on x86_64 architecture.", file: file, line: line)
#endif
}
