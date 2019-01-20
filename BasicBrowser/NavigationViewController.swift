//
//  NavigationViewController.swift
//  BleBrowser
//
//  Created by David Park on 13/01/2019.
//

import UIKit

protocol WBNavigationBarDelegate {
    func navBarIsHiddenDidChange(_ hidden: Bool)
}

class NavigationViewController: UINavigationController {

    var navigationBarDelegate: WBNavigationBarDelegate?

    override var isNavigationBarHidden: Bool {
        set (isHidden) {
            super.isNavigationBarHidden = isHidden
        }
        get {
            return super.isNavigationBarHidden
        }
    }

    override func setNavigationBarHidden(_ hidden: Bool, animated: Bool) {
        super.setNavigationBarHidden(hidden, animated: animated)
        self.navigationBarDelegate?.navBarIsHiddenDidChange(hidden)
    }
}
