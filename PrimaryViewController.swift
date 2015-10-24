//
//  PrimaryViewController.swift
//  SourceView
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/10/24.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 View controller containing the lower UI controls and the embedded child view controller (split view controller)
 */
import Cocoa

// notification to instruct MyOutlineViewController to add a folder
let kAddFolderNotification = "AddFolderNotification"
// notification to instruct MyOutlineViewController to remove a folder
let kRemoveFolderNotification = "RemoveFolderNotification"
// notification to instruct MyOutlineViewController to add a bookmark
let kAddBookmarkNotification = "AddBookmarkNotification"
// notification to instruct MyOutlineViewController to edit a bookmark
let kEditBookmarkNotification = "EditBookmarkNotification"

@objc(PrimaryViewController)
class PrimaryViewController: NSViewController {
    
    @IBOutlet private weak var progIndicator: NSProgressIndicator!
    @IBOutlet private weak var removeButton: NSButton!
    @IBOutlet private weak var actionButton: NSPopUpButton!
    @IBOutlet private weak var urlField: NSTextField!
    @IBOutlet private var editBookmarkMenuItem: NSMenuItem!
    
    //MARK: -
    
    
    // -------------------------------------------------------------------------------
    //	viewDidLoad
    // -------------------------------------------------------------------------------
    override func viewDidLoad() {
        // Note: we keep the left split view item from growing as the window grows by setting its holding priority to 200, and the right to 199.
        // The view with the lowest priority will be the first to take on additional width if the split view grows or shrinks.
        //
        super.viewDidLoad()
        
        // insert an empty menu item at the beginning of the drown down button's menu and add its image
        let actionImage = NSImage(named: NSImageNameActionTemplate)!
        actionImage.size = NSMakeSize(10,10)
        
        let menuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        self.actionButton.menu?.insertItem(menuItem, atIndex: 0)
        menuItem.image = actionImage
        
        self.actionButton.menu?.autoenablesItems = false
        
        // start off by disabling the Edit... menu item until we are notified of a selection
        self.editBookmarkMenuItem.enabled = false
        
        // truncate to the middle if the url is too long to fit
        self.urlField.cell?.lineBreakMode = .ByTruncatingMiddle
    }
    
    // -------------------------------------------------------------------------------
    //	viewWillAppear
    // -------------------------------------------------------------------------------
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // listen for selection changes from the NSOutlineView inside MyOutlineViewController
        // note: we start observing after our outline view is populated so we don't receive unnecessary notifications at startup
        //
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "selectionDidChange:",
            name: NSOutlineViewSelectionDidChangeNotification,
            object: nil)
        
        // notification so we know when the icon view controller is done populating its content
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "contentReceived:",
            name: kReceivedContentNotification,
            object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	dealloc
    // -------------------------------------------------------------------------------
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSOutlineViewSelectionDidChangeNotification, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: kReceivedContentNotification, object: nil)
    }
    
    
    //MARK: - NSNotifications
    
    // -------------------------------------------------------------------------------
    //  contentReceived:notif
    //
    //  Notification sent from IconViewController class,
    //  indicating the file system content has been received
    // -------------------------------------------------------------------------------
    @objc func contentReceived(notif: NSNotification) {
        self.progIndicator.hidden = true
        self.progIndicator.stopAnimation(self)
    }
    
    // -------------------------------------------------------------------------------
    //  Listens for changes outline view row selection
    // -------------------------------------------------------------------------------
    @objc func selectionDidChange(notification: NSNotification) {
        // examine the current selection and adjust the UI
        //
        let outlineView = notification.object as! NSOutlineView
        let selectedRow = outlineView.selectedRow
        if selectedRow == -1 {
            // there is no current selection - no item to display
            self.removeButton.enabled = false
            self.urlField.stringValue = ""
            self.editBookmarkMenuItem.enabled = false
        } else {
            // single selection
            self.removeButton.enabled = true
            
            // report the URL to our NSTextField
            let item = outlineView.itemAtRow(selectedRow)!.representedObject as! BaseNode
            self.urlField.stringValue = item.urlString ?? ""
            
            // enable the Edit... menu item if the selected node is a bookmark
            self.editBookmarkMenuItem.enabled = (item.urlString == nil) || item.isBookmark
            
            if item.isDirectory {
                // we are populating the detail view controler with contents of a folder on disk
                // (may take a while)
                self.progIndicator.hidden = false
            }
        }
    }
    
    
    //MARK: - Folders
    
    // -------------------------------------------------------------------------------
    //	addFolderAction:sender:
    // -------------------------------------------------------------------------------
    @IBAction func addFolderAction(_: AnyObject) {
        // post notification to MyOutlineViewController to add a new folder
        NSNotificationCenter.defaultCenter().postNotificationName(kAddFolderNotification, object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	removeFolderAction:sender:
    // -------------------------------------------------------------------------------
    @IBAction func removeFolderAction(_: AnyObject) {
        // post notification to MyOutlineViewController to remove the selected folder
        NSNotificationCenter.defaultCenter().postNotificationName(kRemoveFolderNotification, object: nil)
    }
    
    
    //MARK: - Bookmarks
    
    // -------------------------------------------------------------------------------
    //	addBookmarkAction:sender
    // -------------------------------------------------------------------------------
    @IBAction func addBookmarkAction(_: AnyObject) {
        // post notification to MyOutlineViewController to add a new bookmark
        NSNotificationCenter.defaultCenter().postNotificationName(kAddBookmarkNotification, object: nil)
    }
    
    // -------------------------------------------------------------------------------
    //	editChildAction:sender
    // -------------------------------------------------------------------------------
    @IBAction func editBookmarkAction(_: AnyObject) {
        // post notification to MyOutlineViewController to edit a selected bookmark
        NSNotificationCenter.defaultCenter().postNotificationName(kEditBookmarkNotification, object: nil)
    }
    
}