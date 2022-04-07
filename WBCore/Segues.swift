//
//  Segues.swift
//  WebBLE
//
//  Created by David Park on 26/09/2019.
//

import UIKit

let DURATION = 0.3

class WBShowPickerSegue: UIStoryboardSegue {
    override func perform() {
        let wvcc = self.source as! WBWebViewContainerController
        let puvc = self.destination as! WBPopUpPickerController
        wvcc.addChild(self.destination)
        wvcc.view.addSubview(self.destination.view)
        let topBotConstraint = wvcc.view.bottomAnchor.constraint(equalTo: puvc.view.topAnchor)
        NSLayoutConstraint.activate([
            wvcc.view.leftAnchor.constraint(equalTo: puvc.view.leftAnchor),
            wvcc.view.rightAnchor.constraint(equalTo: puvc.view.rightAnchor),
            topBotConstraint
            ])
        // inactive initially... activated in the animation block
        wvcc.popUpPickerBottomConstraint = self.source.view.bottomAnchor.constraint(equalTo: self.destination.view.bottomAnchor)
        wvcc.view.layoutIfNeeded()
        UIView.animate(withDuration: DURATION, animations: {
            wvcc.view.removeConstraint(topBotConstraint)
            wvcc.popUpPickerBottomConstraint!.isActive = true
            wvcc.view.layoutIfNeeded()
        })
    }
}

class WBHidePickerSegue: UIStoryboardSegue {
    override func perform() {
        let wvcc = self.destination as! WBWebViewContainerController
        let puvc = self.source as! WBPopUpPickerController
        wvcc.view.removeConstraint(wvcc.popUpPickerBottomConstraint!)
        wvcc.popUpPickerBottomConstraint = nil
        UIView.animate(withDuration: DURATION, animations: {
            wvcc.view.bottomAnchor.constraint(equalTo: puvc.view.topAnchor).isActive = true
            wvcc.view.layoutIfNeeded()
        }, completion: {
            _ in
            puvc.removeFromParent()
            puvc.view.removeFromSuperview()
        })
    }
}

class ViewControllerToConsoleSegue: UIStoryboardSegue {
    override func perform() {
        let vc = self.source as! ViewController
        let view = vc.view!
        let consoleController = self.destination as! ConsoleViewContainerController
        let consoleView = consoleController.view!

        vc.addChild(consoleController)
        view.addSubview(consoleView)

        consoleController.wbLogManager = vc.webViewController.logManager

        NSLayoutConstraint.activate([
            consoleView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            consoleView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            consoleView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            // ensure we do not enlarge the console above the url bar,
            // this is something of a hack
            consoleView.topAnchor.constraint(
                greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 60.0
            ),

            // this constraint will override the existing constraint pinning the bottom of the web view's container to the bottom of the safe area
            consoleView.topAnchor.constraint(
                equalTo: vc.webViewContainerController.view.subviews.first!.bottomAnchor
            ),
        ])
        UserDefaults.standard.setValue(true, forKey: ViewController.prefKeys.consoleOpen.rawValue)
    }
}
