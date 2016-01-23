// from https://github.com/tottokotkd/PopUpPickerView

import UIKit

class PopUpPickerView: UIView {
    var pickerView: UIPickerView!
    var pickerToolbar: UIToolbar!
    var toolbarItems: [UIBarButtonItem]!
    
    var delegate: PopUpPickerViewDelegate? {
        didSet {
            pickerView.delegate = delegate
        }
    }
    private var selectedRows: [Int]?
    
    // MARK: Initializer

    override init(frame: CGRect) {
        super.init(frame: frame)
        initFunc()
    }
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        initFunc()
    }
    private func initFunc() {
        let screenSize = UIScreen.mainScreen().bounds.size
        self.backgroundColor = UIColor.blackColor()
        
        pickerToolbar = UIToolbar()
        pickerView = UIPickerView()
        toolbarItems = []
        
        pickerToolbar.translucent = true
        pickerView.showsSelectionIndicator = true
        pickerView.backgroundColor = UIColor.whiteColor()
        
        self.bounds = CGRectMake(0, 0, screenSize.width, 260)
        self.frame = CGRectMake(0, screenSize.height, screenSize.width, 260)
        pickerToolbar.bounds = CGRectMake(0, 0, screenSize.width, 44)
        pickerToolbar.frame = CGRectMake(0, 0, screenSize.width, 44)
        pickerView.bounds = CGRectMake(0, 0, screenSize.width, 216)
        pickerView.frame = CGRectMake(0, 44, screenSize.width, 216)
        
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FixedSpace, target: nil, action: nil)
        space.width = 12
        let cancelItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Cancel, target: self, action: "cancelPicker")
        let flexSpaceItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.FlexibleSpace, target: self, action: nil)
        let doneButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: Selector("endPicker"))
        toolbarItems! += [space, cancelItem, flexSpaceItem, doneButtonItem, space]
        
        pickerToolbar.setItems(toolbarItems, animated: false)
        self.addSubview(pickerToolbar)
        self.addSubview(pickerView)
    }
    func showPicker() {
        if selectedRows == nil {
            selectedRows = getSelectedRows()
        }
        let screenSize = UIScreen.mainScreen().bounds.size
        UIView.animateWithDuration(0.2) {
            self.frame = CGRectMake(0, screenSize.height - 260.0, screenSize.width, 260.0)
        }
    }
    func cancelPicker() {
        hidePicker()
        restoreSelectedRows()
        selectedRows = nil
    }
    func endPicker() {
        hidePicker()
        delegate?.pickerView?(pickerView, didSelect: getSelectedRows())
        selectedRows = nil
    }
    
    func updatePicker() {
        pickerView.reloadAllComponents()
    }
    
    private func hidePicker() {
        let screenSize = UIScreen.mainScreen().bounds.size
        UIView.animateWithDuration(0.2) {
            self.frame = CGRectMake(0, screenSize.height, screenSize.width, 260.0)
        }
    }
    private func getSelectedRows() -> [Int] {
        var selectedRows = [Int]()
        for i in 0..<pickerView.numberOfComponents {
            selectedRows.append(pickerView.selectedRowInComponent(i))
        }
        return selectedRows
    }
    private func restoreSelectedRows() {
        for i in 0..<selectedRows!.count {
            pickerView.selectRow(selectedRows![i], inComponent: i, animated: true)
        }
    }
}

@objc
protocol PopUpPickerViewDelegate: UIPickerViewDelegate {
    optional func pickerView(pickerView: UIPickerView, didSelect numbers: [Int])
}
