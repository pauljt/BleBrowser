//
//  WBPopUpPickerView.swift
//  WebBLE
//
//  Created by David Park on 26/09/2019.
//

import UIKit

class WBPopUpPickerView: UIPickerView {
    
    @IBOutlet var doneButton: UIButton!
    
    // MARK: - Overridden methods
    override func reloadAllComponents() {
        super.reloadAllComponents()
        if self.numberOfRows > 0 {
            self.doneButton.isEnabled = true
        } else {
            self.doneButton.isEnabled = false
        }
    }
    
    // MARK: - Convenience methods
    var numberOfRows: Int {
        get {
            guard let ds = self.dataSource else {
                return 0
            }
            return ds.pickerView(self, numberOfRowsInComponent: 0)
        }
    }
    var selectedRow: Int {
        return self.selectedRow(inComponent: 0)
    }
}
