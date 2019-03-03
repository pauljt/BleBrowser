//
//  PopUpPickerController.swift
//  BleBrowser
//
//  Created by David Park on 20/01/2019.
//

import UIKit

// MARK: - Protocols
@objc
protocol PopUpPickerViewDelegate: UIPickerViewDelegate, UIPickerViewDataSource {
    @objc optional func pickerView(_ pickerView: UIPickerView, didSelect numbers: [Int])
    @objc optional func pickerViewCancelled(_ pickerView: UIPickerView)
    @objc var numberOfItems: Int { get }
}

class PopUpPickerController: UIViewController, WBPicker {

    // MARK: - Public API
    var delegate: PopUpPickerViewDelegate?

    // MARK: - IBOutlets and IBActions
    @IBOutlet var doneButton: UIButton!
    @IBOutlet var pickerView: UIPickerView!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBAction func endPicker() {
        // TRY gestureRecognizerShouldBegin
        self._hidePicker()
        self.delegate?.pickerView?(self.pickerView, didSelect: self._getSelectedRows())
    }
    @IBAction func cancelPicker() {
        self._hidePicker()
        self._restoreSelectedRows()
        self.delegate?.pickerViewCancelled?(self.pickerView)
    }

    // MARK: - WBPicker protocol
    func showPicker() {
        self.selectedRows = self._getSelectedRows()
        self.bottomConstraint.priority = UILayoutPriority.defaultHigh
        self._animateIntoPlace()
        self.pickerView.dataSource = self.delegate
        self.pickerView.delegate = self.delegate
    }

    func updatePicker() {
        if let numDevices = self.delegate?.numberOfItems,
            numDevices > 0 {
            self.doneButton.isEnabled = true
        }
        else {
            self.doneButton.isEnabled = false
        }
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
    fileprivate func _getSelectedRows() -> [Int] {
        var selectedRows = [Int]()
        for ii in 0 ..< pickerView.numberOfComponents {
            selectedRows.append(pickerView.selectedRow(inComponent: ii))
        }
        return selectedRows
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
