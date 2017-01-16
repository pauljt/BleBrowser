//
//  Animations.swift
//  BleBrowser
//
//  Created by David Park on 16/01/2017.
//  Copyright © 2017 David Park. All rights reserved.
//

import UIKit

struct FlashAnimation {

    let view: UIView

    var fadeInDuration: TimeInterval = 0.05
    var fadeOutDuration: TimeInterval = 0.2
    var lingerDuration: TimeInterval = 1.0

    init(withView view: UIView) {
        self.view = view
    }
    func go() {

        guard let sv = self.view.superview else {
            NSLog("Unable to do flash animation on \(self.view) as it has no superview")
            return
        }

        UIView.transition(with: sv, duration: self.fadeInDuration, options: UIViewAnimationOptions.transitionCrossDissolve, animations: {self.view.isHidden = false}, completion: {
            _ in
            Timer.scheduledTimer(withTimeInterval: self.lingerDuration, repeats: false, block: {
                _ in
                UIView.transition(with: sv, duration: self.fadeOutDuration, options: UIViewAnimationOptions.transitionCrossDissolve, animations: {
                        self.view.isHidden = true
                })
            })
        })
    }
}
