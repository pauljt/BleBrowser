//
//  WBLog.swift
//  BleBrowser
//
//  Created by David Park on 09/10/2018.
//

import Foundation

class WBLog: NSObject {
    enum Level: String {
        case debug
        case log
        case warn
        case error
    }

    let level: Level
    let message: String
    let args: [Any]
    @objc dynamic var isSelected: Bool = false

    static func levelToString(_ level: Level) -> String {
        switch level {
        case .debug: return "Debug"
        case .log: return "Log"
        case .warn: return "Warning"
        case .error: return "Error"
        }
    }

    func levelTaggedMessage() -> String {
        return "\(WBLog.levelToString(self.level)): \(self.message)"
    }

    init(level: Level, message: String, args: [Any]) {
        self.level = level
        self.message = message
        self.args = args
    }
}
