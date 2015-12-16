//
//  AppCell.swift
//  Rainbow
//
//  Created by Marcio Klepacz on 10/08/15.
//  Copyright (c) 2015 Marcio Klepacz. All rights reserved.
//

import UIKit

class AppCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    
    required override init(frame: CGRect) {
        super.init(frame: frame)
        imageView = UIImageView(frame: frame)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
}
