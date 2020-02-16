//
//  ConsoleLogView.swift
//  BleBrowser
//
//  Created by David Park on 23/09/2018.
//

import UIKit

class ConsoleLogView: UIView {
    @IBOutlet
    var messageTextField: UILabel!

    func configureWithLog(_ log: WBLog) {
        self.messageTextField.text = log.message
        switch log.level {
        case .debug:
            self.messageTextField.textColor = UIColor(displayP3Red: 0.0, green: 0.8, blue: 0.8, alpha: 1.0)
        case .log:
            break
        case .warn:
            self.messageTextField.textColor = UIColor(displayP3Red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)
        case .error:
            self.messageTextField.textColor = UIColor(displayP3Red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        }
    }
}
