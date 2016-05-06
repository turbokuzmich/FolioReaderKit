//
//  FolioReaderSidePanelCell.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 07/05/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

class FolioReaderSidePanelCell: UITableViewCell {
    
    static let sectionLabelInset = UIEdgeInsets(top: 8, left: 110, bottom: 8, right: 16)
    static let defaultLabelInset = UIEdgeInsets(top: 8, left: 90, bottom: 8, right: 16)
    
    let indexLabel = UILabel()
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureLabel()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func adjustLabelFrame(isSection: Bool) {
        let insets = isSection ? FolioReaderSidePanelCell.sectionLabelInset : FolioReaderSidePanelCell.defaultLabelInset
        indexLabel.frame = UIEdgeInsetsInsetRect(contentView.bounds, insets)
    }
    
    internal func configureLabel() {
        indexLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        indexLabel.lineBreakMode = .ByWordWrapping
        indexLabel.numberOfLines = 0
        
        adjustLabelFrame(true)
        
        contentView.addSubview(indexLabel)
    }
    
}
