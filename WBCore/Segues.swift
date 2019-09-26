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
        wvcc.addChildViewController(self.destination)
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
            puvc.removeFromParentViewController()
            puvc.view.removeFromSuperview()
        })
    }
}
