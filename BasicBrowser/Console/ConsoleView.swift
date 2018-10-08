//
//  ConsoleView.swift
//  BleBrowser
//
//  Created by David Park on 23/09/2018.
//  Copyright © 2018 David Park. All rights reserved.
//

import UIKit

class ConsoleView: UIView {
    var topLayoutConstraint: NSLayoutConstraint?
    var bottomLayoutConstraint: NSLayoutConstraint?

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        guard let logView = view as? ConsoleLogView else {
            return
        }
        if self.topLayoutConstraint == nil {
            let tlc = NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: logView, attribute: .top, multiplier: 1.0, constant: 0.0)
            self.topLayoutConstraint = tlc
            NSLayoutConstraint.activate([tlc])
        }

        if self.subviews.count > 1 {
            let lastSV = self.subviews[self.subviews.count - 2]
            let lastLC = NSLayoutConstraint(item: lastSV, attribute: .bottom, relatedBy: .equal, toItem: logView, attribute: .top, multiplier: 1.0, constant: 0.0)
            NSLayoutConstraint.activate([lastLC])
        }

        if let blc = self.bottomLayoutConstraint {
            NSLayoutConstraint.deactivate([blc])
        }
        let blc = NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: logView, attribute: .bottom, multiplier: 1.0, constant: 0.0)
        NSLayoutConstraint.activate([blc])
        self.bottomLayoutConstraint = blc
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: logView, attribute: .width, multiplier: 1.0, constant: 0.0)
            ])
    }
}
