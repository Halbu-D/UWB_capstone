//
//  ViewController.swift
//  CapstoneUWB
//
//  Created by Halbu
//

import UIKit
import NearbyInteraction
import os.log

enum MessageId: UInt8 {
    // Messages from the accessory.
    case accessoryConfigurationData = 0x1
    case accessoryUwbDidStart = 0x2
    case accessoryUwbDidStop = 0x3
    
    // Messages to the accessory.
    case initialize = 0xA
    case configureAndStart = 0xB
    case stop = 0xC
}

class ViewController: UIViewController {
    var dataChannel = DataCommunicationChannel()
    var niSession = NISession()
    var configuration: NINearbyAccessoryConfiguration?
    var accessoryConnected = false
    var connectedAccessoryName: String?
    var accessoryMap = [NIDiscoveryToken: String]()
    
    var logger = os.Logger(subsystem: "com.uwblogin.CapstoneUWB", category: "ViewController")
    
    @IBOutlet weak var connectionStateLabel: UILabel!
    @IBOutlet weak var uwbStateLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set a delegate for session updates from the framework.
        niSession.delegate = self
        
        // Prepare the data communication channel.
        dataChannel.accessoryConnectedHandler = accessoryConnected
        dataChannel.accessoryDisconnectedHandler = accessoryDisconnected
        dataChannel.accessoryDataHandler = accessorySharedData
        dataChannel.start()
        
        updateInfoLabel(with: "주변장치 스캔중")
    }
    
    @IBAction func buttonAction(_ sender: Any){
        updateInfoLabel(with: "주변장치로부터 구성 데이터 요청중")
        let msg = Data([MessageId.initialize.rawValue])
        sendDataToAccessory(msg)
    }

    // MARK: - Data channel methods
    
    func accessorySharedData(data: Data, accessoryName: String) {
        // 주변장치는 각 메시지를 식별자 바이트로 시작
        // 메시지의 길이가 유효한 범위인지 확인
        if data.count < 1 {
            updateInfoLabel(with: "주변장치로부터 공유된 데이터가 1보다 작습니다.")
            return
        }
        
        // 메시지의 첫 바이트를 사용해 식별자를 가져옴
        guard let messageId = MessageId(rawValue: data.first!) else {
            fatalError("\(data.first!) 는 유효한 MessageId가 아닙니다.")
        }
        
        // 메시지 식별자에 따라 데이터 부분 처리
        switch messageId {
        case .accessoryConfigurationData:
            // 메시지 식별자를 건너뛰고 데이터에 접근
            assert(data.count > 1)
            let message = data.advanced(by: 1)
            setupAccessory(message, name: accessoryName)
        case .accessoryUwbDidStart:
            handleAccessoryUwbDidStart()
        case .accessoryUwbDidStop:
            handleAccessoryUwbDidStop()
        case .configureAndStart:
            fatalError("Accessory should not send 'configureAndStart'.")
        case .initialize:
            fatalError("Accessory should not send 'initialize'.")
        case .stop:
            fatalError("Accessory should not send 'stop'.")
        }
    }
    
    func accessoryConnected(name: String) {
        accessoryConnected = true
        connectedAccessoryName = name
        actionButton.isEnabled = true
        connectionStateLabel.text = "연결됨"
        updateInfoLabel(with: "Connected to '\(name)'")
    }
    
    func accessoryDisconnected() {
        accessoryConnected = false
        actionButton.isEnabled = false
        connectedAccessoryName = nil
        connectionStateLabel.text = "연결 안 됨"
        updateInfoLabel(with: "주변장치 연결 해제")
    }
    
    // MARK: - Accessory messages handling
    
    func setupAccessory(_ configData: Data, name: String) {
        updateInfoLabel(with: "'\(name)'으로부터 구성 데이터를 받았습니다. 세션을 시작합니다.")
        do {
            configuration = try NINearbyAccessoryConfiguration(data: configData)
        } catch {
            // 들어오는 데이터가 유효하지 않기 때문에 문제를 멈추고 표시
            // 앱에서 예상 형식인지 확인하기위해 액세서리 데이터를 디버깅해야함.
            updateInfoLabel(with: "'\(name)'에 대한 NIAccessoryConfiguration 생성 실패. Error: \(error)")
            return
        }
        
        // 이 액세서리와의 업데이트를 관련시키기 위해 토큰 캐시.
        cacheToken(configuration!.accessoryDiscoveryToken, accessoryName: name)
        niSession.run(configuration!)
    }
    
    func handleAccessoryUwbDidStart() {
        updateInfoLabel(with: "액세서리 세션이 시작됨.")
        actionButton.isEnabled = false
        self.uwbStateLabel.text = "ON"
    }
    
    func handleAccessoryUwbDidStop() {
        updateInfoLabel(with: "액세서리 세션이 중지됨.")
        if accessoryConnected {
            actionButton.isEnabled = true
        }
        self.uwbStateLabel.text = "OFF"
    }
}

// MARK: - `NISessionDelegate`.

extension ViewController: NISessionDelegate {

    func session(_ session: NISession, didGenerateShareableConfigurationData shareableConfigurationData: Data, for object: NINearbyObject) {

        guard object.discoveryToken == configuration?.accessoryDiscoveryToken else { return }
        
        // 액세서리에 메시지를 전송하기 위해 준비
        var msg = Data([MessageId.configureAndStart.rawValue])
        msg.append(shareableConfigurationData)
        
        let str = msg.map { String(format: "0x%02x, ", $0) }.joined()
        logger.info("공유 가능한 configuration bytes: \(str)")
        
        let accessoryName = accessoryMap[object.discoveryToken] ?? "Unknown"
        
        // 액세서리에 메시지를 전송함
        sendDataToAccessory(msg)
        updateInfoLabel(with: "'\(accessoryName)'에 공유 가능한 데이터 전송 완료")
    }
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let accessory = nearbyObjects.first else { return }
        guard let distance = accessory.distance else { return }
        guard let name = accessoryMap[accessory.discoveryToken] else { return }
        
        self.distanceLabel.text = String(format: "'%@' is %0.1f meters away", name, distance)
        self.distanceLabel.sizeToFit()
    }
    
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        // 피어가 타임아웃일 경우 세션을 다시 시도함.
        guard reason == .timeout else { return }
        updateInfoLabel(with: "Session with '\(self.connectedAccessoryName ?? "accessory")' timed out.")
        
        // 세션은 하나의 악세서리와 함께 실행됨
        guard let accessory = nearbyObjects.first else { return }
        
        // 앱의 악세서리 상태를 지움.
        accessoryMap.removeValue(forKey: accessory.discoveryToken)
        
        // 재시도 여부를 결정하는 도우미 함수를 참조
        if shouldRetry(accessory) {
            sendDataToAccessory(Data([MessageId.stop.rawValue]))
            sendDataToAccessory(Data([MessageId.initialize.rawValue]))
        }
    }
    
    func sessionWasSuspended(_ session: NISession) {
        updateInfoLabel(with: "세션이 일시 중단됨.")
        let msg = Data([MessageId.stop.rawValue])
        sendDataToAccessory(msg)
    }
    
    func sessionSuspensionEnded(_ session: NISession) {
        updateInfoLabel(with: "세션 일시 중단이 종료됨.")
        // 일시중단이 끝나면 액세서리와의 구성절차가 다시 시작되어야 함.
        let msg = Data([MessageId.initialize.rawValue])
        sendDataToAccessory(msg)
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        switch error {
        case NIError.invalidConfiguration:
            // 액세서리 데이터가 예상 형식인지 확인하기 위해 디버깅
            updateInfoLabel(with: "액세서리 구성 데이터가 유효하지 않음. 디버깅 후 다시 시도")
        case NIError.userDidNotAllow:
            handleUserDidNotAllow()
        default:
            handleSessionInvalidation()
        }
    }
}

// MARK: - Helpers.

extension ViewController {
    func updateInfoLabel(with text: String) {
        self.infoLabel.text = text
        self.distanceLabel.sizeToFit()
        logger.info("\(text)")
    }
    
    func sendDataToAccessory(_ data: Data) {
        do {
            try dataChannel.sendData(data)
        } catch {
            updateInfoLabel(with: "주변장치에 데이터 전송 실패: \(error)")
        }
    }
    
    func handleSessionInvalidation() {
        updateInfoLabel(with: "세션 무효화. 재시작 중")
        // 액세서리 정지 요청
        sendDataToAccessory(Data([MessageId.stop.rawValue]))

        // 무효화된 새션을 새로 교체
        self.niSession = NISession()
        self.niSession.delegate = self

        // 액세서리 정지 요청
        sendDataToAccessory(Data([MessageId.initialize.rawValue]))
    }
    
    func shouldRetry(_ accessory: NINearbyObject) -> Bool {
        if accessoryConnected {
            return true
        }
        return false
    }
    
    func cacheToken(_ token: NIDiscoveryToken, accessoryName: String) {
        accessoryMap[token] = accessoryName
    }
    
    func handleUserDidNotAllow() {
        // ios 15부터는 설정에서 접근 상태가 필요함
        updateInfoLabel(with: "설정에서 Nearby Interaction에 대한 권한을 변경할 수 있습니다.")
        
        // 사용자가 설정으로 이동하도록 요청하는 알림 생성
        let accessAlert = UIAlertController(title: "Access Required",
                                            message: """
                                            이 앱에서 NIAccessory에 대한 접근을 위해 Nearby Interaction에 대한 권한이 필요함.
                                            설정에서 NI에 대한 권한을 변경하면 기능이 활성화되는지 설명하는데 사용
                                            """,
                                            preferredStyle: .alert)
        accessAlert.addAction(UIAlertAction(title: "취소", style: .cancel, handler: nil))
        accessAlert.addAction(UIAlertAction(title: "설정으로 이동", style: .default, handler: {_ in
            // 사용자가 앱 설정으로 이동하도록 함
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }))

        // 접근 알람 표시
        present(accessAlert, animated: true, completion: nil)
    }
}
