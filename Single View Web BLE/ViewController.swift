//
//  ViewController.swift
//  Single View Web BLE
//
//  Created by David Park on 07/09/2019.
//  Copyright © 2019 David Park. All rights reserved.
//

import UIKit

class SVViewController: UIViewController {
    var WBWebViewContainerController: WBWebViewContainerController {
        get {
            return self.children.first(where: {$0 as? WBWebViewContainerController != nil}) as! WBWebViewContainerController
        }
    }
    var webView: WBWebView {
        get {
            return self.WBWebViewContainerController.webView
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.webView.load(URLRequest(url: URL(
            string: "https://www.greenparksoftware.co.uk"
        )!))
    }
}

