//
//  UIImage+Additions.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 26.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//
import Foundation

extension UIImage {
    class func roundedImageOfSize(_ sourceImage: UIImage, size: CGSize) -> UIImage {
        let frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        let context = UIGraphicsGetCurrentContext()
        UIColor.white.setFill()
        context?.fill(frame);
        UIBezierPath(roundedRect: frame, cornerRadius: ceil(size.width / 2)).addClip()
        sourceImage.draw(in: frame)
        
        let result = UIGraphicsGetImageFromCurrentImageContext()! as UIImage;
        UIGraphicsEndImageContext();
        
        return result;
    }
    
    @nonobjc static let sharedFeedSystemAvatar = UIImage.feedSystemAvatar()
    
    @nonobjc static let sharedAvatarPlaceholder = UIImage.avatarPlaceholder()
    
    fileprivate static func feedSystemAvatar() -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40) as CGRect
        let bundleImage = UIImage(named: "feed_system_avatar")
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0);
        let context = UIGraphicsGetCurrentContext()
        UIColor.white.setFill()
        context?.fill(rect)
        bundleImage?.draw(in: rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()! as UIImage;
        UIGraphicsEndImageContext()
        return image
    }
    
    fileprivate static func avatarPlaceholder() -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 40, height: 40) as CGRect
        UIGraphicsBeginImageContextWithOptions(rect.size, true, 0)
        let context = UIGraphicsGetCurrentContext()
        let ref = UIBezierPath(roundedRect: rect, cornerRadius: 20).cgPath
        context?.addPath(ref);
        context?.setFillColor(UIColor(white: 0.95, alpha: 1).cgColor);
        context?.fillPath();
        let image = UIGraphicsGetImageFromCurrentImageContext()! as UIImage;
        UIGraphicsEndImageContext();
        
        return image
    }
    
    func imageByScalingAndCroppingForSize(_ size: CGSize, radius: CGFloat) -> UIImage {

        let scaleFactor  = size.height / self.size.height
        let scaledWidth  = self.size.width * scaleFactor
        let scaledHeight = self.size.height * scaleFactor
        
        UIGraphicsBeginImageContextWithOptions(size, true, 2)
        
        let thumbnailRect = CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight)
        
        let context = UIGraphicsGetCurrentContext()
        ColorBucket.lightGrayColor.setFill()
        context?.fill(CGRect(origin: CGPoint.zero, size: size))
        UIBezierPath(roundedRect: CGRect(origin: CGPoint.zero, size: size), cornerRadius: radius).addClip()
        
        self.draw(in: thumbnailRect)
        
        let resultImage = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        return resultImage!
    }
    
    func kg_resizedImageWithHeight(_ height: CGFloat) -> UIImage {
        let newHeight = UIScreen.main.scale * height
        let scale: CGFloat = self.size.width / self.size.height
        let size: CGSize = CGSize(width: newHeight * scale, height: height)
        UIGraphicsBeginImageContext(size)
        self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let destImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return destImage!
    }
}
