//
//  UDPClient.swift
//  uwbapp
//
//  Created by Halbu on 6/10/24.
//

import Foundation
import Network


class UDPClient{
    private var connection: NWConnection
    private var host: NWEndpoint.Host
    private var port: NWEndpoint.Port
    private var pendingData: Data?
    
    init(host: String, port: UInt16){
        self.host = NWEndpoint.Host(host)
        self.port = NWEndpoint.Port(rawValue: port)!
        self.connection = NWConnection(host: self.host, port: self.port, using: .udp)
    }
    
    func start() {
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("Connected to \(self.connection.endpoint)")
                if let data = self.pendingData {
                    self.send(data: data)
                    self.pendingData = nil
                }
            case .failed(let error):
                print("Connection failed with error: \(error)")
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    func send(data: Data) {
        if connection.state == .ready {
            connection.send(content: data, completion: .contentProcessed( { error in
                if let error = error {
                    print("Failed to send data: \(error)")
                } else {
                    print("Data was sent")
                }
            }))
        } else {
            print("Connection is not ready. Storing data to send later.")
            pendingData = data
        }
    }

    func stop() {
        connection.cancel()
        print("Connection cancelled")
    }
}
