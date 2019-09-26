//
//  WBPopUpPickerController.swift
//  BleBrowser
//
//  Created by David Park on 20/01/2019.
//

import UIKit

// MARK: - Protocols
@objc
protocol WBPopUpPickerViewDelegate: UIPickerViewDelegate, UIPickerViewDataSource {
}

class WBPopUpPickerController: UIViewController {

    // MARK: - Public API
    var wbManager: WBManager!

    // MARK: - IBOutlets and IBActions
    @IBOutlet var pickerView: WBPopUpPickerView!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!

    // MARK: - UIViewController overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        self.pickerView.dataSource = self.wbManager
        self.pickerView.delegate = self.wbManager
        self.pickerView.reloadAllComponents()
    }

    func updatePicker() {
        self.pickerView.reloadAllComponents()
    }

    // MARK: - Private
    let animationDuration: TimeInterval = 0.2
    fileprivate var selectedRows = [Int]()

    private func _animateIntoPlace() {
        UIView.animate(withDuration: self.animationDuration, animations: {
            self.view.superview?.layoutIfNeeded()
        })
    }
    private func _hidePicker() {
        self.bottomConstraint.priority = UILayoutPriority.defaultLow
        self._animateIntoPlace()
    }
    fileprivate func _restoreSelectedRows() {
        for ii in 0 ..< self.selectedRows.count {
            pickerView.selectRow(self.selectedRows[ii], inComponent: ii, animated: true)
        }
    }
}
