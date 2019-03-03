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
    var logViews: [ConsoleLogView] = []

    func insertLogView(_ view: ConsoleLogView, at index: Int) {
        self.addSubview(view)
        self.logViews.insert(view, at: index)
        for (anch1, anch2) in [
            (self.leftAnchor, view.leftAnchor),
            (self.rightAnchor, view.rightAnchor)
        ] {
            anch1.constraint(equalTo: anch2).isActive = true
        }

        let svCount = self.logViews.count
        let lastIndex = svCount - 1
        switch index {
        case 0:
            if svCount == 1 {
                self.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            } else {
                let viewBelow = self.logViews[1]
                let prevConstraints = self.constraints.filter({
                    $0.secondAttribute == .top &&
                    $0.secondItem ?? nil === viewBelow
                })
                assert(prevConstraints.count > 0)
                NSLayoutConstraint.deactivate(prevConstraints)
            }
            self.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        case 1..<lastIndex:
            let viewAbove = self.logViews[index - 1]
            let viewBelow = self.logViews[index + 1]
            let prevConstraints = viewAbove.constraints.filter({
                $0.secondItem ?? nil === viewBelow &&
                $0.secondAttribute == .bottom
            })
            assert(prevConstraints.count > 0)
            NSLayoutConstraint.deactivate(prevConstraints)
            viewAbove.bottomAnchor.constraint(equalTo: view.topAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: viewBelow.topAnchor).isActive = true
        case lastIndex:
            let viewAbove = self.logViews[index - 1]
            let prevConstraints = self.constraints.filter({
                $0.secondItem === viewAbove &&
                $0.secondAttribute == .bottom
            })
            assert(prevConstraints.count > 0)
            NSLayoutConstraint.deactivate(prevConstraints)
            self.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
            viewAbove.bottomAnchor.constraint(equalTo: view.topAnchor).isActive = true
        default:
            assert(false, "Invalid index \(index)")
        }
    }

    func removeAllLogViews() {
        self.logViews.forEach{$0.removeFromSuperview()}
        self.logViews.removeAll()
    }
}
