//
//  CheckBox.swift
//  hrglass
//
//  Created by Justin Hershey on 1/25/18.
//

import UIKit

protocol CheckBoxDelegate: class {
    func didPress(sender: CheckBox)
}


class CheckBox: UIButton {
    
    // Images
    weak var delegate: CheckBoxDelegate?
    let checkedImage = UIImage(named: "whiteCheckboxChecked")! as UIImage
    let uncheckedImage = UIImage(named: "whiteCheckboxUnchecked")! as UIImage
    
    // Bool property
    var isChecked: Bool = false {
        didSet{
            delegate?.didPress(sender: self)
            if isChecked == true {
                self.setImage(checkedImage, for: UIControlState.normal)
            } else {
                self.setImage(uncheckedImage, for: UIControlState.normal)
            }
        }
    }
    
    override func awakeFromNib() {
        self.addTarget(self, action:#selector(buttonClicked(sender:)), for: UIControlEvents.touchUpInside)
        self.isChecked = false
    }
    
    @objc func buttonClicked(sender: UIButton) {
        if sender == self {
            isChecked = !isChecked
        }
    }
}
