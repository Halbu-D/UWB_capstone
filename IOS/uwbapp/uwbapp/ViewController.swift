//
//  ViewController.swift
//  uwbapp
//
//  Created by Halbu on 4/26/24.
//

import UIKit
import NearbyInteraction
import os.log

enum MessageId: UInt8 {
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    case accessoryPaired = 0x4
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
    
    // User defined/notification messages
    case getReserved = 0x20
    case setReserved = 0x21

    case iOSNotify = 0x2F
}

protocol TableProtocol: AnyObject {
    func buttonAction(_ sender: UIButton)
    func sendStopToDevice(_ deviceID: Int)
}

class ViewController: UIViewController, TableProtocol{
    
    @IBOutlet weak var mainStackView: UIStackView!
    
    // 모든 view
    let separatorView = SeparatorView(fieldTitle: "근처 장치")
    let accessoriesTable = AccessoriesTable()
    
    var dataChannel = DataCommunicationChannel()
    var notifier = NotificationManager.instance
    
    var configuration: NINearbyAccessoryConfiguration?
    // Dictionary to associate each NI Session to the using the uniqueID
    var referenceDict = [Int:NISession]()
    // A mapping from a discovery token to a name.
    var accessoryMap = [NIDiscoveryToken: String]()
    let savedSettings = UserDefaults.standard
    
    let logger = os.Logger(subsystem: "com.capstone.uwbapp", category: "ViewController")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Notification from Settings View Controller
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(clearKnownDevices),name: Notification.Name("clearKnownDevices"), object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(settingsNotification),
                                               name: Notification.Name("settingsNotification"),
                                               object: nil)
        notifier.requestAuthorization()
        
        if let state = savedSettings.object(forKey: "settingsNotification") as? Bool {
            appSettings.pushNotificationEnabled = state
        }
        
        // Set delegate to allow "accessoriesTable" to use TableProtocol
        accessoriesTable.tableDelegate = self
        
        mainStackView.insertArrangedSubview(separatorView, at: 0)
        mainStackView.insertArrangedSubview(accessoriesTable, at: 1)
        mainStackView.overrideUserInterfaceStyle = .light
        
        // Prepare the data communication channel.
        dataChannel.accessorySynchHandler = accessorySynch
        dataChannel.accessoryPairHandler = accessoryPaired
        dataChannel.accessoryConnectedHandler = accessoryConnected
        dataChannel.accessoryDisconnectedHandler = accessoryDisconnected
        dataChannel.accessoryDataHandler = accessorySharedData
        dataChannel.start()
        
        logger.info("액세서리 스캔중")
    }
    ////여기까지
    ///
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    @objc func clearKnownDevices(notification: NSNotification) {
        dataChannel.clearKnownDevices()
    }
    
    @objc func settingsNotification(notification: NSNotification) {
        savedSettings.set(appSettings.pushNotificationEnabled, forKey: "settingsNotification")
    }
    
    @IBAction func buttonAction(_ sender: UIButton) {
        let deviceID = sender.tag
        
        reqConnectionByID(deviceID)
        logger.info("Action Button pressed for device \(deviceID)")
    }
    
    func reqConnectionByID(_ deviceID: Int) {
        // Get qorvo device that's match with sender's tag
        if let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            // Connect to the accessory
            if qorvoDevice.blePeripheralStatus == statusDiscovered {
                logger.info("Connecting to Accessory")
                connectToAccessory(deviceID)
            }
            else {
                return
            }

            // Edit cell for this sender
            accessoriesTable.setCellAsset(deviceID, .connecting)
        }
    }
    
    // MARK: - Data Channel functions and callbacks
    func sendStopToDevice(_ deviceID: Int) {
        let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        
        if qorvoDevice?.blePeripheralStatus != statusDiscovered {
            sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)
        }
    }
    
    // MARK: - Data channel methods
    func accessorySharedData(data: Data, accessoryName: String, deviceID: Int) {
        // The accessory begins each message with an identifier byte.
        // Ensure the message length is within a valid range.
        if data.count < 1 {
            logger.debug("Accessory shared data length was less than 1.")
            return
        }
        
        // Assign the first byte which is the message identifier.
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) is not a valid MessageId.")
        }
        
        // Handle the data portion of the message based on the message identifier.
        switch messageId {
        case .accessoryConfigurationData:
            // Access the message data by skipping the message identifier.
            assert(data.count > 1)
            let message = data.advanced(by: 1)
            setupAccessory(message, name: accessoryName, deviceID: deviceID)
        case .accessoryUwbDidStart:
            handleAccessoryUwbDidStart(deviceID)
        case .accessoryUwbDidStop:
            handleAccessoryUwbDidStop(deviceID)
        case .accessoryPaired:
            accessoryPaired(data: data, deviceID: deviceID)
        case .configureAndStart:
            fatalError("Accessory should not send 'configureAndStart'.")
        case .initialize:
            fatalError("Accessory should not send 'initialize'.")
        case .stop:
            fatalError("Accessory should not send 'stop'.")
        // User defined/notification messages
        case .getReserved:
            logger.debug("Get not implemented in this version")
        case .setReserved:
            logger.debug("Set not implemented in this version")
        case .iOSNotify:
            if appSettings.pushNotificationEnabled! {
                let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
                
                if let message = String(bytes: data.advanced(by: 3), encoding: .utf8) {
                    notifier.setNotification(deviceName: qorvoDevice!.blePeripheralName,
                                             deviceMessage: message)
                }
            }
        }
    }
    
    func accessorySynch(_ index: Int,_ deviceID: Int, insert: Bool ) {
        accessoriesTable.handleCell(index, insert)
        
        if insert, dataChannel.checkPairedDevice(deviceID) {
            reqConnectionByID(deviceID)
        }
    }
    
    func accessoryUpdate() {
        // Update cells based on their status
        uwbDevices.forEach { (qorvoDevice) in
            if qorvoDevice?.blePeripheralStatus == statusDiscovered {
                accessoriesTable.setCellAsset(qorvoDevice!.bleUniqueID,
                                              .actionButton)
            }
        }
    }
    
    func accessoryConnected(deviceID: Int) {
        pairToAccessory(deviceID)
    }
    
    func accessoryPaired(data: Data, deviceID: Int) {
        // Add device if not added yet
        if !(dataChannel.checkPairedDevice(deviceID)) {
            dataChannel.includePairedDevice(deviceID, "test")
        }
        
        // Create a NISession for the new device
        referenceDict[deviceID] = NISession()
        referenceDict[deviceID]?.delegate = self
        
        logger.info("Requesting configuration data from accessory")
        let msg = Data([MessageId.initialize.rawValue])
        
        sendDataToAccessory(msg, deviceID)
    }
    
    func accessoryDisconnected(deviceID: Int) {
        referenceDict[deviceID]?.invalidate()
        // Remove the NI Session and Location values related to the device ID
        referenceDict.removeValue(forKey: deviceID)
        
        accessoryUpdate()
        
        // Update device list and take other actions depending on the amount of devices
        //let deviceCount = uwbDevices.count
        //memo
    }
    
    // MARK: - Accessory messages handling
    func setupAccessory(_ configData: Data, name: String, deviceID: Int) {
        logger.info("Received configuration data from '\(name)'. Running session.")
        
        // Get peerIdentifier from the connected device
        let peerDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        let peerIdentifier = peerDevice!.blePeripheral.identifier

        do {
            configuration = try NINearbyAccessoryConfiguration(accessoryData: configData,
                                                               bluetoothPeerIdentifier: peerIdentifier)
        } catch {
            // Stop and display the issue because the incoming data is invalid.
            // In your app, debug the accessory data to ensure an expected
            // format.
            logger.info("Failed to create NINearbyAccessoryConfiguration for '\(name)'. Error: \(error)")
            return
        }
        
        // Cache the token to correlate updates with this accessory.
        cacheToken(configuration!.accessoryDiscoveryToken, accessoryName: name)
        
        referenceDict[deviceID]?.run(configuration!)
        logger.info("Accessory Background Session configured.")
    }
    
    func handleAccessoryUwbDidStart(_ deviceID: Int) {
        logger.info("Accessory Session started.")
        
        // Update the device Status
        if let startedDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            startedDevice.blePeripheralStatus = statusRanging
        }
        
        accessoriesTable.setCellAsset(deviceID, .miniLocation)
    }
    
    func handleAccessoryUwbDidStop(_ deviceID: Int) {
        logger.info("Accessory Session stopped.")
        
        // Disconnect from device
        disconnectFromAccessory(deviceID)
    }
    
    func updateMiniFields(_ deviceID: Int) {
        //새로 얻은 정보를 갱신함
        let uwbDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        if uwbDevice == nil { return }
        
        // Get updated location values
        let distance  = uwbDevice?.uwbDistance
        
        // Update the "accessoriesTable" cell with the given values
        accessoriesTable.updateCell(deviceID, distance!)
        
    }
    
}

// MARK: - `NISessionDelegate`.
extension ViewController: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {
        guard object.discoveryToken == configuration?.accessoryDiscoveryToken else { return }
        
        // Prepare to send a message to the accessory.
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Sending shareable configuration bytes: \(str)")
        
        // Send the message to the correspondent accessory.
        sendDataToAccessory(msg, deviceIDFromSession(session))
        logger.info("Sent shareable configuration data")
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard let distance  = accessory.distance else { return }
        
        let deviceID = deviceIDFromSession(session)
        //logger.info(NISession.deviceCapabilities)
    
        if let updatedDevice = dataChannel.getDeviceFromUniqueID(deviceID) {
            // set updated values
            updatedDevice.uwbDistance = distance
            updatedDevice.blePeripheralStatus = statusRanging
        }
        
        updateMiniFields(deviceID)
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // Retry the session only if the peer timed out.
        guard reason == .timeout else { return }
        logger.info("Session timed out")
        
        // The session runs with one accessory.
        guard let accessory = nearbyObjects.first else { return }
        
        // Clear the app's accessory state.
        accessoryMap.removeValue(forKey: accessory.discoveryToken)
        
        // Get the deviceID associated to the NISession
        let deviceID = deviceIDFromSession(session)
        
        // Consult helper function to decide whether or not to retry.
        if shouldRetry(deviceID) {
            sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)
            sendDataToAccessory(Data([MessageId.initialize.rawValue]), deviceID)
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        logger.info("Session was suspended")
        let msg = Data([MessageId.stop.rawValue])
        
        sendDataToAccessory(msg, deviceIDFromSession(session))
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        logger.info("Session suspension ended")
        // When suspension ends, restart the configuration procedure with the accessory.
        let msg = Data([MessageId.initialize.rawValue])
        
        sendDataToAccessory(msg, deviceIDFromSession(session))
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        let deviceID = deviceIDFromSession(session)
        
        switch error {
        case NIError.invalidConfiguration:
            // Debug the accessory data to ensure an expected format.
            logger.info("The accessory configuration data is invalid. Please debug it and try again.")
        case NIError.userDidNotAllow:
            handleUserDidNotAllow()
        default:
            handleSessionInvalidation(deviceID)
        }
    }
}

// MARK: - Helpers.
extension ViewController {
    
    func pairToAccessory(_ deviceID: Int) {
         do {
             try dataChannel.pairPeripheral(deviceID)
         } catch {
             logger.info("Failed to pair to accessory: \(error)")
         }
    }
    
    func connectToAccessory(_ deviceID: Int) {
         do {
             try dataChannel.connectPeripheral(deviceID)
         } catch {
             logger.info("Failed to connect to accessory: \(error)")
         }
    }
    
    func disconnectFromAccessory(_ deviceID: Int) {
         do {
             try dataChannel.disconnectPeripheral(deviceID)
         } catch {
             logger.info("Failed to disconnect from accessory: \(error)")
         }
     }
    
    func sendDataToAccessory(_ data: Data,_ deviceID: Int) {
         do {
             try dataChannel.sendData(data, deviceID)
         } catch {
             logger.info("Failed to send data to accessory: \(error)")
         }
     }
    
    func handleSessionInvalidation(_ deviceID: Int) {
        logger.info("Session invalidated. Restarting.")
        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.stop.rawValue]), deviceID)

        // Replace the invalidated session with a new one.
        referenceDict[deviceID] = NISession()
        referenceDict[deviceID]?.delegate = self

        // Ask the accessory to stop.
        sendDataToAccessory(Data([MessageId.initialize.rawValue]), deviceID)
    }
    
    func shouldRetry(_ deviceID: Int) -> Bool {
        // Need to use the dictionary here, to know which device failed and check its connection state
        let qorvoDevice = dataChannel.getDeviceFromUniqueID(deviceID)
        
        if qorvoDevice?.blePeripheralStatus != statusDiscovered {
            return true
        }
        
        return false
    }
    
    func deviceIDFromSession(_ session: NISession)-> Int {
        var deviceID = -1
        
        for (key, value) in referenceDict {
            if value == session {
                deviceID = key
            }
        }
        
        return deviceID
    }
    
    func cacheToken(_ token: NIDiscoveryToken, accessoryName: String) {
        accessoryMap[token] = accessoryName
    }
    
    func handleUserDidNotAllow() {
        // Beginning in iOS 15, persistent access state in Settings.
        logger.info("Nearby Interactions access required. You can change access for NIAccessory in Settings.")
        
        // Create an alert to request the user go to Settings.
        let accessAlert = UIAlertController(title: "AccessRequired".localized,
                                            message: "NIAccessRequired.message".localized,
                                            preferredStyle: .alert)
        accessAlert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))
        accessAlert.addAction(UIAlertAction(title: "GoSettings".localized, style: .default, handler: {_ in
            // Navigate the user to the app's settings.
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))

        // Preset the access alert.
        present(accessAlert, animated: true, completion: nil)
    }
}

// MARK: - Utils.
extension String {
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
    var localizedUppercase: String {
        return NSLocalizedString(self, tableName: nil, bundle: Bundle.main, value: "", comment: "").uppercased()
    }
}
