//
//  WBTransaction.swift
//  BleBrowser
//
//  Copyright 2016-2017 David Park. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import CoreBluetooth
import WebKit


class WBTransactionManager<K> where K: Hashable {
    var transactions = [K: [WBTransaction]]()

    func abandonAll() {
        for (_, ta) in self.transactions {
            for tr in ta {
                tr.abandon()
            }
        }
        self.transactions.removeAll()
    }
    func addTransaction(_ transaction: WBTransaction, atPath path: K) {
        // note that adding a transaction automatically registers a completion handler that will remove the transaction from the manager
        var ts = self.transactions[path] ?? []
        ts.append(transaction)
        self.transactions[path] = ts
        transaction.addCompletionHandler {
            _, _ in
            self.removeTransaction(transaction, atPath: path)
        }
    }
    func apply(_ function: (WBTransaction) -> Void, iff: ((WBTransaction) -> Bool)? = nil) {
        // Rather than using this everywhere with an iff we should in many places probably do tm.transaction[key].forEach(function)
        for (_, vals) in self.transactions {
            for val in vals {
                if let iff_ = iff, !iff_(val) {
                    continue
                }
                function(val)
            }
        }
    }
    func apply(_ function: (WBTransaction) -> Void) {
        self.apply(function, iff: nil)
    }
    func removeTransaction(_ transaction: WBTransaction, atPath path: K) {
        if var ts = self.transactions[path] {
            if let ind = ts.firstIndex(of: transaction) {
                ts.remove(at: ind)
                self.transactions[path] = ts
            }
        }
    }
}

class WBTransaction: Equatable, CustomStringConvertible {

    /*
     * ========== Embedded types ==========
     */
    struct Key: Hashable, CustomStringConvertible {
        let typeComponents: [String]

        var hashValue: Int {
            var hash: Int = 0
            for tc in self.typeComponents {
                hash ^= tc.hashValue
            }
            return hash
        }

        var description: String {
            let contents = self.typeComponents.reduce("") {
                (progress: String, next: String) in
                if (progress.isEmpty) {
                    return next
                } else {
                    return "\(progress):\(next)"
                }
            }
            return contents
        }

        static func == (left: Key, right: Key) -> Bool {
            guard left.typeComponents.count == right.typeComponents.count else {
                return false;
            }
            for (lstr, rstr) in zip(left.typeComponents, right.typeComponents) {
                if (lstr != rstr) {
                    return false
                }
            }
            return true
        }
    }
    class View {
        let transaction: WBTransaction

        /*! @abstract Failable initializer so that subclasses may decide not to accept the transaction. */
        init? (transaction: WBTransaction) {
            self.transaction = transaction
        }
    }

    /*
     * ========== Properties ==========
     */
    /*! @abstract The unique ID for this transaction which is provided for us by the web page */
    let id: Int
    let key: Key
    let messageData: [String: AnyObject]
    /*! @abstract The web view that initiated this transaction, and where we can send the response.
     */
    weak var webView: WKWebView?
    var completionHandlers = [(WBTransaction, Bool) -> Void]()
    var resolved: Bool = false

    var sourceURL: URL? {
        return self.webView?.url
    }
    
    /*
     * ========== Initializers ==========
     */
    init(id: Int, typeComponents: [String], messageData: [String: AnyObject], webView: WKWebView?){
        self.id = id
        self.key = Key(typeComponents: typeComponents)
        self.messageData = messageData
        self.webView = webView
    }
    convenience init?(withMessage message: WKScriptMessage) {

        guard
            let messageBody = message.body as? NSDictionary,
            let id = messageBody["callbackID"] as? Int,
            let typeString = messageBody["type"] as? String,
            let messageData = messageBody["data"] as? [String: AnyObject] else {
                NSLog("Bad WebKit request received \(message.body)")
                message.webView?.evaluateJavaScript(
                    "receiveMessage('badrequest');",
                    completionHandler: nil)
                return nil
        }
        let typeComponents = typeString.components(separatedBy: ":")
        self.init(id: id, typeComponents: typeComponents, messageData: messageData, webView: message.webView)
    }

    /*
     * ========== Public methods ==========
     */
    /*! @abstract Abandon the transaction and release all completion handlers. */
    func abandon() {
        self.completionHandlers = []
        self.resolved = true
    }
    func addCompletionHandler(_ handler: @escaping (WBTransaction, Bool) -> Void) {
        self.completionHandlers.append(handler)
    }
    func resolveAsSuccess(withMessage message: String = "Success") {
        self.complete(success: true, object: message)
    }
    func resolveAsSuccess(withObject object: Jsonifiable) {
        self.complete(success: true, object: object)
    }
    func resolveAsFailure(withMessage message: String) {
        self.complete(success: false, object: message)
    }

    static func == (lhs: WBTransaction, rhs: WBTransaction) -> Bool {
        return lhs.id == rhs.id
    }

    /*
     * ========== CustomStringConvertible ==========
     */
    var description: String {
        return "Transaction(id: \(self.id), key: \(self.key))"
    }

    /*
     * ========== Private methods ==========
     */
    private func complete(success: Bool, object: Jsonifiable) {
        if self.resolved {
            NSLog("Attempt to re-resolve transaction \(self.id) ignored")
            return
        }

        let commandString = "window.receiveMessageResponse(\(success ? "true" : "false"), \(object.jsonify()), \(self.id));\n"
        NSLog("\(self.description) was \(success ? "successful" : "unsuccessful")")

        if let wv = self.webView {
            wv.evaluateJavaScript(commandString, completionHandler: {
                _, error in
                if let err = error {
                    NSLog("Error evaluating javascript: \(err)")
                }})
        }
        else {
            NSLog("ERROR: Webview not configured on transaction or dealloced")
        }
        self.resolved = true
        self.completionHandlers.forEach {$0(self, success)}
        self.completionHandlers.removeAll()
    }
}

