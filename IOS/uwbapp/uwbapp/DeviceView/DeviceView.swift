//
//  DeviceView.swift
//  uwbapp
//
//  Created by Halbu on 4/26/24.
//

import Foundation
import UIKit

class DeviceView: UIView{
    //info
    let titleText: UITextField
    let deviceName: UITextField
    
    let verticalStackView: UIStackView
    
    init() {
        // 초기화
        titleText = UITextField(frame: .zero)
        titleText.translatesAutoresizingMaskIntoConstraints = false
        titleText.font = .systemFont(ofSize: 14)
        titleText.contentVerticalAlignment = .bottom
        titleText.textAlignment = .center
        titleText.textColor = .lightGray
        titleText.text = "SelectedAccessory".localized
        
        deviceName = UITextField(frame: .zero)
        deviceName.translatesAutoresizingMaskIntoConstraints = false
        deviceName.font = .systemFont(ofSize: 16)
        deviceName.contentVerticalAlignment = .center
        deviceName.textAlignment = .center
        deviceName.textColor = .black
        deviceName.text = "NotConnected".localized.uppercased()
        
        verticalStackView = UIStackView(arrangedSubviews: [titleText, deviceName])
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.axis = .vertical
        verticalStackView.distribution = .equalSpacing
        verticalStackView.spacing = 0
        
        super.init(frame: .zero)
        
        // Add the stack view to the superview
        addSubview(verticalStackView)
        
        // Set up the stack view's constraints
        NSLayoutConstraint.activate([
            titleText.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleText.heightAnchor.constraint(equalToConstant: 52.0),
            
            deviceName.centerXAnchor.constraint(equalTo: centerXAnchor),
            deviceName.heightAnchor.constraint(equalToConstant: 52.0),
            
            verticalStackView.topAnchor.constraint(equalTo: topAnchor),
            verticalStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            verticalStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            verticalStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setDeviceName(_ newDeviceName: String) {
        deviceName.text = newDeviceName
    }
    
}
