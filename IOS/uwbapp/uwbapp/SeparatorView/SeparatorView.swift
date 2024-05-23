//
//  SeparatorView.swift
//  uwbapp
//
//  Created by Halbu on 4/26/24.
//

import Foundation
import UIKit

class SeparatorView: UIView {
    // Info field
    let titleText: UITextField
      
    init(fieldTitle: String) {
        // Initializing subviews
        titleText = UITextField(frame: .zero)
        titleText.translatesAutoresizingMaskIntoConstraints = false
        titleText.font = .systemFont(ofSize: 14)
        titleText.contentVerticalAlignment = .center
        titleText.textAlignment = .left
        titleText.textColor = .black
        titleText.text = fieldTitle
        
        super.init(frame: .zero)
        
        // Add the stack view to the subview
        addSubview(titleText)
        
        // Set up the stack view's constraints
        NSLayoutConstraint.activate([
            titleText.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            titleText.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Set up the parent view's constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 52.0)
        ])
        
        backgroundColor = .lightGray
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
