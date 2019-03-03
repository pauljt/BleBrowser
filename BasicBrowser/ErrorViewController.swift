//
//  ErrorViewController.swift
//  BleBrowser
//
//  Created by David Park on 19/02/2019.
//

import UIKit

class ErrorViewController: UIViewController {
    @IBOutlet var messageField: UILabel!

    var errorMessage = "<Unset message>"

    override func viewDidLoad() {
        super.viewDidLoad()
        self.messageField.text = self.errorMessage
    }
}
