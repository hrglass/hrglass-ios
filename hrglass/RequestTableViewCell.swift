//
//  RequestTableViewCell.swift
//  hrglass
//
//  Created by Justin Hershey on 8/1/17.
//
//

import UIKit

class RequestTableViewCell: UITableViewCell {

    @IBOutlet weak var acceptBtn: UIButton!
    
    @IBOutlet weak var nameLbl: UILabel!
    
    @IBOutlet weak var profImageView: UIImageView!
    
    var acceptBtnSelected: (() -> Void)? = nil
    
    @IBAction func acceptBtnAction(_ sender: Any) {
        
        if let acceptBtnAction = self.acceptBtnSelected{
            
            acceptBtnAction()
            
        }
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        self.profImageView.layer.cornerRadius = self.profImageView.frame.height/2
        self.profImageView.clipsToBounds = true
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
