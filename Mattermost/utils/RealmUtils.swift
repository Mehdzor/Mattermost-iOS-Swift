//
//  RealmUtils.swift
//  Mattermost
//
//  Created by Maxim Gubin on 21/07/16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation
import RealmSwift

final class RealmUtils {
    
    fileprivate static var realmForMainThread: Realm = {
        return try! Realm()
    }()
   
    static func realmForCurrentThread() -> Realm {
        if Thread.isMainThread {
            return realmForMainThread
        }
        return try! Realm()
    }
    
    static func save(_ objects: [RealmObject]) {
        let realm = realmForCurrentThread()
        
        try! realm.write({
            realm.add(objects, update: true)
        })
    }
    
    static func create(_ dictionary: [String : AnyObject]) {
        let realm = realmForCurrentThread()
        
        try! realm.write({
            realm.create(Channel.self, value: dictionary, update: true)
        })
    }
    
    static func save(_ object: RealmObject) {
        let realm = realmForCurrentThread()
        
        try! realm.write({
            realm.add(object, update: true)
        })
    }
    
    static func deleteAll() {
        let realm = realmForCurrentThread()
        
        try! realm.write({ 
            realm.deleteAll()
        })
    }
    
    static func deletePostObjects(_ objects: Results<Post>) {
        let realm = realmForCurrentThread()
        
        try! realm.write({
            realm.delete(objects)
        })
    }
    
    static func deleteObject(_ object:RealmObject) {
        let realm = realmForCurrentThread()
        
        try! realm.write({
            realm.delete(object)
        })
    }
    
    static func refresh(withLogout: Bool) {
        let realm = realmForCurrentThread()
        
        let channels = realm.objects(Channel.self)
        let files = realm.objects(File.self)
        let posts = realm.objects(Post.self)
        var users = realm.objects(User.self)
        if !withLogout {
            users = users.filter(NSPredicate(format: "identifier != %@", Preferences.sharedInstance.currentUserId!))
        }
        let attachments = realm.objects(Attachment.self)
        let days = realm.objects(Day.self)
        let members = realm.objects(Member.self)
        
        try! realm.write ({
            realm.delete(channels)
            realm.delete(files)
            realm.delete(posts)
            realm.delete(users)
            realm.delete(attachments)
            realm.delete(days)
            realm.delete(members)
        })
    }
}
