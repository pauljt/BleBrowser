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
    fileprivate var selectedRows: [Int]?
    
    // MARK: Initializer

    override init(frame: CGRect) {
        super.init(frame: frame)
        initFunc()
    }
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
        initFunc()
    }
    fileprivate func initFunc() {
        let screenSize = UIScreen.main.bounds.size
        self.backgroundColor = UIColor.black
        
        pickerToolbar = UIToolbar()
        pickerView = UIPickerView()
        toolbarItems = []
        
        pickerToolbar.isTranslucent = true
        pickerView.showsSelectionIndicator = true
        pickerView.backgroundColor = UIColor.white
        
        self.bounds = CGRect(x: 0, y: 0, width: screenSize.width, height: 260)
        self.frame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: 260)
        pickerToolbar.bounds = CGRect(x: 0, y: 0, width: screenSize.width, height: 44)
        pickerToolbar.frame = CGRect(x: 0, y: 0, width: screenSize.width, height: 44)
        pickerView.bounds = CGRect(x: 0, y: 0, width: screenSize.width, height: 216)
        pickerView.frame = CGRect(x: 0, y: 44, width: screenSize.width, height: 216)
        
        let space = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.fixedSpace, target: nil, action: nil)
        space.width = 12
        let cancelItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(PopUpPickerView.cancelPicker))
        let flexSpaceItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: self, action: nil)
        let doneButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(PopUpPickerView.endPicker))
        toolbarItems! += [space, cancelItem, flexSpaceItem, doneButtonItem, space]
        
        pickerToolbar.setItems(toolbarItems, animated: false)
        self.addSubview(pickerToolbar)
        self.addSubview(pickerView)
    }
    func showPicker() {
        if selectedRows == nil {
            selectedRows = getSelectedRows()
        }
        let screenSize = UIScreen.main.bounds.size
        UIView.animate(withDuration: 0.2, animations: {
            self.frame = CGRect(x: 0, y: screenSize.height - 260.0, width: screenSize.width, height: 260.0)
        }) 
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
    
    fileprivate func hidePicker() {
        let screenSize = UIScreen.main.bounds.size
        UIView.animate(withDuration: 0.2, animations: {
            self.frame = CGRect(x: 0, y: screenSize.height, width: screenSize.width, height: 260.0)
        }) 
    }
    fileprivate func getSelectedRows() -> [Int] {
        var selectedRows = [Int]()
        for i in 0..<pickerView.numberOfComponents {
            selectedRows.append(pickerView.selectedRow(inComponent: i))
        }
        return selectedRows
    }
    fileprivate func restoreSelectedRows() {
        for i in 0..<selectedRows!.count {
            pickerView.selectRow(selectedRows![i], inComponent: i, animated: true)
        }
    }
}

@objc
protocol PopUpPickerViewDelegate: UIPickerViewDelegate {
    @objc optional func pickerView(_ pickerView: UIPickerView, didSelect numbers: [Int])
}
