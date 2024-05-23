//
//  BluetoothLECentral.swift
//  uwbapp
//
//  Created by Halbu on 4/28/24.
//

import Foundation
import NearbyInteraction

import CoreBluetooth
import simd
import os

struct NIService {
    static let serviceUUID = CBUUID(string: "2E938FD0-6A61-11ED-A1EB-0242AC120002")
    
    static let scCharacteristicUUID = CBUUID(string: "2E93941C-6A61-11ED-A1EB-0242AC120002")
    static let rxCharacteristicUUID = CBUUID(string: "2E93998A-6A61-11ED-A1EB-0242AC120002")
    static let txCharacteristicUUID = CBUUID(string: "2E939AF2-6A61-11ED-A1EB-0242AC120002")
}

struct pairedDevice: Codable {
    var name: String    // Name to display, can be changed by user
}

class uwbDevice {
    var blePeripheral: CBPeripheral         // BLE Peripheral instance
    var scCharacteristic: CBCharacteristic? // Secure Characteristic to be used for pairing
    var rxCharacteristic: CBCharacteristic? // Characteristics to be used when receiving data
    var txCharacteristic: CBCharacteristic? // Characteristics to be used when sending data

    var bleUniqueID: Int
    var blePeripheralName: String            // Name to display
    var blePeripheralStatus: String?         // Status to display
    var bleTimestamp: Int64                  // Last time that the device adverstised
    var uwbDistance: Float?                  // Background mode only report distance
    
    init(peripheral: CBPeripheral, uniqueID: Int, peripheralName: String, timeStamp: Int64 ) {
        
        self.blePeripheral = peripheral
        self.scCharacteristic  = nil
        self.rxCharacteristic  = nil
        self.txCharacteristic  = nil

        self.bleUniqueID = uniqueID
        self.blePeripheralName = peripheralName
        self.blePeripheralStatus = statusDiscovered
        self.bleTimestamp = timeStamp
        self.uwbDistance = 0
    }
}

enum BluetoothLECentralError: Error {
    case noPeripheral
}

let statusDiscovered = "Discovered"
let statusPaired = "Paired"
let statusConnected = "Connected"
let statusRanging = "Ranging"

var uwbDevices = [uwbDevice?]()

let pairedDevices = UserDefaults.standard

class DataCommunicationChannel: NSObject {
    var centralManager: CBCentralManager!

    var writeIterationsComplete = 0
    var connectionIterationsComplete = 0
    
    // The number of times to retry scanning for accessories.
    // Change this value based on your app's testing use case.
    let defaultIterations = 5
    
    var accessorySynchHandler: ((Int, Int, Bool) -> Void)?
    var accessoryPairHandler: ((Data, Int) -> Void)?
    var accessoryConnectedHandler: ((Int) -> Void)?
    var accessoryDisconnectedHandler: ((Int) -> Void)?
    var accessoryDataHandler: ((Data, String, Int) -> Void)?

    var bluetoothReady = false
    var shouldStartWhenReady = false

    let logger = os.Logger(subsystem: "com.uwblogin.capstoneUWB", category: "DataChannel")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        
        // Initialises the Timer used for Haptic and Sound feedbacks
        _ = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(timerHandler), userInfo: nil, repeats: true)
    }
    
    deinit {
        centralManager.stopScan()
        logger.info("Scanning stopped.")
    }
    
    // Clear peripherals in uwbDevices[] if not responding for more than one second
    @objc func timerHandler() {
        var index = 0
        
        uwbDevices.forEach { (uwbDevice) in
            
            if uwbDevice!.blePeripheralStatus == statusDiscovered {
                // Get current timestamp
                let timeStamp = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
                
                // Remove device if timestamp is bigger than 5000 msec
                if timeStamp > (uwbDevice!.bleTimestamp + 5000) {
                    logger.info("Device \(uwbDevice?.blePeripheralName ?? "Unknown") timed-out removed at index \(index)")
                    logger.info("Device timestamp: \(uwbDevice!.bleTimestamp) Current timestamp: \(timeStamp) ")
                    
                    dataSourceHandler(nil, index)
                }
            }
            
            index = index + 1
        }
    }
    
    // Get uwb device from the uniqueID
    func getDeviceFromUniqueID(_ uniqueID: Int)->uwbDevice? {
        
        if let index = uwbDevices.firstIndex(where: {$0?.bleUniqueID == uniqueID}) {
            return uwbDevices[index]
        }
        else {
            return nil
        }
        
    }
    
    // Use a sigle function to handle data on Data Source
    func dataSourceHandler(_ item: uwbDevice?,_ index: Int) {
        
        if item != nil {
            uwbDevices.append(item)
            
            if let deviceSynchHandler = accessorySynchHandler {
                deviceSynchHandler(uwbDevices.count - 1, item?.bleUniqueID ?? -1, true)
            }
        }
        else {
            if uwbDevices.indices.contains(index) {
                uwbDevices.remove(at: index)
                
                if let deviceSynchHandler = accessorySynchHandler {
                    deviceSynchHandler(index, -1, false)
                }
            }
        }
        
    }
    
    func start() {
        if bluetoothReady {
            startScan()
            retrievePeripheral()
        } else {
            shouldStartWhenReady = true
        }
    }

    func stop() throws {
        
    }
    
    func pairPeripheral(_ uniqueID: Int) throws {
        
        if let deviceToPair = getDeviceFromUniqueID(uniqueID) {
            // Throw error if status is not Discovered
            if deviceToPair.blePeripheralStatus != statusConnected {
                return
            }
            // Connect to the peripheral.
            logger.info("Pairing to Peripheral \(deviceToPair.blePeripheral)")
            deviceToPair.blePeripheral.readValue(for: deviceToPair.scCharacteristic!)
        }
        else {
            throw BluetoothLECentralError.noPeripheral
        }
    }
    
    func connectPeripheral(_ uniqueID: Int) throws {
        
        if let deviceToConnect = getDeviceFromUniqueID(uniqueID) {
            // Throw error if status is not Discovered
            if deviceToConnect.blePeripheralStatus != statusDiscovered {
                return
            }
            // Connect to the peripheral.
            logger.info("Connecting to Peripheral \(deviceToConnect.blePeripheral)")
            deviceToConnect.blePeripheralStatus = statusConnected
            centralManager.connect(deviceToConnect.blePeripheral, options: nil)
        }
        else {
            throw BluetoothLECentralError.noPeripheral
        }
    }
    
    func disconnectPeripheral(_ uniqueID: Int) throws {
        
        if let deviceToDisconnect = getDeviceFromUniqueID(uniqueID) {
            // Return if status is not Connected or Ranging
            if deviceToDisconnect.blePeripheralStatus == statusDiscovered {
                return
            }
            // Disconnect from peripheral.
            logger.info("Disconnecting from Peripheral \(deviceToDisconnect.blePeripheral)")
            centralManager.cancelPeripheralConnection(deviceToDisconnect.blePeripheral)
        }
        else {
            throw BluetoothLECentralError.noPeripheral
        }
    }
    
    func sendData(_ data: Data,_ uniqueID: Int) throws {
        let str = String(format: "Sending Data to device %d", uniqueID)
        logger.info("\(str)")
        
        if getDeviceFromUniqueID(uniqueID) != nil {
            writeData(data, uniqueID)
        }
        else {
            throw BluetoothLECentralError.noPeripheral
        }
    }
    
    // MARK: - Helper Methods.
    /*
     * BLE will be scanning for new devices, using the service's 128bit CBUUID, all the time.
     */
    private func startScan() {
        logger.info("Scanning started.")
        
        centralManager.scanForPeripherals(withServices: [NIService.serviceUUID],
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    /*
     * Check for a connected peer.
     */
    private func retrievePeripheral() {

    }

    /*
     * Stops an erroneous or completed connection. Note, `didUpdateNotificationStateForCharacteristic`
     * cancels the connection if a subscriber exists.
     */
    private func cleanup() {
        
    }
    
    // Sends data to the peripheral.
    private func writeData(_ data: Data,_ uniqueID: Int) {
        
        let uwbDevice = getDeviceFromUniqueID(uniqueID)

        guard let discoveredPeripheral = uwbDevice?.blePeripheral
        else { return }
        
        guard let transferCharacteristic = uwbDevice?.rxCharacteristic
        else { return }
        
        logger.info("Getting TX Characteristics from device \(uniqueID).")
        
        let mtu = discoveredPeripheral.maximumWriteValueLength(for: .withResponse)

        let bytesToCopy: size_t = min(mtu, data.count)

        var rawPacket = [UInt8](repeating: 0, count: bytesToCopy)
        data.copyBytes(to: &rawPacket, count: bytesToCopy)
        let packetData = Data(bytes: &rawPacket, count: bytesToCopy)

        let stringFromData = packetData.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Writing \(bytesToCopy) bytes: \(String(describing: stringFromData))")

        discoveredPeripheral.writeValue(packetData, for: transferCharacteristic, type: .withResponse)

        writeIterationsComplete += 1
    }
    
    // MARK: - Utils!
    func includePairedDevice(_ deviceID: Int,_ name: String) {
        let keyID = String(deviceID)
        let encoder = JSONEncoder()
        
        let newDevice = pairedDevice(name: name)
        
        if let encoded = try? encoder.encode(newDevice) {
            pairedDevices.set(encoded, forKey: keyID)
        }
    }
    
    func getPairedDevice(_ deviceID: Int) {
        let keyID = String(deviceID)
        let decoder = JSONDecoder()

        if let savedDevice = pairedDevices.object(forKey: keyID) as? Data {
            if let loadedDevice = try? decoder.decode(pairedDevice.self, from: savedDevice) {
                print(loadedDevice.name)
            }
        }
    }
    
    func checkPairedDevice(_ deviceID: Int)->Bool {
        let keyID = String(deviceID)
  
        if pairedDevices.object(forKey: keyID) != nil {
            return true
        }
        
        return false
    }
    
    func clearKnownDevices() {
        let dictionary = pairedDevices.dictionaryRepresentation()
        
        dictionary.keys.forEach { key in
            pairedDevices.removeObject(forKey: key)
        }
    }
}

extension DataCommunicationChannel: CBCentralManagerDelegate {
    /*
     * When Bluetooth is powered, starts Bluetooth operations.
     *
     * The protocol requires a `centralManagerDidUpdateState` implementation.
     * Ensure you can use the Central by checking whether the its state is
     * `poweredOn`. Your app can check other states to ensure availability such
     * as whether the current device supports Bluetooth LE.
     */
    internal func centralManagerDidUpdateState(_ central: CBCentralManager) {

        switch central.state {
            
        // Begin communicating with the peripheral.
        case .poweredOn:
            logger.info("CBManager is powered on")
            bluetoothReady = true
            if shouldStartWhenReady {
                start()
            }
        // In your app, deal with the following states as necessary.
        case .poweredOff:
            logger.error("CBManager is not powered on")
            return
        case .resetting:
            logger.error("CBManager is resetting")
            return
        case .unauthorized:
            handleCBUnauthorized()
            return
        case .unknown:
            logger.error("CBManager state is unknown")
            return
        case .unsupported:
            logger.error("Bluetooth is not supported on this device")
            return
        @unknown default:
            logger.error("A previously unknown central manager state occurred")
            return
        }
    }

    // Reacts to the varying causes of Bluetooth restriction.
    internal func handleCBUnauthorized() {
        switch CBManager.authorization {
        case .denied:
            // In your app, consider sending the user to Settings to change authorization.
            logger.error("The user denied Bluetooth access.")
        case .restricted:
            logger.error("Bluetooth is restricted")
        default:
            logger.error("Unexpected authorization")
        }
    }

    // Reacts to transfer service UUID discovery.
    // Consider checking the RSSI value before attempting to connect.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        //logger.info("Discovered \( String(describing: peripheral.name)) at\(RSSI.intValue)")
        guard
            // Only go ahead if the device's name have been received
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        else { return }
        
        let timeStamp = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        
        // Check if peripheral is already discovered
        if let uwbDevice = getDeviceFromUniqueID(peripheral.hashValue) {
            
            // if yes, update the timestamp
            uwbDevice.bleTimestamp = timeStamp
            
            return
        }
        
        // Insert the new device to Data Source
        dataSourceHandler(uwbDevice(peripheral: peripheral,
                                      uniqueID: peripheral.hashValue,
                                      peripheralName: name,
                                      timeStamp: timeStamp), 0)
        
        if let newPeripheral = uwbDevices.last {
            let nameToPrint = newPeripheral?.blePeripheralName
            logger.info("Peripheral \(nameToPrint ?? "Unknown") included in uwbDevices with unique ID")
        }
    }

    // Reacts to connection failure.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        logger.error("Failed to connect to \(peripheral). \( String(describing: error))")
        cleanup()
    }

    // Discovers the services and characteristics to find the 'TransferService'
    // characteristic after peripheral connection.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("Peripheral Connected")

        // Set the iteration info.
        connectionIterationsComplete += 1
        writeIterationsComplete = 0

        // Set the `CBPeripheral` delegate to receive callbacks for its services discovery.
        peripheral.delegate = self

        // Search only for services that match the service UUID.
        peripheral.discoverServices([NIService.serviceUUID])
    }

    // Cleans up the local copy of the peripheral after disconnection.
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        logger.info("Peripheral Disconnected")
        
        let uniqueID = peripheral.hashValue
        let uwbDevice = getDeviceFromUniqueID(uniqueID)
        
        // Update Timestamp to avoid premature disconnection
        let timeStamp = Int64((Date().timeIntervalSince1970 * 1000.0).rounded())
        uwbDevice!.bleTimestamp = timeStamp
        // Finally, update the device status
        uwbDevice!.blePeripheralStatus = statusDiscovered
        
        if let didDisconnectHandler = accessoryDisconnectedHandler {
            didDisconnectHandler(uniqueID)
        }
        
        // Resume scanning after disconnection.
        if connectionIterationsComplete < defaultIterations {
            logger.info("Retrieve Peripheral")
            retrievePeripheral()
        } else {
            logger.info("Connection iterations completed")
        }
    }
}

// An extention to implement `CBPeripheralDelegate` methods.
extension DataCommunicationChannel: CBPeripheralDelegate {
    
    // Reacts to peripheral services invalidation.
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {

        for service in invalidatedServices where service.uuid == NIService.serviceUUID {
            logger.error("NI service is invalidated - rediscover services")
            peripheral.discoverServices([NIService.serviceUUID])
        }
    }

    // Reacts to peripheral services discovery.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            logger.error("Error discovering services: \(error.localizedDescription)")
            cleanup()
            return
        }
        logger.info("discovered service. Now discovering characteristics")
        // Check the newly filled peripheral services array for more services.
        guard let peripheralServices = peripheral.services else { return }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([NIService.scCharacteristicUUID,
                                                NIService.rxCharacteristicUUID,
                                                NIService.txCharacteristicUUID], for: service)
        }
    }

    // Subscribes to a discovered characteristic, which lets the peripheral know we want the data it contains.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any).
        if let error = error {
            logger.error("Error discovering characteristics: \(error.localizedDescription)")
            cleanup()
            return
        }

        let uniqueID = peripheral.hashValue
        let uwbDevice = getDeviceFromUniqueID(uniqueID)
        
        // Check the newly filled peripheral services array for more services.
        guard let serviceCharacteristics = service.characteristics else { return }
        
        for characteristic in serviceCharacteristics where characteristic.uuid == NIService.scCharacteristicUUID {
            // Subscribe to the transfer service's `scCharacteristic`.
            uwbDevice?.scCharacteristic = characteristic
            logger.info("discovered secure characteristic: \(characteristic)")
        }
        
        for characteristic in serviceCharacteristics where characteristic.uuid == NIService.rxCharacteristicUUID {
            // Subscribe to the transfer service's `rxCharacteristic`.
            uwbDevice?.rxCharacteristic = characteristic
            logger.info("discovered rx characteristic: \(characteristic)")
        }

        for characteristic in serviceCharacteristics where characteristic.uuid == NIService.txCharacteristicUUID {
            // Subscribe to the Transfer service `txCharacteristic`.
            uwbDevice?.txCharacteristic = characteristic
            logger.info("discovered tx characteristic: \(characteristic)")
            peripheral.setNotifyValue(true, for: characteristic)
        }

    }

    // Reacts to data arrival through the characteristic notification.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Check if the peripheral reported an error.
        if let error = error {
            logger.error("Error discovering characteristics:\(error.localizedDescription)")
            cleanup()
            
            return
        }
        guard let characteristicData = characteristic.value else { return }
    
        let str = characteristicData.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("Received \(characteristicData.count) bytes: \(str)")
        
        let uniqueID = peripheral.hashValue
        let uwbDevice = getDeviceFromUniqueID(uniqueID)
        
        // Check if data comes from Secure or TX Service
        if characteristic.uuid == NIService.scCharacteristicUUID {
            if let pairHandler = self.accessoryPairHandler {
                pairHandler(characteristicData, uniqueID)
            }
        }
        else {
            if let dataHandler = self.accessoryDataHandler, let accessoryName = uwbDevice?.blePeripheralName {
                dataHandler(characteristicData, accessoryName, uniqueID)
            }
        }
    }

    // Reacts to the subscription status.
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Check if the peripheral reported an error.
        if let error = error {
            logger.error("Error changing notification state: \(error.localizedDescription)")
            return
        }

        if characteristic.isNotifying {
            // Indicates the notification began.
            logger.info("Notification began on \(characteristic)")
            // Wait for the peripheral to send data.
            if let didConnectHandler = accessoryConnectedHandler {
                didConnectHandler(peripheral.hashValue)
            }
        } else {
            // Because the notification stopped, disconnect from the peripheral.
            logger.info("Notification stopped on \(characteristic). Disconnecting")
            cleanup()
        }
    }
}
