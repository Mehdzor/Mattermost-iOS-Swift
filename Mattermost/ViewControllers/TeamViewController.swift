//
//  TeamViewController.swift
//  Mattermost
//
//  Created by Julia Samoshchenko on 02.09.16.
//  Copyright © 2016 Kilograpp. All rights reserved.
//

import Foundation
import RealmSwift

final class TeamViewController: UIViewController {
    
//MARK: Properties
    
    @IBOutlet weak var navigationView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var loaderView: UIView!
    
    var realm: Realm?
    fileprivate var results: Results<Team>! = nil
    fileprivate lazy var builder: TeamCellBuilder = TeamCellBuilder(tableView: self.tableView)
    
}


private protocol TeamViewControllerLifeCycle {
    func viewDidLoad()
}

private protocol TeamViewControllerSetup {
    func initialSetup()
    func setupTitleLabel()
    func setupTableView()
    func setupNavigationView()
}

private protocol TeamViewControllerAction {
    func backAction()
}

private protocol TeamViewControllerNavigation {
    func returnToPrevious()
}

private protocol TeamViewControllerConfiguration {
    func prepareResults()
}

private protocol TeamViewControllerRequest {
    func reloadChat()
}


//MARK: TeamViewControllerLifeCycle

extension TeamViewController: TeamViewControllerLifeCycle {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        initialSetup()
        prepareResults()
    }
}


//MARK: TeamViewControllerSetup

extension TeamViewController: TeamViewControllerSetup {
    func initialSetup() {
        setupNavigationBar()
        setupTitleLabel()
        setupTableView()
        setupNavigationView()
    }
    
    func setupNavigationBar() {
        let backButton = UIBarButtonItem.init(image: UIImage(named: "navbar_back_icon2"), style: .done, target: self, action: #selector(backAction))
        backButton.tintColor = UIColor.white
        self.navigationItem.leftBarButtonItem = backButton
    }
    
    func setupTableView() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.backgroundColor = ColorBucket.whiteColor
        self.tableView.register(TeamTableViewCell.classForCoder(), forCellReuseIdentifier: TeamTableViewCell.reuseIdentifier)
    }
    
    func setupTitleLabel() {
        self.titleLabel.font = FontBucket.titleURLFont
        self.titleLabel.text = Preferences.sharedInstance.siteName
        self.titleLabel.textColor = ColorBucket.whiteColor
    }
    
    func setupNavigationView() {
        let bgLayer = CAGradientLayer.blueGradientForNavigationBar()
        bgLayer.frame = CGRect(x:0,y:0,width:self.navigationView.bounds.width,height: self.navigationView.bounds.height)
        bgLayer.animateLayerInfinitely(bgLayer)
        self.navigationView.layer.insertSublayer(bgLayer, at: 0)
        self.navigationView.bringSubview(toFront: self.titleLabel)
    }
}


//MARK: TeamViewControllerAction

extension TeamViewController: TeamViewControllerAction {
    func backAction() {
        returnToPrevious()
    }
}


//MARK: TeamViewControllerNavigation

extension TeamViewController: TeamViewControllerNavigation {
    func returnToPrevious() {
        self.dismiss(animated: true, completion: nil)
    }
}


//MARK: TeamViewControllerConfiguration

extension  TeamViewController: TeamViewControllerConfiguration  {
    func prepareResults() {
        let sortName = TeamAttributes.displayName.rawValue
        self.results = RealmUtils.realmForCurrentThread().objects(Team.self).sorted(byProperty: sortName, ascending: true)
    }
}


//MARK: TeamViewControllerRequest

extension TeamViewController: TeamViewControllerRequest {
    func reloadChat() {
        //showLoaderView()
        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Constants.NotificationsNames.ChatLoadingStartNotification), object: nil))
        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Constants.NotificationsNames.UserLogoutNotificationName), object: nil))
        
        showLoaderView()
        
        RealmUtils.refresh()
        print("new team = ", Preferences.sharedInstance.currentTeamId)
        print("data = ", DataManager.sharedInstance.currentTeam?.identifier)
        Api.sharedInstance.loadTeams { (userShouldSelectTeam, error) in
            Api.sharedInstance.loadCurrentUser { (error) in
                Api.sharedInstance.loadChannels(with: { (error) in
                    Api.sharedInstance.loadCompleteUsersList({ (error) in
                        RouterUtils.loadInitialScreen()
                        NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: Constants.NotificationsNames.ChatLoadingStopNotification), object: nil))
                        
                        DispatchQueue.main.async{
                            self.dismiss(animated: true, completion:nil)
                            self.hideLoaderView()
                        }
                    })
                })
            }
        }
    }
}


//MARK: UITableViewDataSource

extension TeamViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let team = self.results[indexPath.row]
        return self.builder.cellFor(team: team, indexPath: indexPath)
    }
}


//MARK: UITableViewDelegate

extension TeamViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return self.builder.cellHeight()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let team = self.results[indexPath.row]
        
        guard (Preferences.sharedInstance.currentTeamId != nil) else {
            Preferences.sharedInstance.currentTeamId = team.identifier
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: Constants.NotificationsNames.UserTeamSelectNotification), object: nil)
            self.dismiss(animated: true, completion: nil)
            
            return
        }
        
        if (Preferences.sharedInstance.currentTeamId != team.identifier) {
            Preferences.sharedInstance.currentTeamId = team.identifier
            self.reloadChat()
        }
        else {
        self.dismiss(animated: true, completion: nil)
        }
    }
}

//MARK: LoaderView
extension TeamViewController {
    func showLoaderView() {
        (self.loaderView.subviews.first as! UIActivityIndicatorView).startAnimating()
        self.loaderView.isHidden = false
    }
    
    func hideLoaderView() {
        (self.loaderView.subviews.first as! UIActivityIndicatorView).startAnimating()
        self.loaderView.isHidden = false
    }
}
