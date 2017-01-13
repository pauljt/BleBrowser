// from https://github.com/tottokotkd/PopUpPickerView

import UIKit

class PopUpPickerView: UIView {

    let animationDuration: TimeInterval = 0.2

    @IBOutlet var bottomConstraint: NSLayoutConstraint!
    @IBOutlet var pickerView: UIPickerView! {
        didSet {
            self.configureDelegates()
        }
    }
    @IBOutlet var cancelButton: UIBarButtonItem! {
        didSet {
            if self.cancelButton != nil {
                self.cancelButton.target = self
                self.cancelButton.action = #selector(PopUpPickerView.cancelPicker)
            }
        }
    }
    @IBOutlet var doneButton: UIBarButtonItem! {
        didSet {
            if let doneButton = self.doneButton {
                doneButton.target = self
                doneButton.action = #selector(PopUpPickerView.endPicker)
            }
        }
    }

    var delegate: PopUpPickerViewDelegate? {
        didSet {
            self.configureDelegates()
        }
    }
    fileprivate var selectedRows = [Int]()


    // MARK: - Manipulate the picker into and out of the view
    func showPicker() {
        self.selectedRows = self.getSelectedRows()
        self.bottomConstraint.constant = 0
        self._animateIntoPlace()
    }
    func cancelPicker() {
        self.hidePicker()
        self.restoreSelectedRows()
        self.delegate?.pickerViewCancelled?(self.pickerView)
    }
    func endPicker() {
        self.hidePicker()
        self.delegate?.pickerView?(self.pickerView, didSelect: self.getSelectedRows())
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
    private func _animateIntoPlace() {
        UIView.animate(withDuration: self.animationDuration, animations: {
            self.superview?.layoutIfNeeded()
        })
    }

    private func configureDelegates() {
        self.pickerView?.delegate = self.delegate
    }

    fileprivate func hidePicker() {
        self.bottomConstraint.constant = -self.frame.height
        self._animateIntoPlace()
    }
    fileprivate func getSelectedRows() -> [Int] {
        var selectedRows = [Int]()
        for ii in 0 ..< pickerView.numberOfComponents {
            selectedRows.append(pickerView.selectedRow(inComponent: ii))
        }
        return selectedRows
    }
    fileprivate func restoreSelectedRows() {
        for ii in 0 ..< self.selectedRows.count {
            pickerView.selectRow(self.selectedRows[ii], inComponent: ii, animated: true)
        }
    }
}

// MARK: - Delegate Protocol

@objc
protocol PopUpPickerViewDelegate: UIPickerViewDelegate, UIPickerViewDataSource {
    @objc optional func pickerView(_ pickerView: UIPickerView, didSelect numbers: [Int])
    @objc optional func pickerViewCancelled(_ pickerView: UIPickerView)
    @objc var numberOfItems: Int { get }
}
