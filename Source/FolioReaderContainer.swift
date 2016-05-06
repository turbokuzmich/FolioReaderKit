//
//  FolioReaderContainer.swift
//  FolioReaderKit
//
//  Created by Heberti Almeida on 15/04/15.
//  Copyright (c) 2015 Folio Reader. All rights reserved.
//

import UIKit
import FontBlaster

var readerConfig: FolioReaderConfig!
var epubPath: String?
var book: FRBook!

enum SlideOutState {
    case BothCollapsed
    case RightPanelExpanded
    case Expanding
    
    init () {
        self = .BothCollapsed
    }
}

protocol FolioReaderContainerDelegate: class {
    /**
    Notifies that the menu was expanded.
    */
    func container(didExpandRightPanel sidePanel: FolioReaderSidePanel)
    
    /**
    Notifies that the menu was closed.
    */
    func container(didCollapseRightPanel sidePanel: FolioReaderSidePanel)
    
    /**
    Notifies when the user selected some item on menu.
    */
    func container(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference)
}

public class FolioReaderContainer: UIViewController, FolioReaderSidePanelDelegate {
    var delegate: FolioReaderContainerDelegate!
    var centerViewController: FolioReaderCenter!
    var rightViewController: FolioReaderSidePanel!
    var audioPlayer: FolioReaderAudioPlayer!
    var centerPanelExpandedOffset: CGFloat = 70
    var currentState = SlideOutState()
    private var errorOnLoad = false
    private var shouldRemoveEpub = true
    
    // MARK: - Init
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    init(config configOrNil: FolioReaderConfig!, epubPath epubPathOrNil: String? = nil, removeEpub: Bool) {
        readerConfig = configOrNil
        epubPath = epubPathOrNil
        shouldRemoveEpub = removeEpub
        super.init(nibName: nil, bundle: NSBundle.frameworkBundle())
        
        // Init with empty book
        book = FRBook()
        
        // Register custom fonts
        FontBlaster.blast(NSBundle.frameworkBundle())
        
        // Register initial defaults
        FolioReader.defaults.registerDefaults([
            kCurrentFontFamily: 0,
            kNightMode: false,
            kCurrentFontSize: 2,
            kCurrentAudioRate: 1,
            kCurrentHighlightStyle: 0,
            kCurrentMediaOverlayStyle: MediaOverlayStyle.Default.rawValue
        ])
    }
    
    // MARK: - View life cicle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        automaticallyAdjustsScrollViewInsets = false
        
        centerViewController = FolioReaderCenter()
        centerViewController.folioReaderContainer = self
        FolioReader.sharedInstance.readerCenter = centerViewController
        
        view.addSubview(centerViewController.view)
        addChildViewController(centerViewController)
        centerViewController.didMoveToParentViewController(self)
        
        // Add gestures
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.delegate = self
        view.addGestureRecognizer(tapGestureRecognizer)
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        view.addGestureRecognizer(panGestureRecognizer)

        // Read async book
        if (epubPath != nil) {
            let priority = DISPATCH_QUEUE_PRIORITY_HIGH
            dispatch_async(dispatch_get_global_queue(priority, 0), { () -> Void in
                
                var isDir: ObjCBool = false
                let fileManager = NSFileManager.defaultManager()

                if fileManager.fileExistsAtPath(epubPath!, isDirectory:&isDir) {
                    if isDir {
                        book = FREpubParser().readEpub(filePath: epubPath!)
                    } else {
                        book = FREpubParser().readEpub(epubPath: epubPath!, removeEpub: self.shouldRemoveEpub)
                    }
                }
                else {
                    print("Epub file does not exist.")
                    self.errorOnLoad = true
                }
                
                FolioReader.sharedInstance.isReaderOpen = true
                
                if !self.errorOnLoad {
                    // Reload data
                    dispatch_async(dispatch_get_main_queue(), {
                        self.centerViewController.reloadData()
                        self.addRightPanelViewController()
                        self.addAudioPlayer()
                        
                        self.tease()
                        
                        FolioReader.sharedInstance.isReaderReady = true
                    })
                }
            })
        } else {
            print("Epub path is nil.")
            errorOnLoad = true
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        showShadowForCenterViewController(true)
        
        if errorOnLoad {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    func tease() {
        if FolioReader.sharedInstance.teased {
            return
        }
        
        FolioReader.sharedInstance.teased = true
        
        let view = centerViewController.view
        let original = view.frame
        let translated = original.translate(-50, y: 0)
        
        UIView.animateWithDuration(0.3, delay: 0.5, options: [UIViewAnimationOptions.CurveEaseInOut], animations: {
            view.frame = translated
        }, completion: { _ in
            UIView.animateWithDuration(0.7, delay: 0.0, usingSpringWithDamping: 0.7, initialSpringVelocity: 1.0, options: [UIViewAnimationOptions.CurveEaseInOut], animations: {
                view.frame = original
            }, completion: nil)
        })
    }
    
    // MARK: CenterViewController delegate methods
    
    func toggleRightPanel() {
        let notAlreadyExpanded = (currentState != .RightPanelExpanded)
        
        if notAlreadyExpanded {
            addRightPanelViewController()
        }
        
        animateRightPanel(shouldExpand: notAlreadyExpanded)
    }
    
    func collapseSidePanels() {
        switch (currentState) {
        case .RightPanelExpanded:
            toggleRightPanel()
        default:
            break
        }
    }
    
    func addRightPanelViewController() {
        if (rightViewController == nil) {
            rightViewController = FolioReaderSidePanel()
            rightViewController.delegate = self
            addChildSidePanelController(rightViewController!)
            
            FolioReader.sharedInstance.readerSidePanel = rightViewController
        }
    }
    
    func addChildSidePanelController(sidePanelController: FolioReaderSidePanel) {
        view.insertSubview(sidePanelController.view, atIndex: 0)
        addChildViewController(sidePanelController)
        sidePanelController.didMoveToParentViewController(self)
    }
    
    func animateRightPanel(shouldExpand shouldExpand: Bool) {
        if (shouldExpand) {
            
            let w = UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication().statusBarOrientation) ? UIScreen.mainScreen().bounds.size.width : UIScreen.mainScreen().bounds.size.height
            
            centerPanelExpandedOffset = 70 - w
            
            currentState = .RightPanelExpanded
            delegate.container(didExpandRightPanel: rightViewController)
            animateCenterPanelXPosition(targetPosition: centerPanelExpandedOffset)
            
            // Reload to update current reading chapter
            rightViewController.tableView.reloadData()
            navigationController?.interactivePopGestureRecognizer?.enabled = false
        } else {
            animateCenterPanelXPosition(targetPosition: 0) { finished in
                self.delegate.container(didCollapseRightPanel: self.rightViewController)
                self.currentState = .BothCollapsed
            }
            navigationController?.interactivePopGestureRecognizer?.enabled = true
        }
    }
    
    func animateCenterPanelXPosition(targetPosition targetPosition: CGFloat, completion: ((Bool) -> Void)! = nil) {
        UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .CurveEaseInOut, animations: {
            self.centerViewController.view.frame.origin.x = targetPosition
        }, completion: completion)
    }
    
    func showShadowForCenterViewController(shouldShowShadow: Bool) {
        if (shouldShowShadow) {
            centerViewController.view.layer.shadowOpacity = 0.2
            centerViewController.view.layer.shadowRadius = 6
            centerViewController.view.layer.shadowPath = UIBezierPath(rect: centerViewController.view.bounds).CGPath
            centerViewController.view.clipsToBounds = false
        } else {
            centerViewController.view.layer.shadowOpacity = 0
            centerViewController.view.layer.shadowRadius = 0
        }
    }
    
    func addAudioPlayer(){
        // @NOTE: should the audio player only be initialized if the epub has audio smil?
        audioPlayer = FolioReaderAudioPlayer()

        FolioReader.sharedInstance.readerAudioPlayer = audioPlayer;
    }

    // MARK: Gesture recognizer
    
    func handleTapGesture(recognizer: UITapGestureRecognizer) {
        if currentState == .RightPanelExpanded {
            toggleRightPanel()
        }
    }
    
    func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        let gestureIsDraggingFromRightToLeft = (recognizer.velocityInView(view).x < 0)
        
        switch(recognizer.state) {
        case .Began:
            if currentState == .BothCollapsed && gestureIsDraggingFromRightToLeft {
                currentState = .Expanding
            }
        case .Changed:
            if currentState == .RightPanelExpanded || currentState == .Expanding && centerViewController.view.frame.origin.x <= 0 {
                centerViewController.view.center.x = centerViewController.view.center.x + recognizer.translationInView(view).x
                recognizer.setTranslation(CGPointZero, inView: view)
            }
        case .Ended:
            if rightViewController != nil {
                let w = UIInterfaceOrientationIsPortrait(UIApplication.sharedApplication().statusBarOrientation) ? UIScreen.mainScreen().bounds.size.width : UIScreen.mainScreen().bounds.size.height
                let gap = 20 as CGFloat
                let xPos = centerViewController.view.frame.origin.x + centerViewController.view.frame.size.width
                let canFinishAnimation = gestureIsDraggingFromRightToLeft && (w - xPos) > gap ? true : false
                animateRightPanel(shouldExpand: canFinishAnimation)
            }
        default:
            break
        }
    }
    
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let tap = gestureRecognizer as? UITapGestureRecognizer else {
            return true
        }
        return centerViewController.view.frame.contains(tap.locationInView(view))
    }
    
    // MARK: - Side Panel delegate
    
    func sidePanel(sidePanel: FolioReaderSidePanel, didSelectRowAtIndexPath indexPath: NSIndexPath, withTocReference reference: FRTocReference) {
        collapseSidePanels()
        delegate.container(sidePanel, didSelectRowAtIndexPath: indexPath, withTocReference: reference)
    }
}

extension CGRect {
    
    func translate(x: CGFloat, y: CGFloat) -> CGRect {
        var clone = self
        clone.origin.x = clone.origin.x + x
        clone.origin.y = clone.origin.y + y
        return clone
    }
    
}
