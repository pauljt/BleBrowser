//
//  URLTextField.swift
//  WebBLE
//
//  Created by David Park on 08/04/2022.
//

import UIKit

class URLTextField: UITextField {
    var alreadyWasFirstResponder = false

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
}
