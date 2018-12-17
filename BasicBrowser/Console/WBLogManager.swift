//
//  WBLogManager.swift
//  BleBrowser
//
//  Created by David Park on 11/10/2018.
//

import Foundation

class WBLogManager: NSObject {

    // could have used dynamic to trigger KVO more easily, but this
    // would have triggered "set"s for "insert"s which we don't want,
    // so manage it manually.
    @objc public var logs: [WBLog] = []
    @objc dynamic private(set) public var aLogIsSelected: Bool = false

    func addLog(_ log: WBLog) {
        let insertIndex = self.logs.count
        self.willChange(.insertion, valuesAt: IndexSet(integer: insertIndex), forKey: "logs")
        self.logs.append(log)
        self._observeLog(log)
        self.didChange(.insertion, valuesAt: IndexSet(integer: insertIndex), forKey: "logs")
    }
    func clearLogs() {
        NSLog("WBLogManager clearLogs()")
        // since logs is not dynamic can't just do self.logs = []
        self.setValue([], forKey: "logs")
    }
    func deselectLogs() {
        self.logs.forEach{$0.isSelected = false}
    }
    func selectedLogText() -> String {
        let res = self.logs.filter{$0.isSelected}.map{$0.levelTaggedMessage()}.joined(separator: "\n")
        return res
    }

    // MARK: - Observe protocol
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard
            let _ = keyPath,
            let _ = change
            else {
                NSLog("Unexpected change with either no keyPath or no change dictionary!")
                return
        }

        switch object! {
        case _ as WBLog:
            switch keyPath! {
            case "isSelected":
                let currALogIsSelected = self.aLogIsSelected
                let newALogIsSelected = self._determineIfALogIsSelected()
                if currALogIsSelected != newALogIsSelected {
                    self.aLogIsSelected = newALogIsSelected
                }
            default:
                NSLog("Unexpected log key path change \(keyPath!)")
            }
        default:
            NSLog("Unexpected object type \(object!)")
        }
    }

    // MARK: - Private
    private func _determineIfALogIsSelected() -> Bool {
        return self.logs.contains{$0.isSelected}
    }

    private func _observeLog(_ log: WBLog) {
        log.addObserver(self, forKeyPath: "isSelected", options: [.initial, .new], context: nil)
    }
    private func _unobserveLog(_ log: WBLog) {
        log.removeObserver(self, forKeyPath: "isSelected")
    }
}
