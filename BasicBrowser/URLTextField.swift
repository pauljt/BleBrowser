//
//  URLTextField.swift
//  WebBLE
//
//  Created by David Park on 08/04/2022.
//

import UIKit

class URLTextField: UITextField {
    var alreadyWasFirstResponder = false
    var superViewConstraints: [NSLayoutConstraint] = []

    override func becomeFirstResponder() -> Bool {
        let answer = super.becomeFirstResponder()
        if !self.alreadyWasFirstResponder {
            self.alreadyWasFirstResponder = true
            self.selectAll(nil)
        }
        return answer
    }
    override func resignFirstResponder() -> Bool {
        let answer = super.resignFirstResponder()
        self.alreadyWasFirstResponder = false
        return answer
    }

    override func didMoveToSuperview() {
        if self.superViewConstraints.count > 0 {
            NSLayoutConstraint.deactivate(self.superViewConstraints)
            // don't necessarily delete them:
            // we may be able to reuse them
        }

        if let sv = self.superview {
            if self.superViewConstraints.count == 0
                || self.superViewConstraints[0].secondItem as? UIView != sv {
                // need new constraints
                self.superViewConstraints = [
                    self.leadingAnchor.constraint(equalTo: sv.leadingAnchor, constant: 8),

                    self.trailingAnchor.constraint(equalTo: sv.trailingAnchor, constant: -8),
                ]
            }
            NSLayoutConstraint.activate(self.superViewConstraints)
        }
    }
}
