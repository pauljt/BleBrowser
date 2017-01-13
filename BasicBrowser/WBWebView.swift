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

        let debug = false

        open func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if self.debug {
                NSLog("WKLog: \(message.body)")
            }
        }
    }
    let wkLogger = WKLogger()
    @IBOutlet var devicePicker: PopUpPickerView!

    let webBluetoothHandlerName = "bluetooth"
    private var _wbManager: WBManager?
    var wbManager: WBManager? {
        get {
            return self._wbManager
        }
        set(newWBManager) {
            if self._wbManager != nil {
                self.configuration.userContentController.removeScriptMessageHandler(forName: self.webBluetoothHandlerName)
            }
            self._wbManager = newWBManager
            self.devicePicker.delegate = newWBManager
            if let newMan = newWBManager {
                self.configuration.userContentController.add(newMan, name: self.webBluetoothHandlerName)
                newMan.devicePicker = self.devicePicker
            }
        }
    }

    required public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
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

        // add the bluetooth script prior to loading all frames
        let userScript = WKUserScript(
            source: script, injectionTime: .atDocumentStart,
            forMainFrameOnly: false)
        userController.addUserScript(userScript)

        self.translatesAutoresizingMaskIntoConstraints = false
        self.allowsBackForwardNavigationGestures = true
    }
}
