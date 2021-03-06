//
//  ChatViewController.swift
//  Mattermost
//
//  Created by Igor Vedeneev on 25.07.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import SlackTextViewController
import RealmSwift
import ImagePickerSheetController
import UITableView_Cache
import MFSideMenu

private protocol Setup {
    func initialSetup()
    func setupTableView()
    func setupInputBar()
    func setupTextView()
    func setupInputViewButtons()
    func setupToolbar()
    func setupRefreshControl()
    func setupPostAttachmentsView()
    func setupTopActivityIndicator()
    func setupCompactPost()
    func setupNoPostsLabel()
}

private protocol Private {
    func showAttachmentsView()
    func hideAttachmentsView()
    func showTopActivityIndicator()
    func hideTopActivityIndicator()
    func assignPhotos()
    func toggleSendButtonAvailability()
    func endRefreshing()
    func clearTextView()
}

private protocol Action {
    func leftMenuButtonAction(_ sender: AnyObject)
    func rigthMenuButtonAction(_ sender: AnyObject)
    func searchButtonAction(_ sender: AnyObject)
    func sendPostAction()
    func assignPhotosAction()
    func refreshControlValueChanged()
}

private protocol Navigation {
    func proceedToSearchChat()
    func proceedToProfileFor(user: User)
}

private protocol Request {
    func loadFirstPageAndReload()
    func loadFirstPageOfData()
    func loadNextPageOfData()
    func sendPost()
    func uploadAttachments()
}


final class ChatViewController: SLKTextViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
//MARK: Properties
    
    fileprivate var channel : Channel?
    fileprivate var resultsObserver: FeedNotificationsObserver! = nil
    fileprivate lazy var builder: FeedCellBuilder = FeedCellBuilder(tableView: self.tableView)
    override var tableView: UITableView! { return super.tableView }
    fileprivate let completePost: CompactPostView = CompactPostView.compactPostView(ActionType.Edit)
    fileprivate let postAttachmentsView = PostAttachmentsView()
    fileprivate let noPostsLabel: UILabel = UILabel()
    
    var refreshControl: UIRefreshControl?
    var topActivityIndicatorView: UIActivityIndicatorView?

    
    var hasNextPage: Bool = true
    var postFromSearch: Post! = nil
    var isLoadingInProgress: Bool = false
    
    var fileUploadingInProgress: Bool = true {
        didSet {
            self.toggleSendButtonAvailability()
        }
    }
    
    fileprivate var assignedAttachmentItemsArray = Array<AssignedAttachmentViewItem>()
    fileprivate var selectedAttachments = Array<AssignedAttachmentViewItem>()
    fileprivate var selectedPost: Post! = nil
    fileprivate var selectedAction: String = Constants.PostActionType.SendNew
    fileprivate var emojiResult: [String]?

}


//MARK: LifeСycle

extension ChatViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ChannelObserver.sharedObserver.delegate = self
        initialSetup()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationController?.isNavigationBarHidden = false
        addSLKKeyboardObservers()
        
        if (self.postFromSearch != nil) {
            changeChannelForPostFromSearch()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        removeSLKKeyboardObservers()
    }
    
    override class func tableViewStyle(for decoder: NSCoder) -> UITableViewStyle {
        return .grouped
    }
    
    func configureWithPost(post: Post) {
        self.postFromSearch = post
    }
    
    func changeChannelForPostFromSearch() {
        ChannelObserver.sharedObserver.selectedChannel = self.postFromSearch.channel
    }
}


//MARK: Setup

extension ChatViewController: Setup {
    func initialSetup() {
        setupInputBar()
        setupTableView()
        setupRefreshControl()
        setupPostAttachmentsView()
        setupTopActivityIndicator()
        setupLongCellSelection()
        setupCompactPost()
        setupNoPostsLabel()
    }
    
    func setupTableView() {
        self.tableView.separatorStyle = .none
        self.tableView.keyboardDismissMode = .onDrag
        self.tableView.backgroundColor = ColorBucket.whiteColor
        self.tableView.register(FeedCommonTableViewCell.self, forCellReuseIdentifier: FeedCommonTableViewCell.reuseIdentifier, cacheSize: 10)
        self.tableView.register(FeedAttachmentsTableViewCell.self, forCellReuseIdentifier: FeedAttachmentsTableViewCell.reuseIdentifier, cacheSize: 10)
        self.tableView.register(FeedFollowUpTableViewCell.self, forCellReuseIdentifier: FeedFollowUpTableViewCell.reuseIdentifier, cacheSize: 18)
        self.tableView.register(FeedTableViewSectionHeader.self, forHeaderFooterViewReuseIdentifier: FeedTableViewSectionHeader.reuseIdentifier())
        self.autoCompletionView.register(EmojiTableViewCell.classForCoder(), forCellReuseIdentifier: EmojiTableViewCell.reuseIdentifier)
        self.registerPrefixes(forAutoCompletion: [":"])
    }
    
    func setupInputBar() {
        setupTextView()
        setupInputViewButtons()
        setupToolbar()
    }
    
    func setupTextView() {
        self.shouldClearTextAtRightButtonPress = false;
        self.textView.delegate = self;
        self.textView.placeholder = "Type something..."
        self.textView.layer.borderWidth = 0;
        self.textInputbar.textView.font = FontBucket.inputTextViewFont;
    }
    
    func setupInputViewButtons() {
        self.rightButton.titleLabel!.font = FontBucket.feedSendButtonTitleFont;
        self.rightButton.setTitle("Send", for: UIControlState())
        self.rightButton.addTarget(self, action: #selector(sendPostAction), for: .touchUpInside)
        
        self.leftButton.setImage(UIImage(named: "common_attache_icon"), for: UIControlState())
        self.leftButton.tintColor = UIColor.gray
        self.leftButton.addTarget(self, action: #selector(attachmentSelection), for: .touchUpInside)
    }
    
    func setupToolbar() {
        self.textInputbar.autoHideRightButton = false;
        self.textInputbar.isTranslucent = false;
        self.textInputbar.barTintColor = ColorBucket.white
    }
    
    fileprivate func setupRefreshControl() {
        let tableVc = UITableViewController.init() as UITableViewController
        tableVc.tableView = self.tableView
        self.refreshControl = UIRefreshControl.init()
        self.refreshControl?.addTarget(self, action: #selector(refreshControlValueChanged), for: .valueChanged)
        tableVc.refreshControl = self.refreshControl
    }
    
    fileprivate func setupPostAttachmentsView() {
        self.postAttachmentsView.backgroundColor = UIColor.blue
        self.view.insertSubview(self.postAttachmentsView, belowSubview: self.textInputbar)
        self.postAttachmentsView.anchorView = self.textInputbar
        
        self.postAttachmentsView.dataSource = self
        self.postAttachmentsView.delegate = self
    }
    
    func setupTopActivityIndicator() {
        self.topActivityIndicatorView  = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        self.topActivityIndicatorView!.transform = self.tableView.transform;
    }
    
    func setupLongCellSelection() {
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(longPressAction))
        self.tableView.addGestureRecognizer(longPressGestureRecognizer)
    }
    
    func setupNoPostsLabel() {
        self.noPostsLabel.text = "No messages in this\n channel yet"
        self.noPostsLabel.textAlignment = .center
        self.noPostsLabel.numberOfLines = 0
        self.noPostsLabel.font = FontBucket.feedbackTitleFont
        self.noPostsLabel.textColor = UIColor.black
        self.noPostsLabel.backgroundColor = self.tableView.backgroundColor
        self.noPostsLabel.frame = CGRect(x: 0, y: 0, width: 280, height: 60)
        self.noPostsLabel.center = CGPoint(x: UIScreen.main.bounds.size.width / 2, y: 100)
        self.noPostsLabel.isHidden = true
        self.view.insertSubview(self.noPostsLabel, aboveSubview: self.tableView)
    }
    
    func setupCompactPost() {
        let size = self.completePost.requeredSize()
        self.completePost.translatesAutoresizingMaskIntoConstraints = false
        self.completePost.isHidden = true
        self.completePost.cancelHandler = {
            self.selectedPost = nil
            self.clearTextView()
            self.dismissKeyboard(true)
            self.completePost.isHidden = true
            self.configureRightButtonWithTitle("Send", action: Constants.PostActionType.SendNew)
        }
        
        self.view.addSubview(self.completePost)
        
        let horizontal = NSLayoutConstraint(item: self.completePost, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0)
        view.addConstraint(horizontal)
        let vertical = NSLayoutConstraint(item: self.completePost, attribute: .bottom, relatedBy: .equal, toItem: self.textView, attribute: .top, multiplier: 1, constant: 0)
        view.addConstraint(vertical)
        
        let width = NSLayoutConstraint(item: self.completePost, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: size.width)
        view.addConstraint(width)
        
        let height = NSLayoutConstraint(item: self.completePost, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: size.height)
        view.addConstraint(height)
    }
    
    override func textWillUpdate() {
        super.textWillUpdate()
        
        if (assignedAttachmentItemsArray.count > 0) {
            self.rightButton.isEnabled = self.fileUploadingInProgress
        }
    }
}


//MARK: Private

extension ChatViewController : Private {
//AttachmentsView
    func showAttachmentsView() {
        var oldInset = self.tableView.contentInset
        oldInset.top = PostAttachmentsView.attachmentsViewHeight
        self.tableView.contentInset = oldInset
    }
    
    func hideAttachmentsView() {
        var oldInset = self.tableView.contentInset
        oldInset.top = 0
        self.tableView.contentInset = oldInset
        self.view.layoutSubviews()
    }

//TopActivityIndicator
    func showTopActivityIndicator() {
        let activityIndicatorHeight = self.topActivityIndicatorView!.bounds.height
        let tableFooterView = UIView(frame:CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: activityIndicatorHeight * 2))
        self.topActivityIndicatorView!.center = CGPoint(x: tableFooterView.center.x, y: tableFooterView.center.y - activityIndicatorHeight / 5)
        tableFooterView.addSubview(self.topActivityIndicatorView!)
        self.tableView.tableFooterView = tableFooterView;
        self.topActivityIndicatorView!.startAnimating()
    }
    
    func attachmentSelection() {
        if (self.assignedAttachmentItemsArray.count < 5) {
            let controller = UIAlertController(title: "Attachment", message: "Choose what you want to attach?", preferredStyle: .actionSheet)
            let gallerySelectionAction = UIAlertAction(title: "Photo/Picture", style: .default, handler: { (action:UIAlertAction) in
                self.assignPhotos()
            })
            gallerySelectionAction.setValue(UIImage(named:"gallery_icon"), forKey: "image")
            controller.addAction(gallerySelectionAction)
            
            let fileSelectionAction = UIAlertAction(title: "File", style: .default, handler: { (action:UIAlertAction) in
                self.proceedToFileSelection()
            })
            fileSelectionAction.setValue(UIImage(named:"iCloud_icon"), forKey: "image")
            controller.addAction(fileSelectionAction)
            controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action:UIAlertAction) in
                print("canceled")
            }))
            present(controller, animated: true) {}
        } else {
            AlertManager.sharedManager.showWarningWithMessage(message: "Maximum of attachments reached", viewController: self)
        }
    }
    
    func hideTopActivityIndicator() {
        self.topActivityIndicatorView!.stopAnimating()
        self.tableView.tableFooterView = UIView(frame: CGRect.zero)
    }
 
//Images
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if ((info["UIImagePickerControllerMediaType"] as! String) == "public.movie") {
            let fileItem = AssignedAttachmentViewItem(image: UIImage(named: "attach_file_icon")!)
            let url = info["UIImagePickerControllerMediaURL"] as! URL
            fileItem.fileName = File.fileNameFromUrl(url: url)
            fileItem.isFile = true
            fileItem.url = url
            self.selectedAttachments = [ fileItem ]
            self.postAttachmentsView.showAnimated()
            self.showAttachmentsView()
            self.postAttachmentsView.updateAppearance()
            uploadAttachments()
        } else {
            var image = info["UIImagePickerControllerOriginalImage"] as! UIImage
            //TODO: 0 -> constants 
            image = image.fixedOrientation()
            let presentImage = UIImage(data:UIImageJPEGRepresentation(image, 0)!)
//            let orientedImage = UIImage(cgImage: image.cgImage!, scale: 0, orientation: .up)
            let imageItem = AssignedAttachmentViewItem(image: presentImage!)
            self.selectedAttachments = [imageItem]
            self.postAttachmentsView.showAnimated()
            self.showAttachmentsView()
            self.postAttachmentsView.updateAppearance()
            uploadAttachments()
        }
        picker.dismiss(animated: true) { }
    }
    
    func assignPhotos() -> Void {
        //TODO: MORE REFACTOR
        let presentImagePickerController: (UIImagePickerControllerSourceType, UIImagePickerControllerCameraCaptureMode) -> () = { source, cameraMode in
            let picker = UIImagePickerController()
            picker.delegate = self
            let sourceType = source
            picker.sourceType = sourceType
            if sourceType == .camera {
                if cameraMode == .video {
                    picker.mediaTypes = ["public.movie"]
                }
            picker.cameraCaptureMode = cameraMode
            }
            self.present(picker, animated: true, completion: nil)
        }
        
        let controller = ImagePickerSheetController(mediaType: .imageAndVideo)
        controller.maximumSelection = 5 - self.assignedAttachmentItemsArray.count
        print("Images to selection:\(controller.maximumSelection)")
        let assignImagesHandler = {
            let convertedAssets = AssetsUtils.convertedArrayOfAssets(controller.selectedImageAssets)
            self.selectedAttachments = convertedAssets
            self.postAttachmentsView.showAnimated()
            self.showAttachmentsView()
            self.postAttachmentsView.updateAppearance()
            self.uploadAttachments()
        }
    
    
        let cameraAction = ImagePickerAction(title: "Gallery", secondaryTitle: "Send", style: .default, handler: { _ in
                presentImagePickerController(.photoLibrary, .photo)
            }) { (_, numberOfPhotos) in
                assignImagesHandler()
            }
        controller.addAction(cameraAction)
        
        let videoAction = ImagePickerAction(title: "Take Video", secondaryTitle: "Take Video", style: .default, handler: { _ in
            presentImagePickerController(.camera, .video)
        }) { (_, numberOfPhotos) in
            presentImagePickerController(.camera, .video)
        }
        controller.addAction(videoAction)
        
        let photoAction = ImagePickerAction(title: "Take Photo", secondaryTitle: "Take Photo", style: .default, handler: { _ in
            presentImagePickerController(.camera, .photo)
        }) { (_, numberOfPhotos) in
            presentImagePickerController(.camera, .photo)
        }
        controller.addAction(photoAction)
        
        
        controller.addAction(ImagePickerAction(cancelTitle: NSLocalizedString("Cancel", comment: "Action Title")))
        present(controller, animated: true, completion: nil)
    }

//Interface
    func toggleSendButtonAvailability() {
        DispatchQueue.main.async { [unowned self] in
            self.rightButton.isEnabled = self.fileUploadingInProgress
        }
    }
    
    func endRefreshing() {
        self.noPostsLabel.isHidden = (self.resultsObserver.numberOfSections() > 0)
        self.refreshControl?.endRefreshing()
    }
    
    func clearTextView() {
        self.textView.text = nil
    }
    
    func configureRightButtonWithTitle(_ title: String, action: String) {
            self.rightButton.setTitle(title, for: UIControlState())
            self.selectedAction = action
    }
    
    func showActionSheetControllerForPost(_ post: Post) {
        
        let actionSheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        self.selectedPost = post
        
        let replyAction = UIAlertAction(title: "Reply", style: .default) { action -> Void in
            self.selectedPost = post
            self.completePost.configureWithPost(self.selectedPost, action: ActionType.Reply)
            self.configureRightButtonWithTitle("Send", action: Constants.PostActionType.SendReply)
            self.completePost.isHidden = false
            self.presentKeyboard(true)
        }
        actionSheetController.addAction(replyAction)
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
            self.selectedPost = nil
        }
        actionSheetController.addAction(cancelAction)
        
        if (post.author.identifier == Preferences.sharedInstance.currentUserId) {
            let editAction = UIAlertAction(title: "Edit", style: .default) { action -> Void in
                //self.selectedPost = post
                self.completePost.configureWithPost(self.selectedPost, action: ActionType.Edit)
                self.completePost.isHidden = false
                self.configureRightButtonWithTitle("Save", action: Constants.PostActionType.SendUpdate)
                self.presentKeyboard(true)
                self.textView.text = self.selectedPost.message
            }
            actionSheetController.addAction(editAction)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { action -> Void in
                self.selectedAction = Constants.PostActionType.DeleteOwn
                self.deletePost()
            }
            actionSheetController.addAction(deleteAction)
        }
        
        self.present(actionSheetController, animated: true, completion: nil)
    }

    fileprivate func showCompletePost(_ post: Post, action: String) {
        
    }
}


//MARK: Action

extension ChatViewController: Action {
    @IBAction func leftMenuButtonAction(_ sender: AnyObject) {
        self.menuContainerViewController.setMenuState(MFSideMenuStateLeftMenuOpen, completion: nil)
    }
    
    @IBAction func rigthMenuButtonAction(_ sender: AnyObject) {
        self.menuContainerViewController.setMenuState(MFSideMenuStateRightMenuOpen, completion: nil)
    }
    
    @IBAction func searchButtonAction(_ sender: AnyObject) {
        proceedToSearchChat()
    }
    
    func sendPostAction() {
        switch self.selectedAction {
        case Constants.PostActionType.SendReply:
            sendPostReply()
        case Constants.PostActionType.SendUpdate:
            updatePost()
        default:
            sendPost()
        }
        self.assignedAttachmentItemsArray.removeAll()
        self.selectedAttachments.removeAll()
        self.postAttachmentsView.hideAnimated()
        self.hideAttachmentsView()
    }
    
    func assignPhotosAction() {
        assignPhotos()
    }
    
    func refreshControlValueChanged() {
        self.loadFirstPageOfData()
    }
    
    func longPressAction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        guard let indexPath = self.tableView.indexPathForRow(at: gestureRecognizer.location(in: self.tableView)) else { return }
        let post = resultsObserver?.postForIndexPath(indexPath)
        showActionSheetControllerForPost(post!)
    }
    
    func resendAction(_ post:Post) {
        PostUtils.sharedInstance.resendPost(post) { _ in }
    }
}


//MARK: Navigation

extension ChatViewController: Navigation {
    func proceedToSearchChat() {
        let transaction = CATransition()
        transaction.duration = 0.3
        transaction.timingFunction = CAMediaTimingFunction.init(name: kCAMediaTimingFunctionEaseInEaseOut)
        transaction.type = kCATransitionMoveIn
        transaction.subtype = kCATransitionFromBottom
        self.navigationController!.view.layer.add(transaction, forKey: kCATransition)
        let identifier = String(describing: SearchChatViewController.self)
        let searchChat = self.storyboard?.instantiateViewController(withIdentifier: identifier) as! SearchChatViewController
        searchChat.configureWithChannel(channel: self.channel!)
        self.navigationController?.pushViewController(searchChat, animated: false)
    }
    
    func proceedToProfileFor(user: User) {
        let storyboard = UIStoryboard.init(name: "Profile", bundle: nil)
        let profile = storyboard.instantiateInitialViewController()
        (profile as! ProfileViewController).configureFor(user: user)
        let navigation = self.menuContainerViewController.centerViewController
        (navigation! as AnyObject).pushViewController(profile!, animated:true)
    }
}


//MARK: Requests

extension ChatViewController: Request {
    func loadFirstPageAndReload() {
        self.isLoadingInProgress = true
        Api.sharedInstance.loadFirstPage(self.channel!, completion: { (error) in
            self.perform(#selector(self.endRefreshing), with: nil, afterDelay: 0.05)
            self.isLoadingInProgress = false
            self.hasNextPage = true
        })
    }
    func loadFirstPageOfData() {
        print("loadFirstPageOfData")
        self.isLoadingInProgress = true
        
        let activityIndicatorView  = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.gray)
        activityIndicatorView.center = self.tableView.center
        activityIndicatorView.startAnimating()
        self.tableView.addSubview(activityIndicatorView)
        
        Api.sharedInstance.loadFirstPage(self.channel!, completion: { (error) in
            activityIndicatorView.removeFromSuperview()
            self.perform(#selector(self.endRefreshing), with: nil, afterDelay: 0.05)
            self.isLoadingInProgress = false
            self.hasNextPage = true
        })
    }
    
    func loadNextPageOfData() {
        print("loadNextPageOfData")
        guard !self.isLoadingInProgress else { return }
        
        self.isLoadingInProgress = true
        showTopActivityIndicator()
        Api.sharedInstance.loadNextPage(self.channel!, fromPost: resultsObserver.lastPost()) { (isLastPage, error) in
            self.hasNextPage = !isLastPage
            self.isLoadingInProgress = false
            self.hideTopActivityIndicator()
        
            self.resultsObserver.prepareResults()
        }
    }
    
    func loadPostsBeforePost(post: Post, shortSize: Bool? = false) {
        print("loadPostsBeforePost")
        guard !self.isLoadingInProgress else { return }
        
        self.isLoadingInProgress = true
        Api.sharedInstance.loadPostsBeforePost(post: post, shortList: shortSize) { (isLastPage, error) in
            self.hasNextPage = !isLastPage
            if !self.hasNextPage {
                self.postFromSearch = nil
                return
            }
            
            self.isLoadingInProgress = false
            self.resultsObserver.prepareResults()
            self.loadPostsAfterPost(post: post, shortSize: true)
        }
    }
    
    func loadPostsAfterPost(post: Post, shortSize: Bool? = false) {
        print("loadPostsAfterPost")
        guard !self.isLoadingInProgress else { return }
        
        self.isLoadingInProgress = true
        Api.sharedInstance.loadPostsAfterPost(post: post, shortList: shortSize) { (isLastPage, error) in
            self.hasNextPage = !isLastPage
            self.isLoadingInProgress = false
            
            self.resultsObserver.unsubscribeNotifications()
            self.resultsObserver.prepareResults()
            self.resultsObserver.subscribeNotifications()
            
            let indexPath =  self.resultsObserver.indexPathForPost(post)
            self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    func sendPost() {
        PostUtils.sharedInstance.sentPostForChannel(with: self.channel!, message: self.textView.text, attachments: nil) { (error) in
            if (error != nil) {
                AlertManager.sharedManager.showErrorWithMessage(message: (error?.message!)!, viewController: self)
            }
        }
        self.dismissKeyboard(true)
        self.clearTextView()
    }
    
    func sendPostReply() {
        guard (self.selectedPost != nil) else { return }
        
        PostUtils.sharedInstance.sendReplyToPost(self.selectedPost, channel: self.channel!, message: self.textView.text, attachments: nil) { (error) in
            if (error != nil) {
                AlertManager.sharedManager.showErrorWithMessage(message: (error?.message!)!, viewController: self)
            }
            self.selectedPost = nil
        }
        self.selectedAction = Constants.PostActionType.SendNew
        self.clearTextView()
        self.dismissKeyboard(true)
    }
    
    func updatePost() {
        guard (self.selectedPost != nil) else { return }
    
        PostUtils.sharedInstance.updateSinglePost(self.selectedPost, message: self.textView.text, attachments: nil, completion: { (error) in
            self.selectedPost = nil
        })
        self.configureRightButtonWithTitle("Send", action: Constants.PostActionType.SendUpdate)
        self.dismissKeyboard(true)
        self.selectedAction = Constants.PostActionType.SendNew
        self.clearTextView()
    }
    
    func deletePost() {
        guard (self.selectedPost != nil) else { return }
        
        PostUtils.sharedInstance.deletePost(self.selectedPost) { (error) in
            self.selectedAction = Constants.PostActionType.SendNew
            RealmUtils.deleteObject(self.selectedPost)
            self.selectedPost = nil
        }
    }
    
    func uploadAttachments() {
        self.fileUploadingInProgress = false
        //Собственный array для images (передавать в images: ...). Это массив с выбранными картинками.
        let images = selectedAttachments
        assignedAttachmentItemsArray.append(contentsOf: self.selectedAttachments)
        PostUtils.sharedInstance.uploadAttachment(self.channel!, items: images, completion: { (finished, error, item) in
            if error != nil {
                //TODO: handle error
                //refactor обработка этой ошибки в отдельную функцию
                AlertManager.sharedManager.showErrorWithMessage(message: (error?.message!)!, viewController: self)
                // Обработка item, который закончился с error
                self.assignedAttachmentItemsArray.removeObject(item)
                self.postAttachmentsView.updateAppearance()
                if (self.assignedAttachmentItemsArray.count == 0) {
                    self.postAttachmentsView.hideAnimated()
                    self.hideAttachmentsView()
                }
            } else {
                self.fileUploadingInProgress = finished
                print ("\(item.identifier) uploaded: \(finished)")
                print ("All files uploaded: \(finished)")
            }
        }) { (value, index) in
            self.assignedAttachmentItemsArray[index].uploaded = value == 1
            self.assignedAttachmentItemsArray[index].uploading = value < 1
            self.assignedAttachmentItemsArray[index].uploadProgress = value
            self.postAttachmentsView.updateProgressValueAtIndex(index, value: value)
        }
    }
}


//MARK: UITableViewDataSource

extension ChatViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        if (tableView == self.tableView) {
            return self.resultsObserver?.numberOfSections() ?? 1
        }
        
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (tableView == self.tableView) {
            return self.resultsObserver?.numberOfRows(section) ?? 0
        }
        
        return (self.emojiResult != nil) ? (self.emojiResult?.count)! : 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if (tableView == self.tableView) {
            let post = resultsObserver?.postForIndexPath(indexPath)
            if self.hasNextPage && self.tableView.offsetFromTop() < 200 {
                self.loadNextPageOfData()
            }
        
            let errorHandler = { (post:Post) in
                self.errorAction(post)
            }
            
            let cell = self.builder.cellForPost(post!, errorHandler: errorHandler)
            if (cell.isKind(of: FeedCommonTableViewCell.self)) {
                (cell as! FeedCommonTableViewCell).avatarTapHandler = {
                    self.proceedToProfileFor(user: (post?.author)!)
                }
            }
            
            return cell
        }
        else {
            return autoCompletionCellForRowAtIndexPath(indexPath)
        }
    }
}


//MARK: UITableViewDelegate

extension ChatViewController {
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard tableView == self.tableView else { return nil }
        guard resultsObserver != nil else { return UIView() }
        var view = tableView.dequeueReusableHeaderFooterView(withIdentifier: FeedTableViewSectionHeader.reuseIdentifier()) as? FeedTableViewSectionHeader
        if view == nil {
            view = FeedTableViewSectionHeader(reuseIdentifier: FeedTableViewSectionHeader.reuseIdentifier())
        }
        let frcTitleForHeader = resultsObserver.titleForHeader(section)
        let titleDate = DateFormatter.sharedConversionSectionsDateFormatter?.date(from: frcTitleForHeader)!
        let titleString = titleDate?.feedSectionDateFormat()
        view!.configureWithTitle(titleString!)
        view!.transform = tableView.transform
        
        return view!
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return (tableView == self.tableView) ? FeedTableViewSectionHeader.height() : 0
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (tableView == self.tableView) {
            let post = resultsObserver?.postForIndexPath(indexPath)
            return self.builder.heightForPost(post!)
        }
        
        return 40
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (tableView == self.autoCompletionView) {
            guard let emojiResult = self.emojiResult else { return }
            var item = emojiResult[indexPath.row]
            if (self.foundPrefix == ":") {
                item += ":"
            }
            
            item += " "
            
            self.acceptAutoCompletion(with: item, keepPrefix: true)
        }
    }
}



//MARK: ChannelObserverDelegate

extension ChatViewController: ChannelObserverDelegate {

    func didSelectChannelWithIdentifier(_ identifier: String!) -> Void {
        //old channel
        //unsubscribing from realm and channelActions
        if resultsObserver != nil {
            resultsObserver.unsubscribeNotifications()
        }
        self.resultsObserver = nil
        self.noPostsLabel.isHidden = true
        if self.channel != nil {
            //remove action observer from old channel
            //after relogin
            NotificationCenter.default.removeObserver(self,
                                                    name: NSNotification.Name(ActionsNotification.notificationNameForChannelIdentifier(channel?.identifier)),
                                                    object: nil)
        }
        
        self.typingIndicatorView?.dismissIndicator()
        
        //new channel
        self.channel = try! Realm().objects(Channel.self).filter("identifier = %@", identifier).first!
        self.title = self.channel?.displayName
        self.resultsObserver = FeedNotificationsObserver(tableView: self.tableView, channel: self.channel!)
        
        if (self.postFromSearch == nil) {
            self.loadFirstPageOfData()
        }
        else {
            loadPostsBeforePost(post: self.postFromSearch, shortSize: true)
        }
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleChannelNotification),
                                                         name: NSNotification.Name(ActionsNotification.notificationNameForChannelIdentifier(channel?.identifier)),
                                                         object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLogoutNotification),
                                                         name: NSNotification.Name(rawValue: Constants.NotificationsNames.UserLogoutNotificationName),
                                                         object: nil)
    }
}


//MARK: PostAttachmentViewDataSource

extension ChatViewController: PostAttachmentViewDataSource {
    func itemAtIndex(_ index: Int) -> AssignedAttachmentViewItem {
        return self.assignedAttachmentItemsArray[index]
    }
    
    func numberOfItems() -> Int {
        return self.assignedAttachmentItemsArray.count
    }
}


//MARK: PostAttachmentViewDelegate

extension ChatViewController: PostAttachmentViewDelegate {
    func didRemovePhoto(_ item: AssignedAttachmentViewItem) {
        PostUtils.sharedInstance.cancelImageItemUploading(item)
        self.assignedAttachmentItemsArray.removeObject(item)
        guard self.assignedAttachmentItemsArray.count != 0 else {
            self.fileUploadingInProgress = false
            self.postAttachmentsView.hideAnimated()
            self.hideAttachmentsView()
            return
        }
    }
    
    func attachmentsViewWillAppear() {
        var oldInset = self.tableView.contentInset
        oldInset.bottom = PostAttachmentsView.attachmentsViewHeight
        self.tableView.contentInset = oldInset
    }
    
    func attachmentViewWillDisappear() {
        var oldInset = self.tableView.contentInset
        oldInset.top = 0
        self.tableView.contentInset = oldInset
    }
}


//MARK: Handlers
extension ChatViewController {
    func handleChannelNotification(_ notification: Notification) {
        if let actionNotification = notification.object as? ActionsNotification {
            let user = User.self.objectById(actionNotification.userIdentifier)
            switch (actionNotification.event!) {
            case .Typing:
                //refactor (to methods)
                if (actionNotification.userIdentifier != Preferences.sharedInstance.currentUserId) {
                    typingIndicatorView?.insertUsername(user?.displayName)
                }
            default:
                typingIndicatorView?.removeUsername(user?.displayName)
            }
        }
    }
    
    func handleLogoutNotification() {
        self.channel = nil
        self.resultsObserver = nil
        ChannelObserver.sharedObserver.delegate = nil
    }
    
    func errorAction(_ post: Post) {
        let controller = UIAlertController(title: "Your message was not sent", message: "Tap resend to send this message again", preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Resend", style: .default, handler: { (action:UIAlertAction) in
            self.resendAction(post)
        }))
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            print("Cancelled")
            }))
        present(controller, animated: true) {}
    }
}


//MARK: UITextViewDelegate

extension ChatViewController {
    func addSLKKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleKeyboardWillHideeNotification), name: NSNotification.Name.SLKKeyboardWillHide, object: nil)
    }
    
    func removeSLKKeyboardObservers() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.SLKKeyboardWillHide, object: nil)
    }
    
    func handleKeyboardWillHideeNotification() {
        self.completePost.isHidden = true
    }
    
    override func textViewDidChange(_ textView: UITextView) {
        SocketManager.sharedInstance.sendNotificationAboutAction(.Typing, channel: channel!)
    }
}


//MARK: UIDocumentPickerDelegate
extension ChatViewController: UIDocumentPickerDelegate {
    func proceedToFileSelection() {
        
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.content"], in: .import)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        self.present(documentPicker, animated:true, completion:nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        //TODO: REFACTOR mechanism

        let fileItem = AssignedAttachmentViewItem(image: UIImage(named: "attach_file_icon")!)
        fileItem.fileName = File.fileNameFromUrl(url: url)
        fileItem.isFile = true
        fileItem.url = url
        self.selectedAttachments = [ fileItem ]
        self.postAttachmentsView.showAnimated()
        self.showAttachmentsView()
        self.postAttachmentsView.updateAppearance()
        self.uploadAttachments()
    }
}

//MARK: AutoCompletionView

extension ChatViewController {
    func autoCompletionCellForRowAtIndexPath(_ indexPath: IndexPath) -> EmojiTableViewCell {
        let cell = self.autoCompletionView.dequeueReusableCell(withIdentifier: EmojiTableViewCell.reuseIdentifier) as! EmojiTableViewCell
        cell.selectionStyle = .default
        
        guard let searchResult = self.emojiResult else { return cell }
        guard let prefix = self.foundPrefix else { return cell }
        
        let text = searchResult[indexPath.row]
        let originalIndex = Constants.EmojiArrays.mattermost.index(of: text)
        cell.configureWith(index: originalIndex)
        
        return cell
    }
    
    override func shouldProcessText(forAutoCompletion text: String) -> Bool {
        return true
    }
    
    override func didChangeAutoCompletionPrefix(_ prefix: String, andWord word: String) {
        var array:Array<String> = []
        self.emojiResult = nil
        
        if (prefix == ":") && word.characters.count > 0 {
            array = Constants.EmojiArrays.mattermost.filter { NSPredicate(format: "self BEGINSWITH[c] %@", word).evaluate(with: $0) };
        }
        
        var show = false
        if array.count > 0 {
            let sortedArray = array.sorted { $0.localizedCaseInsensitiveCompare($1) == ComparisonResult.orderedAscending }
            self.emojiResult = sortedArray
            show = sortedArray.count > 0
        }
        
        self.showAutoCompletionView(show)
    }
    
    override func heightForAutoCompletionView() -> CGFloat {
        guard let smilesResult = self.emojiResult else { return 0 }
        let cellHeight = (self.autoCompletionView.delegate?.tableView!(self.autoCompletionView, heightForRowAt: IndexPath(row: 0, section: 0)))!
        
        return cellHeight * CGFloat(smilesResult.count)
    }
}
