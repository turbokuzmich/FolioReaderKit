//
//  FolioReaderSidePanel.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit

internal let font = UIFont(name: "Avenir-Light", size: 17)!
internal let attributes = [NSFontAttributeName: font]

@objc protocol FolioReaderSidePanelDelegate {
    func sidePanel(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference)
}

class FolioReaderSidePanel: UIViewController, UITableViewDelegate, UITableViewDataSource {

    weak var delegate: FolioReaderSidePanelDelegate?
    var tableView: UITableView!
    let topOffset: CGFloat = 64
    var tocItems = [FRTocReference]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.whiteColor()
        
        var tableViewFrame = screenBounds()
        tableViewFrame.origin.y = tableViewFrame.origin.y+topOffset
        tableViewFrame.size.height = tableViewFrame.height-topOffset
        
        tableView = UITableView(frame: tableViewFrame)
        tableView.delaysContentTouches = true
        tableView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        tableView.backgroundColor = isNight(readerConfig.nightModeMenuBackground, readerConfig.menuBackgroundColor)
        tableView.separatorColor = isNight(readerConfig.nightModeSeparatorColor, readerConfig.menuSeparatorColor)
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        
        // Register cell classes
        tableView.registerClass(FolioReaderSidePanelCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.separatorInset = UIEdgeInsetsZero
        tableView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        
        // Create TOC list
        createTocList()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Recursive add items to a list
    
    func createTocList() {
        for item in book.tableOfContents {
            tocItems.append(item)
            countTocChild(item)
        }
    }
    
    func countTocChild(item: FRTocReference) {
        if item.children.count > 0 {
            for item in item.children {
                tocItems.append(item)
            }
        }
    }

    // MARK: - Table view data source

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tocItems.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! FolioReaderSidePanelCell
        
        let tocReference = tocItems[indexPath.row]
        let isSection = tocReference.children.count > 0
        
        cell.indexLabel.text = tocReference.title.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        cell.indexLabel.font = font
        cell.indexLabel.textColor = readerConfig.menuTextColor

        // Mark current reading chapter
        if let currentPageNumber = currentPageNumber, resource = book.spine.spineReferences[safe: currentPageNumber - 1]?.resource where tocReference.resource != nil {
            cell.indexLabel.textColor = tocReference.resource!.href == resource.href ? readerConfig.tintColor : readerConfig.menuTextColor
        }
        
        cell.layoutMargins = UIEdgeInsetsZero
        cell.preservesSuperviewLayoutMargins = false
        cell.contentView.backgroundColor = isSection ? UIColor(white: 0.7, alpha: 0.1) : UIColor.clearColor()
        cell.backgroundColor = UIColor.clearColor()
        
        // Adjust text position
        cell.adjustLabelFrame(isSection)

        return cell
    }
    
    // MARK: - Table view delegate
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let tocReference = tocItems[indexPath.row]
        delegate?.sidePanel(self, didSelectRowAtIndexPath: indexPath, withTocReference: tocReference)
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    // MARK: - Table view data source
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let ref = tocItems[indexPath.row]
        let isSection = ref.children.count > 0
        let insets = isSection ? FolioReaderSidePanelCell.sectionLabelInset : FolioReaderSidePanelCell.defaultLabelInset
        let title: NSString = ref.title.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let size = UIEdgeInsetsInsetRect(tableView.bounds, insets).size
        let height: CGFloat = ceil(title.boundingRectWithSize(size, options: [NSStringDrawingOptions.UsesLineFragmentOrigin], attributes: attributes, context: nil).height)

        return height + insets.top + insets.bottom + 1
    }
    
    // MARK: - Get Screen bounds
    
    func screenBounds() -> CGRect {
        return UIScreen.mainScreen().bounds
    }
    
    // MARK: - Toolbar actions
    
    func didSelectHighlight(sender: UIBarButtonItem) {
        FolioReader.sharedInstance.readerContainer.toggleRightPanel()
        FolioReader.sharedInstance.readerCenter.presentHighlightsList()
    }
    
    func didSelectClose(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: {
            FolioReader.sharedInstance.isReaderOpen = false
            FolioReader.sharedInstance.isReaderReady = false
            FolioReader.sharedInstance.readerAudioPlayer.stop()
        })
    }
    
    func didSelectFont(sender: UIBarButtonItem) {
        FolioReader.sharedInstance.readerContainer.toggleRightPanel()
        FolioReader.sharedInstance.readerCenter.presentFontsMenu()
    }

}
