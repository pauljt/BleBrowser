//
//  WBWebView.swift
//  BleBrowser
//
//  Created by David Park on 22/12/2016.
//  Copyright © 2016 Stefan Arentz. All rights reserved.
//

import Foundation
import UIKit
import WebKit

open class WBWebView: WKWebView {

    class WKLogger: NSObject, WKScriptMessageHandler {
        open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            NSLog("WKLog: \(message.body)")
        }
    }
    let wkLogger = WKLogger()
    let devicePicker = PopUpPickerView()

    required public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        NSLog("WBWebView init frame \(frame)")
        super.init(frame: frame, configuration: configuration)
    }

    convenience public required init?(coder: NSCoder) {
        // load polyfill script
        let webCfg = WKWebViewConfiguration()
        let userController = WKUserContentController()
        webCfg.userContentController = userController
        self.init(
            frame: CGRect(),
            configuration:webCfg
        )

        guard let filePath = Bundle(for: WBWebView.self).path(forResource: "WBPolyfill", ofType:"js") else {
            NSLog("Failed to find polyfill.")
            return
        }

        var script: String
        do {
            script = try NSString(contentsOfFile: filePath, encoding: String.Encoding.utf8.rawValue) as String
        } catch _ {
            print("Error loading polyfil")
            return
        }

        // TODO: this probably should be more controllable.
        // Before configuring the WKWebView, delete caches since
        // it seems a bit arbitrary when this happens otherwise.
        // This from http://stackoverflow.com/a/34376943/5920499
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]) as! Set<String>
        WKWebsiteDataStore.default().removeData(
            ofTypes: websiteDataTypes,
            modifiedSince: NSDate(timeIntervalSince1970: 0) as Date,
            completionHandler:{})

        userController.add(self.wkLogger, name: "logger")
        self.addSubview(devicePicker)

        // add the bluetooth script prior to loading all frames
        let userScript = WKUserScript(
            source: script, injectionTime: .atDocumentStart,
            forMainFrameOnly: false)
        userController.addUserScript(userScript)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.allowsBackForwardNavigationGestures = true
    }
}
