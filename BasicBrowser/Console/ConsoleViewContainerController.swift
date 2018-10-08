//
//  ConsoleViewContainerController.swift
//  BleBrowser
//
//  Created by David Park on 06/10/2018.
//

import UIKit

class ConsoleViewContainerController: UIViewController {

    @IBOutlet var scrollView: UIView!

    @IBOutlet var consoleScrollViewHeightConstraint: NSLayoutConstraint!
    var consoleScrollViewHeightAtStartOfGesture: CGFloat? = nil

    @IBAction func dividerDrag(_ sender: UIPanGestureRecognizer) {
        let yTranslation = sender.translation(in: sender.view).y
        let gestureState = sender.state
        switch gestureState {
        case .began:
            // this to reset the height if we've had a screen rotation since last height set
            self.consoleScrollViewHeightConstraint.constant = self.scrollView.frame.height
            self.consoleScrollViewHeightAtStartOfGesture = self.consoleScrollViewHeightConstraint.constant
        case .changed: self.consoleScrollViewHeightConstraint.constant = self.consoleScrollViewHeightAtStartOfGesture! - yTranslation
        case .ended:
            NSLog("dragEnd \(self.view.frame.height) \(self.consoleScrollViewHeightConstraint.constant)")
            self.consoleScrollViewHeightAtStartOfGesture = nil
            self.consoleScrollViewHeightConstraint.constant = self.scrollView.frame.height
            UserDefaults.standard.setValue(
                self.consoleScrollViewHeightConstraint.constant, forKey: "lastConsoleHeight"
            )
        default: NSLog("Unexpected gesture state \(gestureState)")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let prevHeight = CGFloat(UserDefaults.standard.float(forKey: "lastConsoleHeight"))

        self.consoleScrollViewHeightConstraint.constant = prevHeight > 0.0 ? prevHeight : 100.0
    }
}
