//
//  SettingsViewController.swift
//  uwbapp
//
//  Created by Halbu on 4/28/24.
//

import UIKit
import os
import NearbyInteraction

public struct Settings {
    var pushNotificationEnabled: Bool?
    
    init() {
        pushNotificationEnabled = true
    }
}

extension UIImage {
    enum AssetIdnetifier: String {
        case SwitchOn = "switch_on.svg"
        case SwitchOff = "switch_off.svg"
    }
    convenience init(assetIdentifier: AssetIdnetifier){
        self.init(named: assetIdentifier.rawValue)!
    }
}

public var appSettings: Settings = Settings.init()

extension UIStackView {
    func copyStackView() -> UIStackView? {
        guard let archived = try? NSKeyedArchiver.archivedData(withRootObject: self,
                                                               requiringSecureCoding: false)
        else {
            fatalError("archivedData failed")
        }
        guard let copy = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(archived) as? UIStackView
        else {
            fatalError("unarchivedData failed")
        }
        
        return copy
    }
}

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var notificationSetting: UIButton!
    @IBOutlet weak var id: UITextField!
    
    let logger = os.Logger(subsystem: "com.uwblogin.capstoneUWB", category: "Settings")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        id.text = UserDefaults.standard.string(forKey: "UserID")
        
        if appSettings.pushNotificationEnabled!{
            notificationSetting.setImage(UIImage(assetIdentifier: .SwitchOn), for: .normal)
        }
        else {
            notificationSetting.setImage(UIImage(assetIdentifier: .SwitchOff), for: .normal)
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    @IBAction func backToMain(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func toggleNotification(_ sender: Any) {
        if appSettings.pushNotificationEnabled! {
            notificationSetting.setImage(UIImage(assetIdentifier: .SwitchOff), for: .normal)
            appSettings.pushNotificationEnabled = false
        }
        else {
            notificationSetting.setImage(UIImage(assetIdentifier: .SwitchOn), for: .normal)
            appSettings.pushNotificationEnabled = true
        }
    }
    
    @IBAction func saveID(_ sender: Any) {
        UserDefaults.standard.set(id.text, forKey: "UserID")
    }
}
