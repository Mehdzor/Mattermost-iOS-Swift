//
//  FeedFollowUpTableViewCell.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 27.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//


final class FeedFollowUpTableViewCell: FeedBaseTableViewCell {
    override func layoutSubviews() {
        guard self.post != nil else {
            return
        }
        let textWidth = UIScreen.screenWidth() - Constants.UI.FeedCellMessageLabelPaddings - Constants.UI.PostStatusViewSize
        self.messageLabel.frame = CGRect(x: 53, y: 8, width: textWidth, height: CGFloat(self.post.attributedMessageHeight))
        super.layoutSubviews()
    }
}

extension FeedFollowUpTableViewCell: TableViewPostDataSource {
    override class func heightWithPost(_ post: Post) -> CGFloat {
        return CGFloat(post.attributedMessageHeight) + 16
    }
}
