//
//  SingleCell.swift
//  uwbapp
//
//  Created by Halbu on 4/26/24.
//

import UIKit

enum asset: String {
    // Index for each label.
    case actionButton = "연결 버튼"
    case connecting   = "에니메이션 아이콘"
    case miniLocation = "Panel with TWR info"
}

class SingleCell: UITableViewCell {
    
    let accessoryButton: UIButton
    var accessoryname: String? ///
    let miniLocation: UIView
    let actionButton: UIButton
    let connecting: UIImageView
    let bottomBar: UIImageView
    
    let pipe: UIImageView
    let distanceLabel: UITextField
    
    // Used to animate scanning images
    var imageLoading = [UIImage]()
    var uniqueID: Int = 0
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        accessoryname = nil ///
        accessoryButton = UIButton()
        accessoryButton.titleLabel?.font = .systemFont(ofSize: 14)
        accessoryButton.setTitleColor(.black, for: .normal)
        accessoryButton.contentHorizontalAlignment = .left
        accessoryButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        //accessoryButton.configuration?.titlePadding = 20
        accessoryButton.translatesAutoresizingMaskIntoConstraints = false
        
        miniLocation = UIView()
        miniLocation.translatesAutoresizingMaskIntoConstraints = false
        
        pipe = UIImageView(image: UIImage(named: "subheading"))
        pipe.contentMode = .scaleAspectFit
        pipe.translatesAutoresizingMaskIntoConstraints = false
        
        distanceLabel = UITextField(frame: .zero)
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.font = .systemFont(ofSize: 14)
        distanceLabel.textAlignment = .right
        distanceLabel.textColor = .black
        distanceLabel.text = "StartMeters".localized
        
        actionButton = UIButton()
        actionButton.titleLabel?.font = .systemFont(ofSize: 16)
        actionButton.setTitleColor(.blue, for: .normal)
        actionButton.setTitle("Connect".localized, for: .normal)
        actionButton.contentHorizontalAlignment = .right
        actionButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)
        //actionButton.configuration?.titlePadding = 20
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        
        connecting = UIImageView()
        connecting.contentMode = .scaleAspectFit
        connecting.translatesAutoresizingMaskIntoConstraints = false
        
        bottomBar = UIImageView(image: UIImage(named: "bar"))
        bottomBar.contentMode = .scaleAspectFit
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        miniLocation.addSubview(distanceLabel)
        miniLocation.addSubview(pipe)
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.backgroundColor = .white
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(accessoryButton)
        contentView.addSubview(miniLocation)
        contentView.addSubview(actionButton)
        contentView.addSubview(connecting)
        contentView.addSubview(bottomBar)
        
        // Start the Activity Indicators
        let imageSmall = UIImage(named: "spinner_small")!
        for i in 0...24 {
            imageLoading.append(imageSmall.rotate(radians: Float(i) * .pi / 12)!)
        }
        connecting.animationImages = imageLoading
        connecting.animationDuration = 1
        
        // Set up the stack view's constraints
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            accessoryButton.topAnchor.constraint(equalTo: topAnchor),
            accessoryButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            accessoryButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            accessoryButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            actionButton.topAnchor.constraint(equalTo: topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            actionButton.widthAnchor.constraint(equalToConstant: 160.0),
            
            connecting.heightAnchor.constraint(equalToConstant: 24.0),
            connecting.widthAnchor.constraint(equalToConstant: 24.0),
            connecting.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            connecting.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            bottomBar.heightAnchor.constraint(equalToConstant: 1.0),
            bottomBar.widthAnchor.constraint(equalToConstant: 370.0),
            bottomBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            bottomBar.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            // miniLocation view is where the location asstes are nested
            miniLocation.topAnchor.constraint(equalTo: topAnchor),
            miniLocation.bottomAnchor.constraint(equalTo: bottomAnchor),
            miniLocation.trailingAnchor.constraint(equalTo: trailingAnchor),
            miniLocation.widthAnchor.constraint(equalToConstant: 160.0),
            
            distanceLabel.widthAnchor.constraint(equalToConstant: 52.0),
            distanceLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            distanceLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            pipe.heightAnchor.constraint(equalToConstant: 18.0),
            pipe.widthAnchor.constraint(equalToConstant: 18.0),
            pipe.trailingAnchor.constraint(equalTo: distanceLabel.leadingAnchor),
            pipe.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        
        backgroundColor = .white
        
        selectAsset(.actionButton)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func selectAsset(_ asset: asset) {
        switch asset {
        case .actionButton:
            miniLocation.isHidden = true
            actionButton.isHidden = false
            connecting.isHidden   = true
            connecting.stopAnimating()
        case .connecting:
            miniLocation.isHidden = true
            actionButton.isHidden = true
            connecting.isHidden   = false
            connecting.startAnimating()
        case .miniLocation:
            miniLocation.isHidden = false
            actionButton.isHidden = true
            connecting.isHidden   = true
            connecting.stopAnimating()
        }
    }
}
