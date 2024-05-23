//
//  AccessoriesTable.swift
//  uwbapp
//
//  Created by Halbu on 4/26/24.
//

import Foundation
import UIKit
import os.log

class AccessoriesTable: UITableView, UITableViewDelegate, UITableViewDataSource {
    
    let logger = os.Logger(subsystem: "com.capstone.uwbapp", category: "AccessoriesTable")
    
    var tableDelegate: TableProtocol?
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        
        // Set up the table view
        delegate = self
        dataSource = self
        
        // Register a cell class for reuse
        register(SingleCell.self, forCellReuseIdentifier: "SingleCell")
        
        rowHeight = 87.0
        separatorInset = .zero
        separatorStyle = .none
        tableFooterView = UIView()
        
        // Set up the parent view's constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 261.0),
            topAnchor.constraint(equalTo: topAnchor),
            leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        separatorStyle = .none
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setCellAsset(_ deviceID: Int,_ newAsset: asset) {
        // Edit cell for this uniqueID
        for case let cell as SingleCell in self.visibleCells {
            if cell.uniqueID == deviceID {
                cell.selectAsset(newAsset)
            }
        }
    }
    
    func setCellColor(_ deviceID: Int,_ newColor: UIColor) {
        // Edit cell for this uniqueID
        for case let cell as SingleCell in self.visibleCells {
            if cell.uniqueID == deviceID {
                cell.accessoryButton.backgroundColor = newColor
            }
        }
    }
    
    func handleCell(_ index: Int,_ insert: Bool ) {
        self.beginUpdates()
        if (insert) {
            self.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
        else {
            self.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
        self.endUpdates()
    }
    
    func updateCell(_ deviceID: Int,_ distance: Float) {
        for case let cell as SingleCell in self.visibleCells {
            if cell.uniqueID == deviceID {
                //print(cell.accessoryButton.currentTitle)
                cell.distanceLabel.text = String(format: "meters".localized, distance)
                print(distance) // 거리
            }
        }
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // Only one section
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Number of rows equals the number of accessories
        return uwbDevices.count
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let disconnect = UIContextualAction(style: .normal, title: "") { [self] (action, view, completion) in
            // Send the disconnection message to the device
            let cell = tableView.cellForRow(at: indexPath) as! SingleCell
            let deviceID = cell.uniqueID
            
            tableDelegate?.sendStopToDevice(deviceID)
            
            completion(true)
        }
        // Set the Contextual action parameters
        disconnect.image = UIImage(named: "trash_bin")
        disconnect.backgroundColor = .red
        
        let swipeActions = UISwipeActionsConfiguration(actions: [disconnect])
        swipeActions.performsFirstActionWithFullSwipe = false
        
        return swipeActions
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SingleCell", for: indexPath) as! SingleCell
        
        let uwbDevice = uwbDevices[indexPath.row]
        
        cell.uniqueID = (uwbDevice?.bleUniqueID)!

        // Initialize the new cell assets
        cell.accessoryButton.tag = cell.uniqueID
        cell.accessoryButton.setTitle(uwbDevice?.blePeripheralName, for: .normal) //여기
        cell.accessoryButton.isEnabled = true
        cell.accessoryname = uwbDevice?.blePeripheralName ///
        cell.actionButton.tag = cell.uniqueID
        cell.actionButton.addTarget(self,
                                    action: #selector(buttonAction),
                                    for: .touchUpInside)
        cell.actionButton.isEnabled = true
        
        logger.info("New device included at row \(indexPath.row)")
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // MARK: - TableProtocol delegate wraper
    //백그라운드에선 제거
//    @objc func buttonSelect(_ sender: UIButton) {
//        tableDelegate?.buttonSelect(sender)
//    }
    
    @objc func buttonAction(_ sender: UIButton) {
        tableDelegate?.buttonAction(sender)
    }
}
