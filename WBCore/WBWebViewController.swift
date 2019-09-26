//
//  WBWebViewController.swift
//  WebBLE
//
//  Created by David Park on 07/09/2019.
//

import UIKit
import WebKit

class WBWebViewController: UIViewController, WKNavigationDelegate {
    class WBLogger: NSObject, WKScriptMessageHandler {

        var manager: WBLogManager! = nil

        // MARK: - WKScriptMessageHandler
        open func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
            ) {
            var log: WBLog
            switch (message.body) {
            case let bodyDict as [String: Any]:
                guard
                    let levelString = bodyDict["level"] as? String,
                    let level = WBLog.Level(rawValue: levelString),
                    let message = bodyDict["message"] as? String
                    else {
                        NSLog("Badly formed dictionary \(bodyDict.description) passed to the logger")
                        return
                }
                log = WBLog(level: level, message: message, args: [])
            case let bodyString as String:
                log = WBLog(level: .log, message: bodyString, args: [])
            default:
                log = WBLog(level: .warn, message: "Unexpected message type from console log: \(message.body)", args: [])
            }
            self.manager.addLog(log)
        }
    }
    let wbLogger = WBLogger()

    var logManager = WBLogManager()

    var webView: WBWebView {
        get {
            return self.view as! WBWebView
        }
    }

    override func viewDidLoad() {
        self.wbLogger.manager = self.logManager
        self.webView.addNavigationDelegate(self)
       // Add logging script
        self.webView.configuration.userContentController.add(
            self.wbLogger, name: "logger"
        )
    }

    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.logManager.clearLogs()
    }
}
