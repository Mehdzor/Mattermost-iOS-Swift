//
// Created by Maxim Gubin on 28/06/16.
// Copyright (c) 2016 Kilograpp. All rights reserved.
//


import Foundation
import RealmSwift
import RestKit
import SOCKit

private protocol Interface: class {
    func baseURL() -> URL!
    func avatarLinkForUser(_ user: User) -> String
    func cancelSearchRequestFor(channel: Channel)
    func isNetworkReachable() -> Bool
}

private protocol PreferencesApi: class {
    func savePreferencesWith(_ params: Dictionary<String, String>, complection: @escaping (_ error: Mattermost.Error?) -> Void)
    func listPreferencesWith(_ category: NSString, completion: @escaping (_ error: Mattermost.Error?) -> Void)
}

private protocol NotifyPropsApi: class {
    func updateNotifyProps(_ notifyProps: NotifyProps, completion: @escaping(_ error: Mattermost.Error?) -> Void)
}

private protocol TeamApi: class {
    func loadTeams(with completion: @escaping (_ userShouldSelectTeam: Bool, _ error: Mattermost.Error?) -> Void)
    func sendInvites(_ invites: [Dictionary<String , String>], completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func loadTeamMembersListBy(ids: [String], completion: @escaping (_ error: Mattermost.Error?) -> Void)
}

private protocol ChannelApi: class {
    func loadChannels(with completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func loadExtraInfoForChannel(_ channelId: String, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func updateLastViewDateForChannel(_ channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func updateHeader(_ header: String, channel:Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func updatePurpose(_ purpose: String, channel:Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func update(newDisplayName:String, newName: String, channel:Channel, completion:@escaping (_ error: Mattermost.Error?) -> Void)
    //func loadChannelsMoreWithCompletion(_ completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func loadChannelsMoreWithCompletion(_ completion: @escaping (_ channels: Array<Channel>?, _ error: Mattermost.Error?) -> Void)
    func addUserToChannel(_ user:User, channel:Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func createChannel(_ type: String, displayName: String, name: String, header: String, purpose: String, completion: @escaping (_ channel: Channel?, _ error: Error?) -> Void)
    func createDirectChannelWith(_ user: User, completion: @escaping (_ channel: Channel?, _ error: Mattermost.Error?) -> Void)
    func leaveChannel(_ channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func joinChannel(_ channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func delete(channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func getChannel(channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
}

private protocol UserApi: class {
    func login(_ email: String, password: String, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func loadCurrentUser(completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func update(firstName: String?, lastName: String?, userName: String?, nickName: String?, email: String?, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func update(currentPassword: String, newPassword: String, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func update(profileImage: UIImage, completion: @escaping (_ error: Mattermost.Error?) -> Void, progress: @escaping (_ value: Float) -> Void)
    func subscribeToRemoteNotifications(completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func passwordResetFor(email: String, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    
    func loadUsersListBy(ids: [String], completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func loadCompleteUsersList(_ completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func loadUsersListFrom(channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void)
    func loadUsersAreNotIn(channel: Channel, completion: @escaping (_ error: Mattermost.Error?,_ users: Array<User>? ) -> Void)
    func loadUsersFromCurrentTeam(completion: @escaping (_ error: Mattermost.Error?,_ users: Array<User>? ) -> Void)
}

private protocol PostApi: class {
    func sendPost(_ post: Post, completion:  @escaping(_ error: Mattermost.Error?) -> Void)
    func getPostWithId(_ identifier: String, channel: Channel, completion: @escaping ((_ post: Post?, _ error: Error?) -> Void))
    func updatePost(_ post: Post, completion:  @escaping(_ error: Mattermost.Error?) -> Void)
    func updateSinglePost(_ post: Post, completion:  @escaping(_ error: Mattermost.Error?) -> Void)
    func deletePost(_ post: Post, completion:  @escaping(_ error: Mattermost.Error?) -> Void)
    func searchPostsWithTerms(terms: String, channel: Channel, completion: @escaping(_ posts: Array<Post>?, _ error: Error?) -> Void)
    func loadFirstPage(_ channel: Channel, completion:  @escaping(_ error: Mattermost.Error?) -> Void)
    func loadNextPage(_ channel: Channel, fromPost: Post, completion:  @escaping(_ isLastPage: Bool, _ error: Mattermost.Error?) -> Void)
    func loadPostsBeforePost(post: Post, shortList: Bool?, completion: @escaping(_ isLastPage: Bool, _ error: Error?) -> Void)
    func loadPostsAfterPost(post: Post, shortList: Bool?, completion: @escaping(_ isLastPage: Bool, _ error: Error?) -> Void)
}

private protocol FileApi : class {
    func uploadImageItemAtChannel(_ item: AssignedAttachmentViewItem,channel: Channel, completion:  @escaping (_ file: File?, _ error: Mattermost.Error?) -> Void, progress:  @escaping(_ identifier: String, _ value: Float) -> Void)
    func cancelUploadingOperationForImageItem(_ item: AssignedAttachmentViewItem)
    func getInfo(fileId: String)
}

final class Api {
    
//MARK: Properties
    static let sharedInstance = Api()
    fileprivate var _managerCache: ObjectManager?
    fileprivate var downloadOperationsArray = Array<AFRKHTTPRequestOperation>()
    fileprivate var networkReachabilityManager = NetworkReachabilityManager.init()
    fileprivate var manager: ObjectManager  {
        if _managerCache == nil {
            _managerCache = ObjectManager(baseURL: self.computeAndReturnApiRootUrl())
            _managerCache!.httpClient.setDefaultHeader(Constants.Http.Headers.RequestedWith, value: "XMLHttpRequest")
            _managerCache!.httpClient.setDefaultHeader(Constants.Http.Headers.AcceptLanguage, value: LocaleUtils.currentLocale())
            _managerCache!.httpClient.setDefaultHeader(Constants.Http.Headers.ContentType, value: RKMIMETypeJSON)
            _managerCache!.requestSerializationMIMEType = RKMIMETypeJSON;
            _managerCache!.addRequestDescriptors(from: RKRequestDescriptor.findAllDescriptors())
            _managerCache!.addResponseDescriptors(from: RKResponseDescriptor.findAllDescriptors())
            
            _managerCache!.registerRequestOperationClass(KGObjectRequestOperation.self)

        }
        return _managerCache!;
    }
    
//MARK: LifeCycle
    fileprivate init() {
        self.setupMillisecondsValueTransformer()
    }
    fileprivate func setupMillisecondsValueTransformer() {
        let transformer = RKValueTransformer.millisecondsToDateValueTransformer()
        RKValueTransformer.defaultValueTransformer().insert(transformer, at: 0)
    }
    
    fileprivate func computeAndReturnApiRootUrl() -> URL! {
        return URL(string: Preferences.sharedInstance.serverUrl!)?.appendingPathComponent(Constants.Api.Route)
    }
}


//MARK: PreferencesApi
extension Api: PreferencesApi {
    func savePreferencesWith(_ params: Dictionary<String, String>, complection: @escaping (_ error: Mattermost.Error?) -> Void) {
       let path = PreferencesPathPatternsContainer.savePathPattern()
        
        self.manager.savePreferencesAt(path: path, parameters: [params], success: { (success) in
            complection(nil)
        }) { (error) in
            complection(error)
        }
    }
    
    func listPreferencesWith(_ category: NSString, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let preference = Preference()
        preference.category = "direct_channel_show"
        let path = SOCStringFromStringWithObject(PreferencesPathPatternsContainer.listPreferencesPathPatterns(), preference)!
        
        self.manager.get(path: path, success: { (mappingResult, skipMapping) in
            let preferences = MappingUtils.fetchAllPreferences(mappingResult)
            for preference in preferences {
                let user = User.objectById(preference.name!)
                if (user?.hasChannel())! {
                    let channel = user?.directChannel()
                    try! RealmUtils.realmForCurrentThread().write {
                        channel?.isDirectPrefered = ((preference as Preference).value == Constants.CommonStrings.True)
                    }
                }
            }
            completion(nil)
            }, failure: { (error) in
                completion(error)
        })
    }
}


//MARK: NotifyProps
extension Api: NotifyPropsApi {
    func updateNotifyProps(_ notifyProps: NotifyProps, completion: @escaping(_ error: Mattermost.Error?) -> Void) {
        let path = NotifyPropsPathPatternsContainer.updatePathPattern()
        
        self.manager.post(object: notifyProps, path: path, parameters: nil, success: { (mappingResult) in
            let object = mappingResult.dictionary()["notify_props"] as! NotifyProps
            let notifyProps = DataManager.sharedInstance.currentUser?.notificationProperies()
//Will replace after connection problems solved
            try! RealmUtils.realmForCurrentThread().write {
                notifyProps?.channel = object.channel
                notifyProps?.comments = object.comments
                notifyProps?.desktop = object.desktop
                notifyProps?.desktopDuration = object.desktopDuration
                notifyProps?.desktopSound = object.desktopSound
                notifyProps?.email = object.email
                notifyProps?.firstName = object.firstName
                notifyProps?.mentionKeys = object.mentionKeys
                notifyProps?.push = object.push
                notifyProps?.pushStatus = notifyProps?.pushStatus
            }
            completion(nil)
            }, failure: { (error) in
                completion(error)
        })
    }
}


//MARK: TeamApi
extension Api: TeamApi {
    func loadTeams(with completion:@escaping (_ userShouldSelectTeam: Bool, _ error: Mattermost.Error?) -> Void) {
        let path = TeamPathPatternsContainer.initialLoadPathPattern()
        
        self.manager.get(path: path, success: { (mappingResult, skipMapping) in
            let teams = MappingUtils.fetchAllTeams(mappingResult)
            //let users = MappingUtils.fetchUsersFromInitialLoad(mappingResult)
            let preferences = MappingUtils.fetchPreferencesFromInitialLoad(mappingResult)
            preferences.forEach{ $0.computeKey() }
            Preferences.sharedInstance.siteName = MappingUtils.fetchSiteName(mappingResult)
            RealmUtils.save(teams)
            let currentUser = DataManager.sharedInstance.currentUser
            let realm = RealmUtils.realmForCurrentThread()
            let oldPreferences = currentUser?.preferences
            try! realm.write {
                currentUser?.preferences.removeAll()
                realm.delete(oldPreferences!)
                realm.add(preferences, update: true)
                currentUser?.preferences.append(objectsIn: preferences)
            }
            if (teams.count == 1) {
                DataManager.sharedInstance.currentTeam = teams.first
                Preferences.sharedInstance.currentTeamId = teams.first?.identifier
                Preferences.sharedInstance.save()
                completion(false, nil)
            } else {
                completion(true, nil)
            }
        }) { (error) in
            completion(true, error)
        }
    }
    
    func checkURL(with completion:@escaping (_ error: Mattermost.Error?) -> Void) {
        let path = TeamPathPatternsContainer.initialLoadPathPattern()
        self._managerCache = nil
        
        self.manager.get(path: path, success: { (mappingResult, skipMapping) in
            Preferences.sharedInstance.siteName = MappingUtils.fetchSiteName(mappingResult)
            completion(nil)
        }) { (error) in
            completion(error)
        }
    }
    
    func sendInvites(_ invites: [Dictionary<String , String>], completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(TeamPathPatternsContainer.teamInviteMembers(), DataManager.sharedInstance.currentTeam)
        let params: Dictionary = ["invites" : invites]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            completion(nil)
        }) { (error) in
            completion(error)
        }
    }
    func loadTeamMembersListBy(ids: [String], completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let currentTeam = DataManager.sharedInstance.currentTeam
        let path = SOCStringFromStringWithObject(TeamPathPatternsContainer.teamMembersIds(), currentTeam)
        
        self.manager.post(nil, path: path, parametersAs: ids, success: { (operation, mappingResult) in
            let teamMembers = mappingResult?.array() as! [Member]
            let realm = RealmUtils.realmForCurrentThread()
            for teamMember in teamMembers {
                let user = realm.object(ofType: User.self, forPrimaryKey: teamMember.userId)
                try! realm.write {
                    user?.isOnTeam = true
                    user?.directChannel().isInterlocuterOnTeam = true
                }
            }
            completion(nil)
        }) { (operation, error) in
            completion(Error.errorWithGenericError(error))
        }
    }
}


//MARK: ChannelApi
extension Api: ChannelApi {
    func loadChannels(with completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.listPathPattern(), DataManager.sharedInstance.currentTeam)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            let realm = RealmUtils.realmForCurrentThread()

            let channels = mappingResult.array() as! [Channel]//MappingUtils.fetchAllChannelsFromList(mappingResult)
            try! realm.write({
                channels.forEach {
                    $0.currentUserInChannel = true
                    $0.computeTeam()
                   // $0.computeDispayNameIfNeeded()
                  /*  if let channel = realm.objects(Channel.self).filter("identifier = %@", $0.identifier!).first{
                        $0.members = channel.members
                    }*/
                    realm.add($0, update: true)
                }
            })
            
            completion(nil)
            }, failure: completion)
    }
    
    func loadExtraInfoForChannel(_ channelId: String, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let teamId = Preferences.sharedInstance.currentTeamId
        let newChannel = Channel()
        newChannel.identifier = channelId
        newChannel.team = RealmUtils.realmForCurrentThread().object(ofType: Team.self, forPrimaryKey: teamId)
        let path =  SOCStringFromStringWithObject(ChannelPathPatternsContainer.loadOnePathPattern(), newChannel)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            let channelDictionary = Reflection.fetchNotNullValues(object: mappingResult.firstObject as! Channel)
            print(channelDictionary)
            RealmUtils.create(channelDictionary)
            let updatedChannel = try! Realm().objects(Channel.self).filter("identifier = %@", (mappingResult.firstObject as! Channel).identifier!).first!
            let realm = RealmUtils.realmForCurrentThread()
            try! realm.write({
                let updatedMembers = updatedChannel.members
                for member in updatedMembers{
                    member.computeDisplayNameWidth()
                }
            })
            completion(nil)
            }, failure: completion)
    }
    
    func updateLastViewDateForChannel(_ channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.updateLastViewDatePathPattern(), channel)
        
        self.manager.post(path: path, success: { (mappingResult) in
            try! RealmUtils.realmForCurrentThread().write({
                channel.lastViewDate = Date()
            })
            completion(nil)
            }, failure: completion)
    }
    
    func loadChannelsMoreWithCompletion(_ completion: @escaping (_ channels: Array<Channel>?, _ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.moreListPathPattern(), DataManager.sharedInstance.currentTeam)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            let allChannels = MappingUtils.fetchAllChannelsFromList(mappingResult)
            completion(allChannels, nil)
        }, failure: { (error) in
            completion(nil, error)
        })
    }
    
    func addUserToChannel(_ user:User, channel:Channel, completion:@escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.addUserPathPattern(), channel)
        let params: Dictionary<String, String> = [ "user_id" : user.identifier ]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            completion(nil)
            }, failure: completion)
    }
    
    func updateHeader(_ header:String, channel:Channel, completion:@escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.updateHeader(), channel)
        let channelId = channel.identifier
        let params: Dictionary<String, String> = [ "channel_header" : header, "channel_id" : channel.identifier! ]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            let realm = RealmUtils.realmForCurrentThread()
            let channel = realm.object(ofType: Channel.self, forPrimaryKey: channelId)
            try! realm.write {
                channel?.header = header
            }
            completion(nil)
            }, failure: completion)
    }
    
    func updatePurpose(_ purpose:String, channel:Channel, completion:@escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.updatePurpose(), channel)
        let channelId = channel.identifier
        let params: Dictionary<String, String> = [ "channel_purpose" : purpose, "channel_id" : channel.identifier! ]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            let realm = RealmUtils.realmForCurrentThread()
            let channel = realm.object(ofType: Channel.self, forPrimaryKey: channelId)
            try! realm.write {
                channel?.purpose = purpose
            }
            completion(nil)
            }, failure: completion)
    }
    
    func update(newDisplayName:String, newName: String, channel:Channel, completion:@escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.update(), channel)
        
        let params: Dictionary<String, Any> = [
        "create_at" : Int(channel.createdAt!.timeIntervalSince1970),
        "creator_id" : String(Preferences.sharedInstance.currentUserId!)!,
        "delete_at" : 0,
        "display_name" : newDisplayName,
        "extra_update_at" : Int(NSDate().timeIntervalSince1970),
        "header" : channel.header!,
        "id" : channel.identifier!,
        "last_post_at" : Int(channel.lastPostDate!.timeIntervalSince1970),
        "name" : newName,
        "purpose" : channel.purpose!,
        "team_id" : channel.team!.identifier!,
        "total_msg_count" : Int(channel.messagesCount!)!,
        "type" : channel.privateType!,
        "update_at" : Int(NSDate().timeIntervalSince1970)]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            completion(nil)
            }, failure: completion)
    }
    
    
    func createChannel(_ type: String, displayName: String, name: String, header: String, purpose: String, completion: @escaping (_ channel: Channel?, _ error: Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.createChannelPathPattern(), DataManager.sharedInstance.currentTeam)
      
        let newChannel = Channel()
        newChannel.privateType = type
        newChannel.name = name.lowercased()
        newChannel.displayName = displayName
        newChannel.header = header
        newChannel.purpose = purpose
        
        RealmUtils.save(newChannel)
        
        self.manager.post(object: newChannel, path: path, parameters: nil, success: { (mappingResult) in
            let realm = RealmUtils.realmForCurrentThread()
            let channel = mappingResult.firstObject as! Channel
            try! realm.write({
                channel.currentUserInChannel = true
                channel.computeTeam()
                channel.computeDispayNameIfNeeded()
                realm.add(channel)
            })
            completion(channel ,nil)
        }) { (error) in
            completion(nil, error)
        }
    }

    func createDirectChannelWith(_ user: User, completion: @escaping (_ channel: Channel?, _ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.createDirrectChannelPathPattern(), DataManager.sharedInstance.currentTeam)
        let params: Dictionary<String, String> = [ "user_id" : user.identifier ]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            let realm = RealmUtils.realmForCurrentThread()
            let channel = mappingResult.firstObject as! Channel
            try! realm.write({
                channel.currentUserInChannel = true
                channel.computeTeam()
                channel.computeDispayNameIfNeeded()
                realm.add(channel)
            })
            completion(nil ,nil)
            }) { (error) in
                completion(nil, error)
        }
    }
    
    func leaveChannel(_ channel: Channel, completion: @escaping (Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.leaveChannelPathPattern(), channel)
        
        self.manager.post(object: nil, path: path, parameters: nil, success: { (mappingResult) in
            let channelId = (mappingResult.firstObject as! Channel).identifier
            
            try! RealmUtils.realmForCurrentThread().write {
                Channel.objectById(channelId!)?.currentUserInChannel = false
            }
            
            let notificationName = Constants.NotificationsNames.UserJoinNotification
            NotificationCenter.default.post(name: Notification.Name(rawValue: notificationName), object: channel)
            
            completion(nil)
            }, failure: completion)
    }
    
    func joinChannel(_ channel: Channel, completion: @escaping (Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.joinChannelPathPattern(), channel)
        
        self.manager.post(object: nil, path: path, parameters: nil, success: { (mappingResult) in
            let channelId = (mappingResult.firstObject as! Channel).identifier
            
            try! RealmUtils.realmForCurrentThread().write {
                Channel.objectById(channelId!)?.currentUserInChannel = true
            }
            completion(nil)
            }, failure: completion)
    }
    
    func delete(channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.deleteChannelPathPattern(), channel)
        
        self.manager.post(path: path, success: { (mappingResult) in
            completion(nil)
        }, failure: { (error) in
            completion(error)
        })
    }
    
    //FIXMEGETCHANNEL
    func getChannel(channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(ChannelPathPatternsContainer.getChannelPathPattern(), channel)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            let realm = RealmUtils.realmForCurrentThread()
            let obtainedChannel = MappingUtils.fetchAllChannels(mappingResult).first
            print(obtainedChannel?.name)
          //  let obtainedChannel = mappingResult.firstObject as! Channel
            try! realm.write({
                channel.updateAt = obtainedChannel?.updateAt
                channel.deleteAt = obtainedChannel?.deleteAt
                channel.displayName = obtainedChannel?.displayName!
                channel.name = obtainedChannel?.name!
                channel.header = obtainedChannel?.header!
                channel.purpose = obtainedChannel?.purpose!
                channel.lastPostDate = obtainedChannel?.lastPostDate
                channel.messagesCount = obtainedChannel?.messagesCount
                channel.extraUpdateDate = obtainedChannel?.extraUpdateDate
            })
            completion(nil)
        }, failure: completion)
    }
}


//MARK: UserApi
extension Api: UserApi {
    func login(_ email: String, password: String, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = UserPathPatternsContainer.loginPathPattern()
        let parameters = ["login_id" : email, "password": password, "token" : ""]
        
        self.manager.post(path: path, parameters: parameters as [AnyHashable: Any]?, success: { (mappingResult) in
            let user = mappingResult.firstObject as! User
            let notifyProps = user.notifyProps
            notifyProps?.userId = user.identifier
            notifyProps?.computeKey()
            let systemUser = DataManager.sharedInstance.instantiateSystemUser()
            user.computeDisplayName()
            DataManager.sharedInstance.currentUser = user
            RealmUtils.save([user, systemUser])
            RealmUtils.save(notifyProps!)
            
            _ = DataManager.sharedInstance.currentUser

            SocketManager.sharedInstance.setNeedsConnect()
            //completion(nil)
            NotificationsUtils.subscribeToRemoteNotificationsIfNeeded(completion: completion)
            }, failure: completion)
    }
    
    func logout(_ completion:@escaping (_ error: Mattermost.Error?) -> Void) {
        let path = UserPathPatternsContainer.logoutPathPattern()
        let parameters = ["user_id" : Preferences.sharedInstance.currentUserId!]
        
        self.manager.post(path: path, parameters: parameters, success: { (mappingResult) in
            completion(nil)
            }, failure: completion)
    }
    
    func loadCurrentUser(completion: @escaping (Error?) -> Void) {
        let path = UserPathPatternsContainer.loadCurrentUser()
        
        self.manager.get(path: path, success: { (mappingResult, skipMapping) in
            let updatedUser = mappingResult.firstObject as! User
            let updatedNotifyProps = updatedUser.notifyProps
            updatedNotifyProps?.userId = updatedUser.identifier
            updatedNotifyProps?.computeKey()
            
            let realm = RealmUtils.realmForCurrentThread()
            let currentUser = DataManager.sharedInstance.currentUser
            //let preferences = DataManager.sharedInstance.currentUser?.preferences
            try! realm.write {
                //Update user fields
                currentUser?.updateAt = updatedUser.updateAt
                currentUser?.deleteAt = updatedUser.deleteAt
                currentUser?.username = updatedUser.username
                currentUser?.email = updatedUser.email
                currentUser?.nickname = updatedUser.nickname
                currentUser?.firstName = updatedUser.firstName
                currentUser?.lastName = updatedUser.lastName
                //Update notifyProps
                realm.delete((currentUser?.notifyProps)!)
                realm.add(updatedNotifyProps!)
                currentUser?.notifyProps = updatedNotifyProps
            }
            
            
           /* let user = mappingResult.firstObject as! User
            let systemUser = DataManager.sharedInstance.instantiateSystemUser()
            user.computeDisplayName()
            DataManager.sharedInstance.currentUser = user
            RealmUtils.save([user, systemUser])
            SocketManager.sharedInstance.setNeedsConnect()*/
            completion(nil)
            }, failure: completion)
    }
    
    func loadUsersListBy(ids: [String], completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = UserPathPatternsContainer.usersByIdsPathPattern()
        
        self.manager.post(nil, path: path, parametersAs: ids, success: { (operation, mappingResult) in
            //Temp cap
            
            let responseDictionary = operation?.httpRequestOperation.responseString!.toDictionary()
            var users = Array<User>()
            print("ids = ", ids)
            for userId in ids {
                guard responseDictionary?[userId] != nil else { continue }
                
                let userDictionary = (responseDictionary?[userId])! as! Dictionary<String, Any>
                let user = User()
                user.identifier = userDictionary["id"] as! String!
                user.createAt = Date(timeIntervalSince1970: userDictionary["create_at"] as! TimeInterval)
                user.updateAt = Date(timeIntervalSince1970: userDictionary["update_at"] as! TimeInterval)
                user.deleteAt = Date(timeIntervalSince1970: userDictionary["delete_at"] as! TimeInterval)
                user.username = userDictionary["username"] as! String?
                user.authData = userDictionary["auth_data"] as! String?
                user.authService = userDictionary["auth_service"] as! String?
                user.email = userDictionary["email"] as! String?
                user.nickname = userDictionary["nickname"] as! String?
                user.firstName = userDictionary["first_name"] as! String?
                user.lastName = userDictionary["last_name"] as! String?
                user.roles = userDictionary["roles"] as! String?
                user.locale = userDictionary["locale"] as! String?
                user.computeDisplayName()
                
                users.append(user)
            }
            
            
         //   let users = MappingUtils.fetchPreferedUsersBy(ids: ids, mappingResult: mappingResult!)
            let realm = RealmUtils.realmForCurrentThread()
            let preferences = Preference.preferedUsersList()
            for user in users {
                user.computeDisplayName()
                let predicate = NSPredicate(format: "name == %@", user.identifier)
                let preference = preferences.filter(predicate).first
                user.isOnTeam = (preference?.value == Constants.CommonStrings.True)
                try! realm.write {
                    let existUser = realm.object(ofType: User.self, forPrimaryKey: user.identifier)
                    if existUser == nil {
                        realm.add(user)
                        user.directChannel().isDirectPrefered = true
                        user.directChannel().displayName = user.displayName
                    } else {
                        existUser?.directChannel().isDirectPrefered = true
                        existUser?.directChannel().displayName = user.displayName
                    }
                }
            }
            completion(nil)
        }) { (operation, error) in
            completion(Error.errorWithGenericError(error))
        }
    }
    
    func loadCompleteUsersList(_ completion:@escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(UserPathPatternsContainer.completeListPathPattern(), DataManager.sharedInstance.currentTeam)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            let users = MappingUtils.fetchUsersFromCompleteList(mappingResult)
            users.forEach {$0.computeDisplayName()}
            RealmUtils.save(users)
                        
            completion(nil)
        }, failure: completion)
    }
    
    func loadUsersListFrom(channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(UserPathPatternsContainer.usersFromChannelPathPattern(), channel)!
        
        self.manager.getObjectsAt(path: path, success: {  (operation, mappingResult) in
            print(operation.httpRequestOperation.responseString)
            //Temp cap
            let responseDictionary = operation.httpRequestOperation.responseString!.toDictionary()
            let ids = Array(responseDictionary!.keys.map{$0})
            let realm = RealmUtils.realmForCurrentThread()
            try! realm.write {
                for userId in ids {
                    let userDictionary = (responseDictionary?[userId])! as! Dictionary<String, Any>
                    let user = User()
                    user.identifier = userDictionary["id"] as! String!
                    user.createAt = Date(timeIntervalSince1970: userDictionary["create_at"] as! TimeInterval)
                    user.updateAt = Date(timeIntervalSince1970: userDictionary["update_at"] as! TimeInterval)
                    user.deleteAt = Date(timeIntervalSince1970: userDictionary["delete_at"] as! TimeInterval)
                    user.username = userDictionary["username"] as! String?
                    user.authData = userDictionary["auth_data"] as! String?
                    user.authService = userDictionary["auth_service"] as! String?
                    user.email = userDictionary["email"] as! String?
                    user.nickname = userDictionary["nickname"] as! String?
                    user.firstName = userDictionary["first_name"] as! String?
                    user.lastName = userDictionary["last_name"] as! String?
                    user.roles = userDictionary["roles"] as! String?
                    user.locale = userDictionary["locale"] as! String?
                    realm.add(user, update: true)
                    if !Array(channel.members.map{$0.identifier}).contains(user.identifier) {
                        channel.members.append(user)
                    }
                }
            }
            completion(nil)
        }, failure: completion)
    }
    
    func loadUsersAreNotIn(channel: Channel, completion: @escaping (_ error: Mattermost.Error?,_ users: Array<User>? ) -> Void){
        let path = SOCStringFromStringWithObject(UserPathPatternsContainer.usersNotInChannelPathPattern(), channel)!
        self.manager.getObjectsAt(path: path, success: {  (operation, mappingResult) in
            print(operation.httpRequestOperation.responseString)
            //Temp cap
            let responseDictionary = operation.httpRequestOperation.responseString!.toDictionary()
            var users = Array<User>()
            let ids = Array(responseDictionary!.keys.map{$0})
            let realm = RealmUtils.realmForCurrentThread()
            //try! realm.write {
                for userId in ids {
                    let userDictionary = (responseDictionary?[userId])! as! Dictionary<String, Any>
                    let user = User()
                    user.identifier = userDictionary["id"] as! String!
                    user.createAt = Date(timeIntervalSince1970: userDictionary["create_at"] as! TimeInterval)
                    user.updateAt = Date(timeIntervalSince1970: userDictionary["update_at"] as! TimeInterval)
                    user.deleteAt = Date(timeIntervalSince1970: userDictionary["delete_at"] as! TimeInterval)
                    user.username = userDictionary["username"] as! String?
                    user.authData = userDictionary["auth_data"] as! String?
                    user.authService = userDictionary["auth_service"] as! String?
                    user.email = userDictionary["email"] as! String?
                    user.nickname = userDictionary["nickname"] as! String?
                    user.firstName = userDictionary["first_name"] as! String?
                    user.lastName = userDictionary["last_name"] as! String?
                    user.roles = userDictionary["roles"] as! String?
                    user.locale = userDictionary["locale"] as! String?
                    //if !channel.members.contains(user) {
                        //realm.add(user, update: true)
                        users.append(user)
                    //}
                }
            //}
            completion(nil, users)
            
        }, failure:{ error in
                completion(error, nil)
        })
    }
    
    func loadUsersFromCurrentTeam(completion: @escaping (_ error: Mattermost.Error?,_ users: Array<User>? ) -> Void) {
        let path = SOCStringFromStringWithObject(UserPathPatternsContainer.usersFromCurrentTeamPathPattern(), DataManager.sharedInstance.currentTeam)!
        self.manager.getObjectsAt(path: path, success: {  (operation, mappingResult) in
            print(operation.httpRequestOperation.responseString)
            //Temp cap
            let responseDictionary = operation.httpRequestOperation.responseString!.toDictionary()
            var users = Array<User>()
            let ids = Array(responseDictionary!.keys.map{$0})
            let realm = RealmUtils.realmForCurrentThread()
            for userId in ids {
                let userDictionary = (responseDictionary?[userId])! as! Dictionary<String, Any>
                let user = User()
                user.identifier = userDictionary["id"] as! String!
                user.createAt = Date(timeIntervalSince1970: userDictionary["create_at"] as! TimeInterval)
                user.updateAt = Date(timeIntervalSince1970: userDictionary["update_at"] as! TimeInterval)
                user.deleteAt = Date(timeIntervalSince1970: userDictionary["delete_at"] as! TimeInterval)
                user.username = userDictionary["username"] as! String?
                user.authData = userDictionary["auth_data"] as! String?
                user.authService = userDictionary["auth_service"] as! String?
                user.email = userDictionary["email"] as! String?
                user.nickname = userDictionary["nickname"] as! String?
                user.firstName = userDictionary["first_name"] as! String?
                user.lastName = userDictionary["last_name"] as! String?
                user.roles = userDictionary["roles"] as! String?
                user.locale = userDictionary["locale"] as! String?
                users.append(user)
            }
            completion(nil, users)
            
        }, failure:{ error in
            completion(error, nil)
        })
    }
    
    func update(firstName: String? = nil,
                lastName: String? = nil,
                userName: String? = nil,
                nickName: String? = nil,
                email: String? = nil,
                completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = UserPathPatternsContainer.userUpdatePathPattern()
        let user = DataManager.sharedInstance.currentUser
        
        var params: [String : Any] = ["id" : user?.identifier! as Any,
                                      "create_at" : (user?.createAt?.timeIntervalSince1970)! * 1000]
        params["first_name"] = firstName ?? user?.firstName
        params["last_name"] = lastName ?? user?.lastName
        params["nickname"] = nickName ?? user?.nickname
        params["username"] = userName ?? user?.username
        params["email"] = email ?? user?.email
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            let realm = RealmUtils.realmForCurrentThread()
            try! realm.write {
                user?.firstName = firstName ?? user?.firstName
                user?.lastName = lastName ?? user?.lastName
                user?.nickname = nickName ?? user?.nickname
                user?.username = userName ?? user?.username
                user?.displayName = userName ?? user?.username
                user?.computeDisplayNameWidth()
                user?.email = email ?? user?.email
            }
            completion(nil)
        }) { (error) in
            completion(error)
        }
    }
    
    func update(currentPassword: String, newPassword: String, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = UserPathPatternsContainer.userUpdatePasswordPathPattern()
        
        let params = ["user_id" : DataManager.sharedInstance.currentUser?.identifier as Any,
                      "current_password" : currentPassword,
                      "new_password" : newPassword] as [String : Any]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            
            completion(nil)
        }) { (error) in
            completion(error)
        }
    }
    
    func update(profileImage: UIImage,
                completion: @escaping (_ error: Mattermost.Error?) -> Void,
                progress: @escaping (_ value: Float) -> Void) {
        let path = UserPathPatternsContainer.userUpdateImagePathPattern()
    
        self.manager.post(image: profileImage, identifier: "image_id", name: "image", path: path, parameters: nil, success: { (mappingResult) in
            print(mappingResult)
            completion(nil)
            
        }, failure: { (error) in
            completion(error)
        }) { (value) in
            progress(value)
        }
    }
    
    func subscribeToRemoteNotifications(completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = UserPathPatternsContainer.attachDevicePathPattern()
        let deviceUUID = Preferences.sharedInstance.deviceUUID
        let params = ["device_id" : "apple:" + deviceUUID!]
        print(params)
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            completion(nil)
        }, failure: { (error) in
            completion(error)
        })
    }
    
    func passwordResetFor(email: String, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = UserPathPatternsContainer.passwordResetPathPattern()
        let params = [ "email" : email ]
        
        self.manager.post(object: nil, path: path, parameters: params, success: { (mappingResult) in
            completion(nil)
        }, failure: { (error) in
            completion(error)
        })
        
    }
}


//MARK: PostApi
extension Api: PostApi {
    func loadFirstPage(_ channel: Channel, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let wrapper = PageWrapper(channel: channel)
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.firstPagePathPattern(), wrapper)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            guard !skipMapping else { completion(nil); return }
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                let posts = MappingUtils.fetchConfiguredPosts(mappingResult)
                RealmUtils.save(posts)                
                for post in posts {
                    for file in post.files {
                        self.getInfo(fileId: file.identifier!)
                    }
                }
                DispatchQueue.main.sync {
                    completion(nil)
                }
            })
        }) { (error) in
            
            //If joined current user -> reload left menu
            if let error = error {
                if (error.code == -1011) {
                    let notificationName = Constants.NotificationsNames.UserJoinNotification
                    try! RealmUtils.realmForCurrentThread().write {
                    channel.currentUserInChannel = false
                    }
                    NotificationCenter.default.post(name: Notification.Name(rawValue: notificationName), object: channel)
                }
            }
            completion(error)
        }
    }
    
    func loadNextPage(_ channel: Channel, fromPost: Post, completion: @escaping (_ isLastPage: Bool, _ error: Mattermost.Error?) -> Void) {
        guard fromPost.identifier != nil else { return }
        let postIdentifier = fromPost.identifier!
        let wrapper = PageWrapper(channel: channel, lastPostId: postIdentifier)
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.nextPagePathPattern(), wrapper)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            guard !skipMapping else {
                completion(MappingUtils.isLastPage(mappingResult, pageSize: wrapper.size), nil)
                return
            }
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                RealmUtils.save(MappingUtils.fetchConfiguredPosts(mappingResult))
                DispatchQueue.main.sync {
                    completion(MappingUtils.isLastPage(mappingResult, pageSize: wrapper.size), nil)
                }
            })
        }) { (error) in
            let isLastPage = (error!.code == 1001) ? true : false
            completion(isLastPage, error)
        }
    }
    
    func loadPostsBeforePost(post: Post, shortList: Bool? = false, completion: @escaping(_ isLastPage: Bool, _ error: Error?) -> Void) {
        let size = (shortList == true) ? 10 : 60
        let wrapper = PageWrapper(size: size, channel: post.channel, lastPostId: post.identifier)
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.beforePostPathPattern(), wrapper)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            guard !skipMapping else {
                completion(MappingUtils.isLastPage(mappingResult, pageSize: wrapper.size), nil)
                return
            }
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                RealmUtils.save(MappingUtils.fetchConfiguredPosts(mappingResult))
                DispatchQueue.main.sync {
                    completion(MappingUtils.isLastPage(mappingResult, pageSize: wrapper.size), nil)
                }
            })
        }) { (error) in
            let isLastPage = (error!.code == 1001) ? true : false
            completion(isLastPage, error)
        }
    }
    
    func loadPostsAfterPost(post: Post, shortList: Bool? = false, completion: @escaping(_ isLastPage: Bool, _ error: Error?) -> Void) {
        let size = (shortList == true) ? 10 : 60
        let wrapper = PageWrapper(size: size, channel: post.channel, lastPostId: post.identifier)
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.afterPostPathPattern(), wrapper)
        
        self.manager.get(path: path!, success: { (mappingResult, skipMapping) in
            guard !skipMapping else {
                completion(MappingUtils.isLastPage(mappingResult, pageSize: wrapper.size), nil)
                return
            }
            DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
                RealmUtils.save(MappingUtils.fetchConfiguredPosts(mappingResult))
                DispatchQueue.main.sync {
                    completion(MappingUtils.isLastPage(mappingResult, pageSize: wrapper.size), nil)
                }
            })
        }) { (error) in
            let isLastPage = (error!.code == 1001) ? true : false
            completion(isLastPage, error)
        }
    }
    
    func sendPost(_ post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.creationPathPattern(), post)
        self.manager.post(object: post, path: path, success: { (mappingResult) in
            let resultPost = mappingResult.firstObject as! Post
            try! RealmUtils.realmForCurrentThread().write {
                //addition parameters
                post.status = .default
                post.identifier = resultPost.identifier
            }
            completion(nil)
        }, failure: { (error) in
            completion(error)
        })
    }
    
    func getPostWithId(_ identifier: String, channel: Channel, completion: @escaping ((_ post: Post?, _ error: Error?) -> Void)) {
        var path = "teams/" + (channel.team?.identifier)!
            path += "/channels/" + channel.identifier!
            path += "/posts/" + identifier + "/get"
        self.manager.get(path: path, success: { (mappingResult, canSkipMapping) in
            let resultPost = mappingResult.firstObject as! Post
            resultPost.computeMissingFields()
            RealmUtils.save(resultPost)
            completion(resultPost, nil)
        }) { (error) in
            completion(nil, error)
        }
    }
    
    func updateSinglePost(_ post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.updatingPathPattern(), post)
        self.manager.post(object: post, path: path, success: { (mappingResult) in
            RealmUtils.save(mappingResult.firstObject as! Post)
            completion(nil)
            }, failure: completion)
    }
    
    func deletePost(_ post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.deletingPathPattern(), post)
        let params = ["team_id"    : Preferences.sharedInstance.currentTeamId!,
                      "channel_id" : post.channelId!,
                      "post_id"    : post.identifier!]
        
        self.manager.deletePostAt(path: path, parameters: params, success: { (mappingResult) in
            completion(nil)
        }) { (error) in
            completion(error)
        }
    }
    
    func searchPostsWithTerms(terms: String, channel: Channel, completion: @escaping(_ posts: Array<Post>?, _ error: Error?) -> Void) {
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.searchingPathPattern(), channel)
        let params = ["team_id" : Preferences.sharedInstance.currentTeamId!]
        
        self.manager.searchPostsWith(terms: terms, path: path, parameters: params, success: { (mappingResult) in
            let posts = MappingUtils.fetchConfiguredPosts(mappingResult)
            completion(posts, nil)
        }) { (error) in
            completion(nil, error)
        }
    }
    
    func updatePost(_ post: Post, completion: @escaping (_ error: Mattermost.Error?) -> Void) {
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.updatePathPattern(), post)
                
        self.manager.get(object: post, path: path!, success: { (mappingResult, skipMapping) in
            RealmUtils.save(MappingUtils.fetchPostFromUpdate(mappingResult))
            completion(nil)
        }, failure: completion)
    }
}


//MARK: FileApi
extension Api : FileApi {
    func uploadImageItemAtChannel(_ item: AssignedAttachmentViewItem,
                                  channel: Channel,
                                  completion: @escaping (_ file: File?, _ error: Mattermost.Error?) -> Void,
                                  progress: @escaping (_ identifier: String, _ value: Float) -> Void) {
        let path = SOCStringFromStringWithObject(FilePathPatternsContainer.uploadPathPattern(), DataManager.sharedInstance.currentTeam)
        let params = ["channel_id" : channel.identifier!,
                      "client_ids"  : StringUtils.randomUUID()]
        
        self.manager.post(image: item.image, identifier: params["client_ids"]!, name: "files", path: path, parameters: params, success: { (mappingResult) in
            let file = File()
            let dictionary = mappingResult.firstObject as! [String:String]
            let rawLink = dictionary[FileAttributes.rawLink.rawValue]
            file.identifier = params["client_ids"]
            file.rawLink = rawLink
            completion(file, nil)
            RealmUtils.save(file)
            }, failure: { (error) in
                completion(nil, error)
            }) { (value) in
                progress(item.identifier, value)
        }
    }
    
    func cancelUploadingOperationForImageItem(_ item: AssignedAttachmentViewItem) {
        self.manager.cancelUploadingOperationForImageItem(item)
    }
    
    func uploadFileItemAtChannel(_ item: AssignedAttachmentViewItem,
                                  channel: Channel,
                                  completion: @escaping (_ file: File?, _ error: Mattermost.Error?) -> Void,
                                  progress: @escaping (_ identifier: String, _ value: Float) -> Void) {
        let path = SOCStringFromStringWithObject(FilePathPatternsContainer.uploadPathPattern(), DataManager.sharedInstance.currentTeam)
        let params = ["channel_id" : channel.identifier!,
                      "client_ids" : item.identifier]
        
        if item.isFile {
            self.manager.postFileWith(url: item.url, identifier: params["client_ids"]!, name: "files", path: path, parameters: params, success: { (mappingResult) in
                let file = File()
                let dictionary = mappingResult.firstObject as! [String:String]
                let rawLink = dictionary[FileAttributes.rawLink.rawValue]
                file.identifier = params["client_ids"]
                file.rawLink = rawLink
                completion(file, nil)
                RealmUtils.save(file)
                }, failure: { (error) in
                    completion(nil, error)
            }) { (value) in
                progress(item.identifier, value)
            }
        } else {
            self.manager.post(image: item.image, identifier: params["client_ids"]!, name: "files", path: path, parameters: params, success: { (mappingResult) in
                let file = File()
                let dictionary = mappingResult.firstObject as! [String:String]
                let rawLink = dictionary[FileAttributes.rawLink.rawValue]
                file.identifier = params["client_ids"]
                file.rawLink = rawLink
                completion(file, nil)
                RealmUtils.save(file)
                }, failure: { (error) in
                    completion(nil, error)
            }) { (value) in
                progress(item.identifier, value)
            }
        }
    }
    
    func getInfo(fileId: String) {
        var file = RealmUtils.realmForCurrentThread().object(ofType: File.self, forPrimaryKey: fileId)
        let path = "teams/" + (DataManager.sharedInstance.currentTeam?.identifier)! + "/files/get_info" + file!.rawLink!
        
        self.manager.get(path: path, success: { (mappingResult, skipMapping) in
            let realm = RealmUtils.realmForCurrentThread()
            file = realm.object(ofType: File.self, forPrimaryKey: fileId)
            let result = mappingResult.firstObject as! File
            try! realm.write {
                file?.ext = result.ext
                file?.size = result.size
                file?.hasPreview = result.hasPreview
                file?.mimeType = result.mimeType
            }
            let notification = Notification(name: NSNotification.Name(Constants.NotificationsNames.ReloadFileSizeNotification),
                                            object: nil, userInfo: ["fileId" : fileId, "fileSize" : result.size])
            NotificationCenter.default.post(notification as Notification)
            
        }) { (error) in
            print(error?.message! ?? "getInfo_error")
        }
    }
    
    func download(fileId: String,
                         completion: @escaping (_ error: Mattermost.Error?) -> Void,
                         progress: @escaping (_ identifier: String, _ value: Float) -> Void) {
        for operation in self.downloadOperationsArray {
            if (operation.userInfo["identifier"] as! String) == fileId {
                return
            }
        }
        
        var file = File.objectById(fileId)
        let request: NSMutableURLRequest = NSMutableURLRequest(url: file!.downloadURL()!)
        request.httpMethod = "GET"
        
        let filePath = FileUtils.localLinkFor(file: file!)
        let operation: AFRKHTTPRequestOperation = AFRKHTTPRequestOperation(request: request as URLRequest!)
        operation.outputStream = OutputStream(toFileAtPath: filePath, append: false)
        operation.userInfo = ["identifier" : fileId]
        
        operation.setDownloadProgressBlock { (written: UInt, totalWritten: Int64, expectedToWrite: Int64) -> Void in
            let result = Float(totalWritten) / Float(expectedToWrite)
            print("downloading progress = ", result)
            progress(fileId, result)
        }
        
        operation.setCompletionBlockWithSuccess({ (operation: AFRKHTTPRequestOperation?, responseObject: Any?) in
            let realm = RealmUtils.realmForCurrentThread()
            file = realm.object(ofType: File.self, forPrimaryKey: fileId)
            try! realm.write {
                file?.downoloadedSize = (file?.size)!
                file?.localLink = filePath
            }
            print("downloading finished")
            self.downloadOperationsArray.removeObject(operation!)
            completion(nil)
        }, failure: { (operation: AFRKHTTPRequestOperation?, error: Swift.Error?) -> Void in
            self.downloadOperationsArray.removeObject(operation!)
            let realm = RealmUtils.realmForCurrentThread()
            file = realm.object(ofType: File.self, forPrimaryKey: fileId)
            FileUtils.removeLocalCopyOf(file: file!)
            try! realm.write {
                file?.downoloadedSize = 0
                file?.localLink = nil
            }
            guard (error as! NSError).code != -999 else { return }
            completion(Error.errorWithGenericError(error))
        })
        operation.start()
        self.downloadOperationsArray.append(operation)
    }
    
    func cancelDownloading(fileId: String) {
        for operation in self.downloadOperationsArray {
            if (operation.userInfo["identifier"] as! String) == fileId {
                operation.cancel()
                self.downloadOperationsArray.removeObject(operation)
                break
            }
        }
    }
}


//MARK: Interface
extension Api: Interface {
    func baseURL() -> URL! {
        return self.manager.httpClient.baseURL
    }
    
    func avatarLinkForUser(_ user: User) -> String {
        let path = SOCStringFromStringWithObject(UserPathPatternsContainer.avatarPathPattern(), user)
        let url = URL(string: path!, relativeTo: self.manager.httpClient.baseURL)
        return url!.absoluteString
    }
    
    func cancelSearchRequestFor(channel: Channel) {
        let path = SOCStringFromStringWithObject(PostPathPatternsContainer.searchingPathPattern(), channel)
        self.manager.cancelAllObjectRequestOperations(with: .any, matchingPathPattern: path)
    }
    
    func isNetworkReachable() -> Bool {
        return (self.networkReachabilityManager?.isReachable)!
    }
}
