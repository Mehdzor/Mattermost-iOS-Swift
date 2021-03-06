//
//  StringUtils.swift
//  Mattermost
//
//  Created by Maxim Gubin on 22/07/16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation

final class StringUtils {
    
    static func emptyString() -> String {
        return ""
    }
    
    static func isEmpty(_ string: String?) -> Bool{
        if let unwrappedString = string {
            return unwrappedString.isEmpty
        }
        return true
    }
    static func isValidLink(_ string: String?) -> Bool {
        let types: NSTextCheckingResult.CheckingType = .link
        let detector = try? NSDataDetector(types: types.rawValue)
        guard let detect = detector else { return false }
        guard let text = string else { return false }
        let matches = detect.matches(in: text, options: .reportCompletion, range: NSMakeRange(0, text.characters.count))
        return matches.count > 0
    }
    
    static func widthOfString(_ string: NSString!, font: UIFont?) -> Float {
        let attributes = [NSFontAttributeName : font!]
        return ceilf(Float(string.size(attributes: attributes).width))
    }
    
    static func heightOfAttributedString(_ attributedString: NSAttributedString!) -> Float {
        let textWidth: CGFloat = UIScreen.screenWidth() - Constants.UI.FeedCellMessageLabelPaddings - Constants.UI.PostStatusViewSize;
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let frame = attributedString.boundingRect(with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude), options: options, context: nil)
        return ceilf(Float(frame.size.height))
    }
    
    static func heightOfString(_ string: String, font: UIFont) -> Float {
        let width: CGFloat = UIScreen.screenWidth() - Constants.UI.FeedCellMessageLabelPaddings - Constants.UI.PostStatusViewSize;
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let frame = string.boundingRect(with: constraintRect, options: options, attributes: [NSFontAttributeName: font], context: nil)
        
        return ceilf(Float(frame.size.height))
    }
    
    static func heightOfString(_ string: String, width: CGFloat, font: UIFont) -> Float {
        //let width: CGFloat = UIScreen.screenWidth() - Constants.UI.FeedCellMessageLabelPaddings - Constants.UI.PostStatusViewSize;
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        let frame = string.boundingRect(with: constraintRect, options: options, attributes: [NSFontAttributeName: font], context: nil)
        
        return ceilf(Float(frame.size.height))
    }
    
    static func randomUUID() -> String {
        let newUniqueId = CFUUIDCreate(kCFAllocatorDefault)
        let uuidString = CFUUIDCreateString(kCFAllocatorDefault, newUniqueId)
        
        return uuidString as! String
    }
    
    static func quotedString(_ string: String!) -> String {
       return "\"" + string + "\""
    }
    
    static func commaTailedString(_ string: String) -> String {
     return (string.characters.count > 0) ? (string + ", ") : string
    }
    
    static func suffixedFor(size: Int) -> String {
            var floatSize = Float(size)
            var pow = 0
            
            while (floatSize / 1024 >= 1) {
                floatSize = floatSize / 1024
                pow += 1
            }
        
            switch (pow) {
            case 0:
                return String(format: "%.1F B", floatSize)
            case 1:
                return String(format: "%.1F KB", floatSize)
            case 2:
                return String(format: "%.1F MB", floatSize)
            case 3:
                return String(format: "%.1F GB", floatSize)
            default:
                return ""
        }
    }
}
