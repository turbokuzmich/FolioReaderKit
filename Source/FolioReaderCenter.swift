//
//  FolioReaderCenter.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 08/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import ZFDragableModalTransition

let reuseIdentifier = "Cell"
var isScrolling = false
var recentlyScrolled = false
var recentlyScrolledDelay = 2.0 // 2 second delay until we clear recentlyScrolled
var recentlyScrolledTimer: NSTimer!
var scrollDirection = ScrollDirection()
var pageWidth: CGFloat!
var pageHeight: CGFloat!
var previousPageNumber: Int!
var currentPageNumber: Int!
var nextPageNumber: Int!
private var tempReference: FRTocReference?
private var isFirstLoad = true

enum ScrollDirection: Int {
    case None
    case Right
    case Left
    case Up
    case Down
    
    init() {
        self = .None
    }
}

class FolioReaderCenter: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, FolioPageDelegate, FolioReaderContainerDelegate {
    
    var collectionView: UICollectionView!
    var loadingView: UIActivityIndicatorView!
    var pages: [String]!
    var totalPages: Int!
    var tempFragment: String?
    var currentPage: FolioReaderPage!
    weak var folioReaderContainer: FolioReaderContainer!
    var animator: ZFModalTransitionAnimator!
    var bookShareLink: String?
    
    private var screenBounds: CGRect!
    private var pointNow = CGPointZero
    private let pageIndicatorHeight = 20 as CGFloat
    
    var topOffset: CGFloat = 64
    
    // MARK: - View life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = false
        
        let app = UIApplication.sharedApplication()
        
        screenBounds = UIScreen.mainScreen().bounds
        
        view.backgroundColor = UIColor.greenColor()
        
        // Layout
        let layout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsetsZero
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.scrollDirection = UICollectionViewScrollDirection.Vertical
        
        // CollectionView
        collectionView = UICollectionView(frame: CGRect(x: 0, y: topOffset, width: screenBounds.width, height: screenBounds.height - topOffset), collectionViewLayout: layout)
        collectionView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.pagingEnabled = true
        collectionView.backgroundColor = UIColor.redColor()
        collectionView.decelerationRate = UIScrollViewDecelerationRateFast
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        // Register cell classes
        collectionView!.registerClass(FolioReaderPage.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        // Delegate container
        folioReaderContainer.delegate = self
        totalPages = book.spine.spineReferences.count
        
        // Loading indicator
        let style: UIActivityIndicatorViewStyle = isNight(.White, .Gray)
        loadingView = UIActivityIndicatorView(activityIndicatorStyle: style)
        loadingView.center = view.center
        loadingView.hidesWhenStopped = true
        loadingView.startAnimating()
        view.addSubview(loadingView)
        
        setPageSize(app.statusBarOrientation)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        isFirstLoad = true
    }

    func reloadData() {
        loadingView.stopAnimating()
        bookShareLink = readerConfig.localizedShareWebLink
        totalPages = book.spine.spineReferences.count

        collectionView.reloadData()
        
        currentPageNumber = 1
    }
    
    // MARK: Status bar and Navigation bar

    func togglePlay(sender: UIBarButtonItem) {
        presentPlayerMenu()
    }

    // MARK: Toggle menu
    
    func toggleMenu(sender: UIBarButtonItem) {
        FolioReader.sharedInstance.readerContainer.toggleRightPanel()
    }
    
    // MARK: UICollectionViewDataSource
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return totalPages
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! FolioReaderPage
        
        cell.pageNumber = indexPath.row+1
        cell.webView.scrollView.delegate = self
        cell.delegate = self
        cell.backgroundColor = UIColor.clearColor()
        cell.contentView.backgroundColor = UIColor.redColor()
        
        // Configure the cell
        let resource = book.spine.spineReferences[indexPath.row].resource
        var html = try? String(contentsOfFile: resource.fullHref, encoding: NSUTF8StringEncoding)
        let mediaOverlayStyleColors = "\"\(readerConfig.mediaOverlayColor.hexString(false))\", \"\(readerConfig.mediaOverlayColor.highlightColor().hexString(false))\""

        // Inject CSS
        let jsFilePath = NSBundle.frameworkBundle().pathForResource("Bridge", ofType: "js")
        let cssFilePath = NSBundle.frameworkBundle().pathForResource("Style", ofType: "css")
        let cssTag = "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(cssFilePath!)\">"
        let jsTag = "<script type=\"text/javascript\" src=\"\(jsFilePath!)\"></script>" +
                    "<script type=\"text/javascript\">setMediaOverlayStyleColors(\(mediaOverlayStyleColors))</script>"
        
        let toInject = "\n\(cssTag)\n\(jsTag)\n</head>"
        html = html?.stringByReplacingOccurrencesOfString("</head>", withString: toInject)
        
        // Font class name
        var classes = ""
        let currentFontName = FolioReader.sharedInstance.currentFontName
        switch currentFontName {
        case 0:
            classes = "andada"
            break
        case 1:
            classes = "lato"
            break
        case 2:
            classes = "lora"
            break
        case 3:
            classes = "raleway"
            break
        default:
            break
        }
        
        classes += " "+FolioReader.sharedInstance.currentMediaOverlayStyle.className()
        
        // Night mode
        if FolioReader.sharedInstance.nightMode {
            classes += " nightMode"
        }
        
        // Font Size
        let currentFontSize = FolioReader.sharedInstance.currentFontSize
        switch currentFontSize {
        case 0:
            classes += " textSizeOne"
            break
        case 1:
            classes += " textSizeTwo"
            break
        case 2:
            classes += " textSizeThree"
            break
        case 3:
            classes += " textSizeFour"
            break
        case 4:
            classes += " textSizeFive"
            break
        default:
            break
        }
        
        html = html?.stringByReplacingOccurrencesOfString("<html ", withString: "<html class=\"\(classes)\"")
        
        cell.loadHTMLString(html, baseURL: NSURL(fileURLWithPath: (resource.fullHref as NSString).stringByDeletingLastPathComponent))

        return cell
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSizeMake(pageWidth, pageHeight)
    }
    
    // MARK: - Device rotation
    
    override func willRotateToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        setPageSize(toInterfaceOrientation)
        updateCurrentPage()
        
        UIView.animateWithDuration(duration, animations: {
            self.collectionView.contentSize = CGSizeMake(pageWidth, pageHeight * CGFloat(self.totalPages))
            self.collectionView.setContentOffset(self.frameForPage(currentPageNumber).origin, animated: false)
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    override func willAnimateRotationToInterfaceOrientation(toInterfaceOrientation: UIInterfaceOrientation, duration: NSTimeInterval) {
        if !FolioReader.sharedInstance.isReaderReady { return }
        
        if currentPageNumber+1 >= totalPages {
            UIView.animateWithDuration(duration, animations: {
                self.collectionView.setContentOffset(self.frameForPage(currentPageNumber).origin, animated: false)
            })
        }
    }
    
    // MARK: - Page
    
    func setPageSize(orientation: UIInterfaceOrientation) {
        if orientation.isPortrait {
            if screenBounds.size.width < screenBounds.size.height {
                pageWidth = screenBounds.size.width
                pageHeight = screenBounds.size.height - topOffset
            } else {
                pageWidth = screenBounds.size.height - topOffset
                pageHeight = screenBounds.size.width
            }
        } else {
            if screenBounds.size.width > screenBounds.size.height {
                pageWidth = screenBounds.size.width
                pageHeight = screenBounds.size.height - topOffset
            } else {
                pageWidth = screenBounds.size.height - topOffset
                pageHeight = screenBounds.size.width
            }
        }
    }
    
    func updateCurrentPage(completion: (() -> Void)? = nil) {
        updateCurrentPage(nil) { () -> Void in
            if (completion != nil) { completion!() }
        }
    }
    
    func updateCurrentPage(page: FolioReaderPage!, completion: (() -> Void)? = nil) {
        if let page = page {
            currentPage = page
            previousPageNumber = page.pageNumber-1
            currentPageNumber = page.pageNumber
        } else {
            let currentIndexPath = getCurrentIndexPath()
            if currentIndexPath != NSIndexPath(forRow: 0, inSection: 0) {
                currentPage = collectionView.cellForItemAtIndexPath(currentIndexPath) as! FolioReaderPage
            }
            
            previousPageNumber = currentIndexPath.row
            currentPageNumber = currentIndexPath.row+1
        }
        
        nextPageNumber = currentPageNumber+1 <= totalPages ? currentPageNumber+1 : currentPageNumber
        
        // Set navigation title
        if let chapterName = getCurrentChapterName() {
            title = chapterName
        } else { title = ""}
        
        // Set pages
        if let page = currentPage {
            page.webView.becomeFirstResponder()
        }
        
        if (completion != nil) { completion!() }
    }
    
    func pageForOffset(offset: CGFloat, pageHeight height: CGFloat) -> Int {
        let page = Int(ceil(offset / height))+1
        return page
    }
    
    func getCurrentIndexPath() -> NSIndexPath {
        let indexPaths = collectionView.indexPathsForVisibleItems()
        var indexPath = NSIndexPath()
        
        if indexPaths.count > 1 {
            let first = indexPaths.first! as NSIndexPath
            let last = indexPaths.last! as NSIndexPath
            
            switch scrollDirection {
            case .Up:
                if first.compare(last) == NSComparisonResult.OrderedAscending {
                    indexPath = last
                } else {
                    indexPath = first
                }
            default:
                if first.compare(last) == NSComparisonResult.OrderedAscending {
                    indexPath = first
                } else {
                    indexPath = last
                }
            }
        } else {
            indexPath = indexPaths.first ?? NSIndexPath(forRow: 0, inSection: 0)
        }
        
        return indexPath
    }
    
    func frameForPage(page: Int) -> CGRect {
        return CGRectMake(0, pageHeight * CGFloat(page-1), pageWidth, pageHeight)
    }
    
    func changePageWith(page page: Int, animated: Bool = false, completion: (() -> Void)? = nil) {
        if page > 0 && page-1 < totalPages {
            let indexPath = NSIndexPath(forRow: page-1, inSection: 0)
            changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
                self.updateCurrentPage({ () -> Void in
                    if (completion != nil) { completion!() }
                })
            })
        }
    }
    
    func changePageWith(page page: Int, andFragment fragment: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        if currentPageNumber == page {
            if fragment != "" && currentPage != nil {
                currentPage.handleAnchor(fragment, avoidBeginningAnchors: true, animating: animated)
                if (completion != nil) { completion!() }
            }
        } else {
            tempFragment = fragment
            changePageWith(page: page, animated: animated, completion: { () -> Void in
                self.updateCurrentPage({ () -> Void in
                    if (completion != nil) { completion!() }
                })
            })
        }
    }
    
    func changePageWith(href href: String, animated: Bool = false, completion: (() -> Void)? = nil) {
        let item = findPageByHref(href)
        let indexPath = NSIndexPath(forRow: item, inSection: 0)
        changePageWith(indexPath: indexPath, animated: animated, completion: { () -> Void in
            self.updateCurrentPage({ () -> Void in
                if (completion != nil) { completion!() }
            })
        })
    }

    func changePageWith(href href: String, andAudioMarkID markID: String) {
        if recentlyScrolled { return } // if user recently scrolled, do not change pages or scroll the webview

        let item = findPageByHref(href)
        let pageUpdateNeeded = item+1 != currentPage.pageNumber
        let indexPath = NSIndexPath(forRow: item, inSection: 0)
        changePageWith(indexPath: indexPath, animated: true) { () -> Void in
            if pageUpdateNeeded {
                self.updateCurrentPage({ () -> Void in
                    self.currentPage.audioMarkID(markID);
                })
            } else {
                self.currentPage.audioMarkID(markID);
            }
        }
    }

    func changePageWith(indexPath indexPath: NSIndexPath, animated: Bool = false, completion: (() -> Void)? = nil) {
        UIView.animateWithDuration(animated ? 0.3 : 0, delay: 0, options: .CurveEaseInOut, animations: { () -> Void in
            self.collectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: .Top, animated: false)
            }) { (finished: Bool) -> Void in
                if (completion != nil) { completion!() }
        }
    }
    
    func isLastPage() -> Bool{
        return currentPageNumber == nextPageNumber
    }

    func changePageToNext(completion: (() -> Void)? = nil) {
        changePageWith(page: nextPageNumber, animated: true) { () -> Void in
            if (completion != nil) { completion!() }
        }
    }
    
    func changePageToPrevious(completion: (() -> Void)? = nil) {
        changePageWith(page: previousPageNumber, animated: true) { () -> Void in
            if (completion != nil) { completion!() }
        }
    }

    /**
    Find a page by FRTocReference.
    */
    func findPageByResource(reference: FRTocReference) -> Int {
        var count = 0
        for item in book.spine.spineReferences {
            if let resource = reference.resource where item.resource.href == resource.href {
                return count
            }
            count += 1
        }
        return count
    }
    
    /**
    Find a page by href.
    */
    func findPageByHref(href: String) -> Int {
        var count = 0
        for item in book.spine.spineReferences {
            if item.resource.href == href {
                return count
            }
            count += 1
        }
        return count
    }
    
    /**
    Find and return the current chapter resource.
    */
    func getCurrentChapter() -> FRResource? {
        if let currentPageNumber = currentPageNumber {
            for item in FolioReader.sharedInstance.readerSidePanel.tocItems {
                if let reference = book.spine.spineReferences[safe: currentPageNumber-1], resource = item.resource
                    where resource.href == reference.resource.href {
                    return item.resource
                }
            }
        }
        return nil
    }

    /**
     Find and return the current chapter name.
     */
    func getCurrentChapterName() -> String? {
        if let currentPageNumber = currentPageNumber {
            for item in FolioReader.sharedInstance.readerSidePanel.tocItems {
                if let reference = book.spine.spineReferences[safe: currentPageNumber-1], resource = item.resource
                    where resource.href == reference.resource.href {
                    if let title = item.title {
                        return title
                    }
                    return nil
                }
            }
        }
        return nil
    }
    
    // MARK: - Audio Playing

    func playAudio(fragmentID: String){

        let chapter = getCurrentChapter()
        let href = chapter != nil ? chapter!.href : "";
        FolioReader.sharedInstance.readerAudioPlayer.playAudio(href, fragmentID: fragmentID)
    }

    func audioMark(href href: String, fragmentID: String) {
        changePageWith(href: href, andAudioMarkID: fragmentID)
    }

    // MARK: - Sharing
    
    /**
    Sharing chapter method.
    */
    func shareChapter(sender: UIBarButtonItem) {
        
        if let chapterText = currentPage.webView.js("getBodyText()") {
            
            let htmlText = chapterText.stringByReplacingOccurrencesOfString("[\\n\\r]+", withString: "<br />", options: .RegularExpressionSearch)

            var subject = readerConfig.localizedShareChapterSubject
            var html = ""
            var text = ""
            var bookTitle = ""
            var chapterName = ""
            var authorName = ""
            
            // Get book title
            if let title = book.title() {
                bookTitle = title
                subject += " “\(title)”"
            }
            
            // Get chapter name
            if let chapter = getCurrentChapterName() {
                chapterName = chapter
            }
            
            // Get author name
            if let author = book.metadata.creators.first {
                authorName = author.name
            }
            
            // Sharing html and text
            html = "<html><body>"
            html += "<br /><hr> <p>\(htmlText)</p> <hr><br />"
            html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
            html += "<b>\(bookTitle)</b><br />"
            html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"
            if (bookShareLink != nil) { html += "<a href=\"\(bookShareLink!)\">\(bookShareLink!)</a>" }
            html += "</center></body></html>"
            text = "\(chapterName)\n\n“\(chapterText)” \n\n\(bookTitle) \nby \(authorName)"
            if (bookShareLink != nil) { text += " \n\(bookShareLink!)" }
            
            
            let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
            let shareItems = [act, ""]
            let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
            activityViewController.excludedActivityTypes = [UIActivityTypePrint, UIActivityTypePostToVimeo, UIActivityTypePostToFacebook]
            
            // Pop style on iPad
            if let actv = activityViewController.popoverPresentationController {
                actv.barButtonItem = sender
            }
            
            presentViewController(activityViewController, animated: true, completion: nil)
        }
    }
    
    /**
    Sharing highlight method.
    */
    func shareHighlight(string: String, rect: CGRect) {
        
        var subject = readerConfig.localizedShareHighlightSubject
        var html = ""
        var text = ""
        var bookTitle = ""
        var chapterName = ""
        var authorName = ""
        
        // Get book title
        if let title = book.title() {
            bookTitle = title
            subject += " “\(title)”"
        }
        
        // Get chapter name
        if let chapter = getCurrentChapterName() {
            chapterName = chapter
        }
        
        // Get author name
        if let author = book.metadata.creators.first {
            authorName = author.name
        }
        
        // Sharing html and text
        html = "<html><body>"
        html += "<br /><hr> <p>\(chapterName)</p>"
        html += "<p>\(string)</p> <hr><br />"
        html += "<center><p style=\"color:gray\">"+readerConfig.localizedShareAllExcerptsFrom+"</p>"
        html += "<b>\(bookTitle)</b><br />"
        html += readerConfig.localizedShareBy+" <i>\(authorName)</i><br />"
        if (bookShareLink != nil) { html += "<a href=\"\(bookShareLink!)\">\(bookShareLink!)</a>" }
        html += "</center></body></html>"
        text = "\(chapterName)\n\n“\(string)” \n\n\(bookTitle) \nby \(authorName)"
        if (bookShareLink != nil) { text += " \n\(bookShareLink!)" }
        
        
        let act = FolioReaderSharingProvider(subject: subject, text: text, html: html)
        let shareItems = [act, ""]
        let activityViewController = UIActivityViewController(activityItems: shareItems, applicationActivities: nil)
        activityViewController.excludedActivityTypes = [UIActivityTypePrint, UIActivityTypePostToVimeo, UIActivityTypePostToFacebook]
        
        // Pop style on iPad
        if let actv = activityViewController.popoverPresentationController {
            actv.sourceView = currentPage
            actv.sourceRect = rect
        }
        
        presentViewController(activityViewController, animated: true, completion: nil)
    }
    
    // MARK: - Folio Page Delegate
    
    func pageDidLoad(page: FolioReaderPage) {
        
        if let position = FolioReader.defaults.valueForKey(kBookId) as? NSDictionary {
            let pageNumber = position["pageNumber"]! as! Int
            let pageOffset = position["pageOffset"]! as! CGFloat
            
            if isFirstLoad {
                updateCurrentPage(page)
                isFirstLoad = false
                
                if currentPageNumber == pageNumber && pageOffset > 0 {
                    page.scrollPageToOffset("\(pageOffset)", animating: false)
                }
            }
            
        } else if isFirstLoad {
            updateCurrentPage(page)
            isFirstLoad = false
        }
        
        // Go to fragment if needed
        if let fragment = tempFragment where fragment != "" && currentPage != nil {
            currentPage.handleAnchor(fragment, avoidBeginningAnchors: true, animating: true)
            tempFragment = nil
        }
    }
    
    // MARK: - ScrollView Delegate
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        isScrolling = true
        clearRecentlyScrolled()
        recentlyScrolled = true
        pointNow = scrollView.contentOffset
        
        if let currentPage = currentPage {
            currentPage.webView.createMenu(options: true)
            currentPage.webView.setMenuVisible(false)
        }
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        scrollDirection = scrollView.contentOffset.y < pointNow.y ? .Down : .Up
    }
    
    func scrollViewDidEndDecelerating(scrollView: UIScrollView) {
        isScrolling = false
        
        if scrollView is UICollectionView {
            if totalPages > 0 { updateCurrentPage() }
        }
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        recentlyScrolledTimer = NSTimer(timeInterval:recentlyScrolledDelay, target: self, selector: #selector(FolioReaderCenter.clearRecentlyScrolled), userInfo: nil, repeats: false)
        NSRunLoop.currentRunLoop().addTimer(recentlyScrolledTimer, forMode: NSRunLoopCommonModes)
    }

    func clearRecentlyScrolled(){
        if( recentlyScrolledTimer != nil ){
            recentlyScrolledTimer.invalidate()
            recentlyScrolledTimer = nil
        }
        recentlyScrolled = false
    }
    
    // MARK: - Container delegate
    
    func container(didExpandRightPanel sidePanel: FolioReaderSidePanel) {
        collectionView.userInteractionEnabled = false
        FolioReader.saveReaderState()
    }
    
    func container(didCollapseRightPanel sidePanel: FolioReaderSidePanel) {
        collectionView.userInteractionEnabled = true
        updateCurrentPage()
        
        // Move to #fragment
        if tempReference != nil {
            if tempReference!.fragmentID != "" && currentPage != nil {
                currentPage.handleAnchor(tempReference!.fragmentID!, avoidBeginningAnchors: true, animating: true)
            }
            tempReference = nil
        }
    }
    
    func container(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference) {
        let item = findPageByResource(reference)
        
        if item < totalPages-1 {
            let indexPath = NSIndexPath(forRow: item, inSection: 0)
            changePageWith(indexPath: indexPath, animated: false, completion: { () -> Void in
                self.updateCurrentPage()
            })
            tempReference = reference
        } else {
            print("Failed to load book because the requested resource is missing.")
        }
    }
    
    // MARK: - Fonts Menu
    
    func presentFontsMenu() {
        let menu = FolioReaderFontsMenu()
        menu.modalPresentationStyle = .Custom

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.dragable = false
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.Bottom

        menu.transitioningDelegate = animator
        presentViewController(menu, animated: true, completion: nil)
    }
    
    // MARK: - Highlights List
    
    func presentHighlightsList() {
        let menu = UINavigationController(rootViewController: FolioReaderHighlightList())
        presentViewController(menu, animated: true, completion: nil)
    }


    // MARK: - Audio Player Menu

    func presentPlayerMenu() {
        let menu = FolioReaderPlayerMenu()
        menu.modalPresentationStyle = .Custom

        animator = ZFModalTransitionAnimator(modalViewController: menu)
        animator.dragable = true
        animator.bounces = false
        animator.behindViewAlpha = 0.4
        animator.behindViewScale = 1
        animator.transitionDuration = 0.6
        animator.direction = ZFModalTransitonDirection.Bottom

        menu.transitioningDelegate = animator
        presentViewController(menu, animated: true, completion: nil)
    }
}
