//
//  ActivityIndicator.swift
//  uwbapp
//
//  Created by Halbu on 4/26/24.
//

import UIKit

extension UIImage{
    func rotate(radians: Float) -> UIImage?{
        
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(0))).size
        
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        
        let context = UIGraphicsGetCurrentContext();
        
        // Move origin to middle
        context?.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context?.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
    
}
