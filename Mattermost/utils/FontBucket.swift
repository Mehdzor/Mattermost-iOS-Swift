//
//  FontUtils.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 27.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation

private protocol PostFonts: class {
    static var channelFont: UIFont { get }
    static var messageFont: UIFont { get }
    static var postDateFont: UIFont { get }
    static var postAuthorNameFont: UIFont { get }
    static var parentAuthorNameFont: UIFont { get }
    static var parentMessageFont: UIFont { get }
    static var editTypeFont: UIFont { get }
}

private protocol FeedFonts: class {
    static var feedSendButtonTitleFont: UIFont { get }
    static var inputTextViewFont: UIFont { get }
    static var sectionTitleFont: UIFont { get }
    static var feedbackTitleFont: UIFont { get}
}

private protocol LeftMenuFonts: class {
    static var normalTitleFont: UIFont { get }
    static var highlighTedTitleFont: UIFont { get }
    static var headerTitleFont: UIFont { get }
    static var footerTitleFont: UIFont { get }
}

private protocol RightMenuFonts: class {
    static var rightMenuFont: UIFont { get }
}

private protocol LoginFonts: class {
    static var loginButtonFont: UIFont { get }
    static var loginTextFieldFont: UIFont { get }
    static var titleLoginFont: UIFont { get }
    static var forgotPasswordButtonFont: UIFont { get }
}

private protocol ServerUrlFonts: class {
    static var titleServerUrlFont: UIFont { get }
    static var subtitleServerUrlFont: UIFont { get }
}

private protocol MarkdownFonts: class {
    static var emphasisFont: UIFont { get }
    
    static func semiboldFontOfSize(_ size: CGFloat) -> UIFont
    static func regularFontOfSize(_ size: CGFloat) -> UIFont
    static func regularDisplayFontOfSize(_ size: CGFloat) -> UIFont
}

private protocol MoreChannelsFonts: class {
    static var titleChannelFont: UIFont { get }
    static var subtitleChannelFont: UIFont { get }
    static var dateChannelFont: UIFont { get }
    static var letterChannelFont: UIFont { get }
}

private protocol TeamsFonts: class {
    static var teamNameFont: UIFont {get}
    static var titleURLFont: UIFont { get }
}

private protocol CommonFonts: class {
    static var alertFont: UIFont { get }
}

final class FontBucket {
}

extension FontBucket: PostFonts {
    static let channelFont = FontBucket.semiboldFontOfSize(13)
    static let messageFont = FontBucket.regularFontOfSize(15)
    static let postDateFont = FontBucket.regularFontOfSize(13)
    static let postAuthorNameFont = FontBucket.semiboldFontOfSize(16)
    static let parentAuthorNameFont = FontBucket.semiboldFontOfSize(13)
    static let parentMessageFont = FontBucket.regularFontOfSize(14)
    static let editTypeFont = FontBucket.regularFontOfSize(13)
}

extension FontBucket: FeedFonts {
    static let feedSendButtonTitleFont = FontBucket.semiboldFontOfSize(16)
    static let inputTextViewFont = FontBucket.regularFontOfSize(15)
    static let sectionTitleFont = FontBucket.semiboldFontOfSize(16)
    static let feedbackTitleFont = FontBucket.regularDisplayFontOfSize(23)
}

extension FontBucket: LeftMenuFonts {
    static let normalTitleFont = FontBucket.regularFontOfSize(18)
    static let highlighTedTitleFont = FontBucket.semiboldFontOfSize(18)
    static let headerTitleFont = FontBucket.boldFontOfSize(10)
    static let footerTitleFont = FontBucket.boldFontOfSize(14)
    static let menuTitleFont = FontBucket.boldFontOfSize(16)
}

extension FontBucket: RightMenuFonts {
    static let rightMenuFont = FontBucket.semiboldFontOfSize(16)
}

extension FontBucket: LoginFonts {
    static let loginButtonFont = FontBucket.mediumFontOfSize(18)
    static let loginTextFieldFont = FontBucket.regularFontOfSize(16)
    static let titleLoginFont = FontBucket.semiboldFontOfSize(28)
    static let forgotPasswordButtonFont = FontBucket.regularFontOfSize(16)
}

extension FontBucket: ServerUrlFonts {
    static let titleServerUrlFont = FontBucket.regularFontOfSize(36)
    static let subtitleServerUrlFont = FontBucket.regularFontOfSize(14)
}

extension FontBucket: MoreChannelsFonts {
    static let titleChannelFont = FontBucket.semiboldFontOfSize(16)
    static let subtitleChannelFont = FontBucket.regularFontOfSize(16)
    static let dateChannelFont = FontBucket.regularFontOfSize(16)
    static let letterChannelFont = FontBucket.regularFontOfSize(30)
}

extension FontBucket: TeamsFonts {
    static let teamNameFont = FontBucket.regularFontOfSize(16)
    static let titleURLFont = FontBucket.boldFontOfSize(28)
}

extension FontBucket: CommonFonts {
    static let alertFont = FontBucket.boldSystemFontOfSize(13)
}

//MARK: Helpers

extension FontBucket: MarkdownFonts {
    static let emphasisFont = FontBucket.italicFontOfSize(15)
    
    static func regularFontOfSize(_ size: CGFloat) -> UIFont {
        return UIFont(name: FontNames.Regular, size: size)!
    }
    
    static func semiboldFontOfSize(_ size: CGFloat) -> UIFont {
        return UIFont(name: FontNames.Semibold, size: size)!
    }
}

extension FontBucket {
    fileprivate static func italicFontOfSize(_ size: CGFloat) -> UIFont {
        return UIFont(name: FontNames.Italic, size: size)!
    }
    
    fileprivate static func mediumFontOfSize(_ size: CGFloat) -> UIFont {
        return UIFont(name: FontNames.Medium, size: size)!
    }
    
    fileprivate static func boldFontOfSize(_ size: CGFloat) -> UIFont {
        return UIFont(name: FontNames.Bold, size: size)!
    }
    
    fileprivate static func regularDisplayFontOfSize(_ size: CGFloat) -> UIFont {
        return UIFont(name: FontNames.RegularDisplay, size: size)!
    }
    
    fileprivate static func boldSystemFontOfSize(_ size: CGFloat) -> UIFont {
        return UIFont.boldSystemFont(ofSize: size)
    }
}

private struct FontNames {
    static let Regular               = "SFUIText-Regular"
    static let Semibold              = "SFUIText-Semibold"
    static let Medium                = "SFUIText-Medium"
    static let Bold                  = "SFUIText-Bold"
    static let Italic                = "SFUIText-LightItalic"
    static let RegularDisplay        = "SFUIDisplay-Regular"
    static let SemiboldDisplay       = "SFUIDisplay-Semibold"
    static let BoldDisplay           = "SFUIDisplay-Bold"
    static let MediumDisplay         = "SFUIDisplay-Medium"
}
