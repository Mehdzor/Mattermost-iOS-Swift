//
//  HeaderChannelSettingsCell.swift
//  Mattermost
//
//  Created by Владислав on 10.11.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import UIKit
//Нужен ли ксиб?
class HeaderChannelSettingsCell: UITableViewCell {

    @IBOutlet weak var channelImage: UIImageView!
    @IBOutlet weak var channelName: UILabel!
    @IBOutlet weak var channelFirstSymbol: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        channelImage.layer.cornerRadius = 30.0
        channelImage.clipsToBounds = true
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        self.contentView.backgroundColor = .white
        // Configure the view for the selected state
    }

}
