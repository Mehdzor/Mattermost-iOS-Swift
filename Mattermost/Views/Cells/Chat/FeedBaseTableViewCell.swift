//
//  ChatBaseTableViewCell.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 26.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

protocol FeedTableViewCellProtocol : class, MattermostTableViewCellProtocol {
    var onMentionTap: ((nickname : String) -> Void)? { get set }
    var post : Post? { get set }
    
    static var messageQueue : NSOperationQueue {get set}
    func configureWithPost(post: Post) -> Void
    static func heightWithPost(post: Post) -> CGFloat
}
//
//если нужна реализация
extension FeedTableViewCellProtocol {
}