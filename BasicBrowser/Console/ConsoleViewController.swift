//
//  ConsoleViewController.swift
//  BleBrowser
//
//  Created by David Park on 18/09/2018.
//  Copyright © 2018 David Park. All rights reserved.
//

import UIKit

class ConsoleViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

//        let vcs = self.view.constraintsAffectingLayout(for: .vertical)
//        NSLayoutConstraint.deactivate(vcs)

        for sv in self.view.subviews {
            sv.removeFromSuperview()
        }
        self.addLog(message: "Hello world")
        self.addLog(message: "How's it hanging?")
        self.addLog(message: "Sounds great!")
        self.addLog(message: "How about one more...")
        self.addLog(message: "for luck!")
        self.addLog(message: "Also interesting to know what happens when we put a long one in that will clearly run off the edge of the screen")
    }

    func addLog(message: String) {
        NSLog("addLog \(message)")
        let clvc: ConsoleLogViewController = ConsoleLogViewController(nibName: "ConsoleLogView", bundle: nil)
        NSLog("nib loaded: \(clvc) \(clvc.view ?? nil)")
        let clv = clvc.view as! ConsoleLogView
        clv.messageTextField?.text = message
        self.view.addSubview(clv)
        
    }

    // MARK: - Event handling
    @IBAction
    @objc public func showConsole() {
        NSLog("Showing console")
    }
}
